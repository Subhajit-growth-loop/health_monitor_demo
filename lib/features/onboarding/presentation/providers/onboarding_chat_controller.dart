import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../domain/entities/onboarding_chat.dart';
import '../../domain/entities/onboarding_draft.dart';
import '../../domain/entities/patient_profile_options.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_providers.dart';

/// State of the AI follow-up conversation on the note step.
class OnboardingChatState {
  const OnboardingChatState({
    this.messages = const [],
    this.sessionId,
    this.question,
    this.done = false,
    this.summary,
    this.starting = false,
    this.sending = false,
    this.error,
  });

  /// The rendered conversation, oldest first.
  final List<ChatMessage> messages;

  final String? sessionId;

  /// The question currently awaiting an answer. Null once [done].
  final String? question;

  /// True when the AI has finished — this is what unlocks "Save & next".
  final bool done;

  final PatientSummary? summary;

  /// The opening `/start` call is in flight.
  final bool starting;

  /// A `/turn` call is in flight.
  final bool sending;

  /// Last failure, shown inline with a retry affordance.
  final String? error;

  bool get busy => starting || sending;

  /// The patient may type only while a session is open and unfinished.
  bool get canAnswer => sessionId != null && !done && !busy;

  OnboardingChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    String? question,
    bool? done,
    PatientSummary? summary,
    bool? starting,
    bool? sending,
    String? error,
  }) => OnboardingChatState(
    messages: messages ?? this.messages,
    sessionId: sessionId ?? this.sessionId,
    // Explicitly nullable: the question clears when the conversation ends.
    question: question,
    done: done ?? this.done,
    summary: summary ?? this.summary,
    starting: starting ?? this.starting,
    sending: sending ?? this.sending,
    // Same — errors clear on the next attempt rather than sticking.
    error: error,
  );
}

/// Drives `/onboarding-chat/start` and `/onboarding-chat/turn`.
///
/// The server owns all conversation state; this holds only the `session_id` and
/// what has been rendered. `/skip` is deliberately not wired up.
class OnboardingChatController extends Notifier<OnboardingChatState> {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  OnboardingChatState build() => const OnboardingChatState();

  /// Opens a **fresh** conversation, discarding anything from a previous visit
  /// to this step — nothing about the chat is kept between visits.
  ///
  /// The in-flight guard remains so a rebuild mid-open can't fire a second
  /// `/start`; call [restart] to force a new one.
  Future<void> start() async {
    if (state.starting) return;
    state = const OnboardingChatState();

    state = state.copyWith(starting: true, error: null);
    try {
      await _openSession();
      state = state.copyWith(starting: false, question: state.question);
    } catch (e, st) {
      final message = AppErrorHandler.instance.handle(
            e,
            stackTrace: st,
            context: 'Onboarding chat · start',
          ) ??
          "Couldn't start the conversation.";

      // Same rule as a failed turn: a 404 here means the server won't give us a
      // usable conversation, so send the user back to login rather than leaving
      // them on a screen whose CTA can never unlock.
      if (e is DioException && e.response?.statusCode == 404) {
        state = state.copyWith(
          starting: false,
          error: 'Please sign in again to continue.',
        );
        AppErrorHandler.instance.onSessionExpired?.call();
        return;
      }

      state = state.copyWith(starting: false, error: message);
    }
  }

  /// Calls `POST /onboarding-chat/start` and adopts the `session_id` it returns.
  /// **Every** later `/turn` uses that id — there is no other source for it.
  ///
  /// [render] appends the opening question to the transcript. It's false when
  /// recovering a dead session mid-conversation: the patient has already typed an
  /// answer, so a fresh opening question would read as a non-sequitur above it.
  ///
  /// Returns the new session id. Throws on failure so callers can decide.
  Future<String> _openSession({bool render = true}) async {
    final onboarding = ref.read(onboardingControllerProvider).value;
    final res = await _repo.startChat(
      patientId: CurrentUser.instance.id,
      onboarding: buildChatPayload(
        profile: onboarding?.profile ?? const UserProfile(),
        draft: onboarding?.draft ?? const OnboardingDraft(),
      ),
    );

    if (res.sessionId.isEmpty) {
      throw StateError('/onboarding-chat/start returned no session_id');
    }

    if (render) {
      _apply(res);
    } else {
      state = state.copyWith(
        sessionId: res.sessionId,
        question: res.question,
        done: res.done,
      );
    }
    return res.sessionId;
  }

  /// Retry after a failed [start] — clears the error and tries again.
  Future<void> retryStart() async {
    if (state.sessionId != null) return;
    state = state.copyWith(error: null);
    await start();
  }

  /// Throws away the conversation and opens a fresh one. Used when the server no
  /// longer recognises our session, which it cannot resume.
  Future<void> restart() async {
    state = const OnboardingChatState();
    await start();
  }

  /// Submits [answer] and renders the next question or the final summary.
  Future<void> send(String answer) async {
    final text = answer.trim();
    final sessionId = state.sessionId;
    if (text.isEmpty || sessionId == null || state.done || state.busy) return;

    // Echo the patient's message immediately so the send feels instant; the
    // loader covers the round-trip.
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.patient(text)],
      sending: true,
      error: null,
      question: state.question,
    );

    try {
      final res = await _repo.chatTurn(sessionId: sessionId, answer: text);
      _apply(res, sending: false);
      return;
    } on DioException catch (e, st) {
      // A 404 means the server has no session by that id. It keeps conversation
      // state in memory (v1), so a backend restart — routine in development —
      // invalidates the id `/start` gave us. Recover by opening a fresh session
      // and replaying this answer against the *new* id, so the patient never
      // sees the failure. Attempted once; a second 404 is a real problem.
      if (e.response?.statusCode == 404 && !_recovering) {
        if (await _recoverAndResend(text)) return;
      }
      _failTurn(e, st);
      return;
    } catch (e, st) {
      _failTurn(e, st);
      return;
    }
  }

  /// Guards against a recovery attempt recursing into another recovery.
  bool _recovering = false;

  /// Opens a new session and re-sends [text] with the id it returns.
  /// Returns true when the replay succeeded.
  Future<bool> _recoverAndResend(String text) async {
    _recovering = true;
    try {
      if (kDebugMode) {
        debugPrint('[OnboardingChat] session expired — opening a new one '
            'and replaying the answer');
      }
      // render: false — the patient's answer is already on screen, so a fresh
      // opening question above it would read as a non-sequitur. The turn's own
      // acknowledgment + question get appended instead.
      final newSessionId = await _openSession(render: false);
      final res = await _repo.chatTurn(sessionId: newSessionId, answer: text);
      _apply(res, sending: false);
      return true;
    } catch (_) {
      return false;
    } finally {
      _recovering = false;
    }
  }

  void _failTurn(Object e, StackTrace st) {
    final message = AppErrorHandler.instance.handle(
          e,
          stackTrace: st,
          context: 'Onboarding chat · turn',
        ) ??
        "Couldn't send that. Please try again.";

    // A 404 that survived the retry means the server won't accept any session we
    // can produce, so there is nothing useful left on this screen. Sign the user
    // out and send them to the login screen for a clean slate — signing back in
    // issues a fresh token *and* a fresh conversation.
    //
    // The server's own wording is deliberately not shown: it embeds the internal
    // session id ("Chat session 'onb_…' was not found"), which means nothing to a
    // patient. It stays in the debug log via handle() above.
    final expired = e is DioException && e.response?.statusCode == 404;
    if (expired) {
      if (kDebugMode) {
        debugPrint('[OnboardingChat] session unrecoverable after retry — '
            'signing out and returning to login');
      }
      state = OnboardingChatState(
        messages: state.messages,
        error: 'Please sign in again to continue.',
      );
      // Wired in main.dart: clears the token + user, then pushes the login screen
      // and clears the navigation stack.
      AppErrorHandler.instance.onSessionExpired?.call();
      return;
    }

    state = state.copyWith(
      sending: false,
      question: state.question,
      error: message,
    );
  }

  /// Appends the acknowledgment then the question, in that order — the
  /// acknowledgment responds to what the patient just said, so it reads first.
  void _apply(
    OnboardingChatResponse res, {
    bool? starting,
    bool? sending,
  }) {
    final added = <ChatMessage>[
      if (res.acknowledgment != null) ChatMessage.coach(res.acknowledgment!),
      if (res.question != null) ChatMessage.coach(res.question!),
    ];

    state = OnboardingChatState(
      messages: [...state.messages, ...added],
      sessionId: res.sessionId.isNotEmpty ? res.sessionId : state.sessionId,
      question: res.question,
      done: res.done,
      summary: res.summary ?? state.summary,
      starting: starting ?? state.starting,
      sending: sending ?? state.sending,
    );

    // Nothing is written to the local draft. The conversation lives on the
    // server for the life of its session; the client keeps it only in this
    // controller, which is reset every time the step is opened.
  }
}

final onboardingChatControllerProvider =
    NotifierProvider<OnboardingChatController, OnboardingChatState>(
      OnboardingChatController.new,
    );

// ── Payload ──────────────────────────────────────────────────────────────────

/// Builds the `onboarding` object for `/onboarding-chat/start` from everything
/// collected so far.
///
/// The AI planner receives this verbatim, so values are sent as **human-readable
/// labels** rather than the API's snake_case enum values — "Type 2 Diabetes"
/// reads better in a generated question than `type_2_diabetes`.
Map<String, dynamic> buildChatPayload({
  required UserProfile profile,
  required OnboardingDraft draft,
}) {
  String labelFor(String value, List<(String, String)> options) {
    for (final (optionValue, label) in options) {
      if (optionValue == value) return label;
    }
    // Free text the user typed into an "Other" box — already readable.
    return value;
  }

  List<String> labelsFor(
    List<String> values,
    List<(String, String)> options,
  ) => [for (final v in values) labelFor(v, options)];

  /// Turns a snake_case draft value ('very_active') into a label.
  String pretty(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// The wellbeing sliders are 0..1; the API example uses a 0-10 scale.
  int scale10(double v) => (v * 10).round().clamp(0, 10);

  final names = profile.fullName.trim().split(RegExp(r'\s+'));

  return {
    'patient': {
      'first_name': names.isEmpty ? '' : names.first,
      'last_name': names.length > 1 ? names.sublist(1).join(' ') : '',
      'date_of_birth': profile.dateOfBirth,
      'gender': profile.gender,
    },
    'clinical_profile': {
      'primary_diagnosis': labelFor(
        profile.primaryDiagnosis,
        PatientProfileOptions.primaryDiagnosis,
      ),
      'diagnosed_at': profile.diagnosedDate,
      'other_conditions': labelsFor(
        profile.otherConditions,
        PatientProfileOptions.otherConditions,
      ),
      // The API models medications as objects; the questionnaire only captures
      // the name, so dose and frequency are omitted rather than invented.
      'medications': [
        for (final m in labelsFor(
          profile.currentMedications,
          PatientProfileOptions.medications,
        ))
          {'name': m},
      ],
      'supplements': labelsFor(
        profile.currentSupplements,
        PatientProfileOptions.supplements,
      ),
    },
    'motivation': {
      'reason_for_joining': draft.motivations.map(pretty).toList(),
      'support_preferences': draft.supportTypes.map(pretty).toList(),
    },
    'lifestyle': {
      'activity_level': pretty(draft.activityLevel),
      'eating_pattern': pretty(draft.eatingRhythm),
      'typical_sleep': {'hours': draft.sleepHours},
      'dietary_preferences': draft.dietaryPrefs.map(pretty).toList(),
    },
    if (profile.isFemale)
      'women_health': {'cycle_status': pretty(draft.menstrualCycle)},
    'symptoms': draft.symptoms.map(pretty).toList(),
    'wellbeing': {
      'sleep': scale10(draft.feeling.sleep),
      'energy': scale10(draft.feeling.energy),
      'stress': scale10(draft.feeling.stress),
      'mood': scale10(draft.feeling.mood),
    },
  };
}
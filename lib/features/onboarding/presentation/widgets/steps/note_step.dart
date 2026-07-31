import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../domain/entities/onboarding_chat.dart';
import '../../view_model/onboarding_chat_controller.dart';

// ── Step 7: AI follow-up chat ─────────────────────────────────────────────────

/// The AI onboarding conversation: `/onboarding-chat/start` on open, then
/// `/onboarding-chat/turn` per answer. The step's CTA stays locked until the
/// server reports `done: true`.
class NoteStep extends ConsumerStatefulWidget {
  const NoteStep({super.key});

  @override
  ConsumerState<NoteStep> createState() => _NoteStepState();
}

class _NoteStepState extends ConsumerState<NoteStep> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// Whether the field holds something other than whitespace. Tracked as state
  /// rather than read inline so the send button repaints as the user types.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Open the conversation as soon as the step is shown. start() no-ops if a
    // session already exists, so navigating back and forth won't restart it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(onboardingChatControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Only rebuilds when the empty/non-empty state actually flips, not on every
  /// keystroke.
  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(onboardingChatControllerProvider.notifier).send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final chat = ref.watch(onboardingChatControllerProvider);
    // Keep the newest bubble in view as the conversation grows.
    ref.listen(onboardingChatControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) _scrollToEnd();
    });

    return Container(
      height: 380.h,
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.border),
      ),
      child: Column(
        children: [
          Expanded(child: _body(chat)),
          Divider(height: 1, color: s.border),
          _composer(chat),
        ],
      ),
    );
  }

  Widget _body(OnboardingChatState chat) {
    final s = NeuSurface.of(context);
    if (chat.starting && chat.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22.r,
              height: 22.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: NeuColors.primary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Reading your answers…',
              style: TextStyle(
                fontSize: 12.sp,
                color: s.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Opening call failed — nothing to talk to yet, so offer a retry.
    if (chat.messages.isEmpty && chat.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: s.textMuted,
                size: 32.r,
              ),
              SizedBox(height: 12.h),
              Text(
                chat.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: s.textMuted,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.h),
              FilledButton(
                onPressed: () => ref
                    .read(onboardingChatControllerProvider.notifier)
                    .retryStart(),
                style: FilledButton.styleFrom(
                  backgroundColor: NeuColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    // One trailing slot for the typing indicator, then one for an inline error.
    final extra = (chat.sending ? 1 : 0) + (chat.error != null ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(14.r),
      itemCount: chat.messages.length + extra,
      itemBuilder: (_, i) {
        if (i < chat.messages.length) {
          return Bubble(message: chat.messages[i]);
        }
        if (chat.sending && i == chat.messages.length) {
          return const TypingBubble();
        }
        // No session left means it expired server-side — a retry of the same
        // turn would 404 again, so offer a fresh conversation instead.
        return InlineError(
          message: chat.error!,
          actionLabel: chat.sessionId == null ? 'Start a new conversation' : null,
          onRetry: chat.sessionId == null
              ? () => ref
                  .read(onboardingChatControllerProvider.notifier)
                  .restart()
              : null,
        );
      },
    );
  }

  Widget _composer(OnboardingChatState chat) {
    final s = NeuSurface.of(context);
    // Typing is allowed whenever the session is open…
    final canType = chat.canAnswer;
    // …but sending needs something to send.
    final canSend = canType && _hasText;
    final String hint;
    if (chat.done) {
      hint = 'Conversation complete';
    } else if (chat.sessionId == null) {
      // "Connecting…" would be a lie once the session is gone — the field only
      // wakes up after the patient taps "Start a new conversation".
      hint = chat.error != null ? 'Not connected' : 'Connecting…';
    } else {
      hint = 'Type a message…';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: canType,
              textInputAction: TextInputAction.send,
              // 4000 is the server's documented ceiling for `answer`.
              maxLength: 4000,
              maxLines: 4,
              minLines: 1,
              onSubmitted: (_) => _send(),
              style: TextStyle(color: s.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: s.textMuted),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: canSend ? _send : null,
            child: Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: canSend
                    ? NeuColors.primary
                    : s.border.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              // No spinner here — the wait is shown by the "Thinking…" bubble in
              // the transcript, so the button just stays put.
              child: Icon(
                chat.done ? Icons.check_rounded : Icons.send_rounded,
                color: canSend
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single conversation bubble — the coach on the left, the patient on the
/// right.
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    final fromPatient = message.fromPatient;
    return Align(
      alignment: fromPatient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 250.w),
        decoration: BoxDecoration(
          color: fromPatient ? NeuColors.primary : s.background,
          borderRadius: BorderRadius.circular(16.r),
          border: fromPatient
              ? null
              : Border.all(color: s.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14.sp,
            color: fromPatient ? Colors.white : s.onSurface,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// Shown while a `/turn` call is in flight — the API documents 2-5s latency, so
/// the wait needs to be visible. Reads as "Maya is thinking" rather than a
/// generic spinner: three dots pulse in sequence, which suits a conversation
/// better than a progress indicator that implies measurable progress.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opacity for dot [i], staggered so the wave travels left to right.
  double _dotOpacity(int i) {
    const dots = 3;
    final phase = (_controller.value - (i / dots)) % 1.0;
    // Ramp up over the first third of each dot's slot, then fade back.
    final eased = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * eased.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: s.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: s.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thinking',
              style: TextStyle(
                fontSize: 13.sp,
                color: s.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(width: 8.w),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(width: 4.w),
                    Container(
                      width: 6.r,
                      height: 6.r,
                      decoration: BoxDecoration(
                        color: NeuColors.primary.withValues(
                          alpha: _dotOpacity(i),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failed turn, shown in the transcript so the patient's typed answer isn't
/// silently lost.
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.actionLabel,
  });
  final String message;
  final VoidCallback? onRetry;

  /// Defaults to a plain retry; an expired session says "start a new one"
  /// instead, since retrying the same turn cannot succeed.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: 260.w),
        decoration: BoxDecoration(
          color: const Color(0xFFD63031).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFFD63031).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFFFF7675),
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  actionLabel ?? 'Try again',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: NeuColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

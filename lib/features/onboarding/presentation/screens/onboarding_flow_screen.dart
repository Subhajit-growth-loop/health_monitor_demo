import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/session/onboarding_progress.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/widgets/neu_base_screen.dart';
import '../../domain/entities/patient_profile_options.dart';
import '../view_model/onboarding_view_model.dart';
import '../widgets/steps/connect_step.dart';
import '../widgets/steps/cycle_step.dart';
import '../widgets/steps/feeling_step.dart';
import '../widgets/steps/first_action_step.dart';
import '../widgets/steps/letter_step.dart';
import '../widgets/steps/motivation_step.dart';
import '../widgets/steps/note_step.dart';
import '../widgets/steps/rhythm_step.dart';
import '../widgets/steps/symptoms_step.dart';
import '../widgets/steps/verify_info_step.dart';
import 'onboarding_base_screen.dart';
import 'onboarding_complete_screen.dart';

// ── Flow screen ──────────────────────────────────────────────────────────────

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState
    extends ConsumerState<OnboardingFlowScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final msg = AppErrorHandler.instance.handle(
              next.error!,
              stackTrace: next.stackTrace,
              context: 'Load onboarding',
            ) ??
            'Could not load onboarding';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    final async = ref.watch(onboardingControllerProvider);
    return async.when(
      loading: () => const _CenteredMessage(
        child: CircularProgressIndicator(color: NeuColors.primary),
      ),
      error: (e, _) => _CenteredMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: s.textMuted, size: 48),
            SizedBox(height: 16.h),
            Text(
              'Could not load your onboarding data.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.sp, color: s.textMuted, height: 1.5),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(onboardingControllerProvider),
              style: FilledButton.styleFrom(
                backgroundColor: NeuColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: _buildStep,
    );
  }

  Widget _buildStep(OnboardingState state) {
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final draft = state.draft;

    String? heading;
    String? prompt;
    final Widget body;

    switch (state.currentStep) {
      case OnboardingStep.verifyInfo:
        heading = 'Verify your information';
        prompt =
            "Before we start, let's confirm the records your care team shared with me.";
        body = const VerifyInfoStep();
      case OnboardingStep.motivation:
        heading = 'What brought you to Neu?';
        prompt =
            'What brought you to Neu, and what kind of support are you '
            'hoping for?';
        body = MotivationStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.rhythm:
        // No serif heading on this step per design — just the Maya prompt.
        prompt = 'A few details about your everyday rhythm.';
        body = RhythmStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.cycle:
        heading = 'Which best describes your menstrual cycle?';
        prompt =
            'This helps me read your glucose and symptoms in the right context.';
        body = CycleStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.symptoms:
        heading = 'Recent symptoms';
        prompt = "Select any changes you've noticed lately.";
        body = SymptomsStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.feeling:
        heading = 'How are you feeling?';
        prompt =
            "Share how you're feeling today to help us personalize your journey.";
        body = FeelingStep(draft: draft, ctrl: ctrl);
      case OnboardingStep.note:
        // Chatbot step — Maya prompt only, no serif heading.
        prompt =
            "Share how you're feeling today to help us personalize your journey.";
        body = const NoteStep();
      case OnboardingStep.connect:
        heading = 'Connect your data';
        prompt =
            'Connect an app or device you already use so Neu can read your '
            'data automatically.';
        body = const ConnectStep();
      case OnboardingStep.letter:
        heading = 'A letter from your AI coach';
        body = const LetterStep();
      case OnboardingStep.firstAction:
        heading = 'Your first small action';
        prompt =
            "Let's pick one small thing to start with — just one. Small is "
            'how change lasts.';
        body = FirstActionStep(draft: draft, ctrl: ctrl);
    }

    return NeuOnboardingShell(
      progress: state.progress,
      stepLabel: 'STEP ${state.stepIndex + 1} / ${state.totalSteps}',
      heading: heading,
      mayaPrompt: prompt,
      showBack: !state.isFirst,
      onBack: ctrl.back,
      body: body,
      ctaLabel: state.isLast ? 'Set my first action' : 'Save & next',
      ctaLoading: _saving,
      ctaEnabled: _isStepComplete(state),
      onCta: () => _onCta(state, ctrl),
    );
  }

  /// A step's CTA stays disabled until its required inputs are answered.
  bool _isStepComplete(OnboardingState state) {
    final d = state.draft;
    switch (state.currentStep) {
      case OnboardingStep.verifyInfo:
        final p = state.profile;
        // Check what will actually be *sent*, not what is selected locally:
        // picking only "Other" without typing a name sanitizes to an empty
        // array, so the CTA must stay locked until there's a real answer.
        return p.dateOfBirth.isNotEmpty &&
            p.gender.isNotEmpty &&
            p.primaryDiagnosis.isNotEmpty &&
            p.diagnosedDate.isNotEmpty &&
            PatientProfileOptions.forApi(
              p.otherConditions,
              PatientProfileOptions.otherConditions,
            ).isNotEmpty &&
            PatientProfileOptions.forApi(
              p.currentMedications,
              PatientProfileOptions.medications,
            ).isNotEmpty &&
            PatientProfileOptions.forApi(
              p.currentSupplements,
              PatientProfileOptions.supplements,
            ).isNotEmpty;
      case OnboardingStep.feeling:
        // No validation by design. The four sliders always hold a value (they
        // default to 0.5), so there is nothing the user could fail to answer —
        // leaving them untouched is itself a valid answer.
        return true;
      case OnboardingStep.letter:
        // Read-only — nothing to answer.
        return true;
      case OnboardingStep.motivation:
        return d.motivations.isNotEmpty && d.supportTypes.isNotEmpty;
      case OnboardingStep.rhythm:
        return d.activityLevel != null &&
            d.eatingRhythm != null &&
            d.dietaryPrefs.isNotEmpty;
      case OnboardingStep.cycle:
        return d.menstrualCycle != null;
      case OnboardingStep.symptoms:
        return d.symptoms.isNotEmpty;
      case OnboardingStep.note:
        // Always enabled: the chat is optional context, so the patient can move
        // on mid-conversation. Gating on `done` also meant a server-side chat
        // failure blocked onboarding entirely, with no way past this step.
        return true;
      case OnboardingStep.connect:
        return d.connectChoice != null;
      case OnboardingStep.firstAction:
        return d.firstAction != null;
    }
  }

  Future<void> _onCta(OnboardingState state, OnboardingController ctrl) async {
    setState(() => _saving = true);
    try {
      if (state.isLast) {
        final result = await ctrl.complete();
        await OnboardingProgress.markComplete(
          ref.read(sharedPreferencesProvider),
          CurrentUser.instance.email,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingCompleteScreen(result: result),
          ),
        );
      } else if (state.currentStep == OnboardingStep.verifyInfo) {
        // PATCH /patient/me/details — see savePatientDetails() in
        // onboarding_view_model.dart. Must succeed before advancing.
        await ctrl.savePatientDetails();
        await ctrl.saveAndNext();
      } else {
        await ctrl.saveAndNext();
      }
    } catch (e, st) {
      if (mounted) {
        final msg = AppErrorHandler.instance.handle(
              e,
              stackTrace: st,
              context: 'Onboarding · ${state.currentStep.name}',
            ) ??
            'Something went wrong';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Small shared helpers ──────────────────────────────────────────────────────

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return NeuBaseScreen(
      backgroundColor: s.background,
      lightStatusIcons: s.isDark,
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Center(child: child),
      ),
    );
  }
}

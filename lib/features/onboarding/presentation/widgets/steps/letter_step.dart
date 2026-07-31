import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/current_user.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../view_model/onboarding_view_model.dart';

// ── Step 9: Letter ────────────────────────────────────────────────────────────

class LetterStep extends ConsumerWidget {
  const LetterStep({super.key});

  static const _body =
      "I'm Maya — your AI-enabled wellness coach. ✨\n\n"
      "If you've been diagnosed with MASLD, insulin resistance, or metabolic "
      "dysfunction, you're not alone. Millions of people are navigating "
      "fatigue, inflammation, weight changes, cravings, poor sleep, and "
      "changing labs without truly understanding what's happening in their "
      "bodies. Neu Health was built to support you between doctor visits — "
      "where real health change actually happens.\n\n"
      "Together, we'll use your health patterns, daily routines, movement, "
      "meals, and recovery to build small, sustainable shifts that help your "
      "body feel steadier, stronger, and healthier over time. This is "
      "intelligent support designed for real life.\n\n"
      "You've carried a lot through the years — and now it's time for some of "
      "that care to come back to you. I'll be here to guide, encourage, and "
      "adjust alongside you, one day at a time. I'm so glad you're here and "
      "honored to be on your journey to better health.\n\n"
      "With warmth,\nMaya ✨";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = NeuSurface.of(context);
    // Prefer the name on the verified profile (the user may have corrected it on
    // step 1); fall back to the name the auth response stored. Greets without a
    // name rather than showing a placeholder if neither is set.
    final profileName =
        ref.watch(onboardingControllerProvider).valueOrNull?.profile.firstName ??
            '';
    final firstName =
        profileName.isNotEmpty ? profileName : CurrentUser.instance.firstName;
    final greeting = firstName.isEmpty ? 'Hi, ' : 'Hi $firstName, ';

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: s.border),
      ),
      child: Text(
        '$greeting$_body',
        style: TextStyle(
          fontSize: 14.5.sp,
          height: 1.5,
          color: s.onSurface.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

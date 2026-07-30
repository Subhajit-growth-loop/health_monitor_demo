import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/onboarding_progress.dart';
import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../health/presentation/screens/dashboard_screen.dart';
import '../widgets/neu_dot_indicator.dart';
import '../widgets/neu_logo.dart';
import 'neu_feature_screens.dart';
import 'neu_login_screen.dart';
import 'neu_onboarding_flow_screen.dart';

class NeuSplashScreen extends ConsumerStatefulWidget {
  const NeuSplashScreen({super.key});

  @override
  ConsumerState<NeuSplashScreen> createState() => _NeuSplashScreenState();
}

class _NeuSplashScreenState extends ConsumerState<NeuSplashScreen> {
  int _dotIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animate());
  }

  void _animate() {
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _dotIndex = 1);
      Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _dotIndex = 2);
        Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _navigate();
        });
      });
    });
  }

  void _navigate() {
    final prefs = ref.read(sharedPreferencesProvider);
    final email = prefs.getString('neu_email') ?? '';
    final token = prefs.getString('neu_token') ?? '';
    final onboardingComplete = OnboardingProgress.isComplete(prefs, email);

    final Widget destination;
    if (email.isEmpty) {
      destination = const NeuFeatureScreens();
    } else if (token.isEmpty) {
      destination = const NeuLoginScreen();
    } else if (!onboardingComplete) {
      // Signed up but did not finish onboarding — resume it.
      destination = const NeuOnboardingFlowScreen();
    } else {
      destination = const DashboardScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: NeuColors.splashBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: NeuColors.splashBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed splash background image.
            Positioned.fill(
              child: Image.asset(
                'assets/images/splash_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            // Content
            Column(
              children: [
                const Spacer(flex: 2),
                NeuLogo(
                  size: 90.r,
                  asset: 'assets/icons/logo_white.png',
                  tint: false,
                ),
                SizedBox(height: 24.h),
                Text(
                  'Neu Health',
                  style: NeuTypography.serif(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Text(
                    'Your metabolic health, finally\nprecise.',
                    textAlign: TextAlign.center,
                    style: NeuTypography.serif(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36.h),
                    child: NeuDotIndicator(
                      count: 3,
                      currentIndex: _dotIndex,
                      activeColor: Colors.white,
                      dotSize: 7,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../health/presentation/screens/dashboard_screen.dart';
import '../widgets/neu_dot_indicator.dart';
import '../widgets/neu_logo.dart';
import 'neu_feature_screens.dart';
import 'neu_login_screen.dart';

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

    final Widget destination;
    if (email.isEmpty) {
      destination = const NeuFeatureScreens();
    } else if (token.isEmpty) {
      destination = const NeuLoginScreen();
    } else {
      destination = const DashboardScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
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
            // Subtle decorative ring (replace with image asset later)
            Positioned(
              bottom: -80,
              right: -80,
              child: _DecorativeRing(size: 340),
            ),
            Positioned(
              bottom: -120,
              right: -120,
              child: _DecorativeRing(size: 480),
            ),
            // Content
            Column(
              children: [
                const Spacer(flex: 2),
                NeuLogo(size: 108.r, color: Colors.white),
                SizedBox(height: 28.h),
                Text(
                  'Neu Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 14.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Text(
                    'Your metabolic health, finally precise.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 17.sp,
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

class _DecorativeRing extends StatelessWidget {
  const _DecorativeRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
    );
  }
}

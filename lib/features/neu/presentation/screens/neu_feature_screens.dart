import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../widgets/neu_dot_indicator.dart';
import '../widgets/neu_logo.dart';
import '../widgets/neu_primary_button.dart';
import 'neu_welcome_screen.dart';

class NeuFeatureScreens extends StatefulWidget {
  const NeuFeatureScreens({super.key});

  @override
  State<NeuFeatureScreens> createState() => _NeuFeatureScreensState();
}

class _NeuFeatureScreensState extends State<NeuFeatureScreens> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 0) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NeuWelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed background photo.
            Positioned.fill(
              child: Image.asset(
                'assets/images/feature_sc_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            // Subtle scrim so the headline + bottom controls stay legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x66000000),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            // Page content
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [_FeaturePage1(), _FeaturePage2()],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 28.h),
                    child: Column(
                      children: [
                        NeuDotIndicator(
                          count: 2,
                          currentIndex: _page,
                          activeColor: NeuColors.primary,
                          inactiveColor: Colors.white.withValues(alpha: 0.35),
                          dotSize: 8,
                        ),
                        SizedBox(height: 18.h),
                        NeuPrimaryButton(
                          label: _page == 0 ? 'Next' : 'Get Started',
                          onPressed: _next,
                          height: 56,
                        ),
                      ],
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

// ── Page 1 ──────────────────────────────────────────────────────────────────

class _FeaturePage1 extends StatelessWidget {
  const _FeaturePage1();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            NeuLogo(size: 64.r, color: NeuColors.primary),
            SizedBox(height: 24.h),
            RichText(
              text: TextSpan(
                style: NeuTypography.serif(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.12,
                ),
                children: [
                  const TextSpan(text: 'Your metabolic\nhealth,\n'),
                  TextSpan(
                    text: 'finally precise.',
                    style: NeuTypography.serif(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.primary,
                      height: 1.12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22.h),
            Text(
              'Personalized coaching for people managing MASLD — '
              'guided by your own data and Maya, your AI health coach.',
              style: TextStyle(
                fontSize: 15.5.sp,
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.55,
              ),
            ),
            SizedBox(height: 160.h),
          ],
        ),
      ),
    );
  }
}

// ── Page 2 ──────────────────────────────────────────────────────────────────

class _FeaturePage2 extends StatelessWidget {
  const _FeaturePage2();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 48.h),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: NeuColors.accentYellow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'HOW NEU WORKS',
                style: TextStyle(
                  color: NeuColors.olive,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Small, followable steps\n– built around you.',
              style: NeuTypography.serif(
                fontSize: 30.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.18,
              ),
            ),
            SizedBox(height: 36.h),
            _FeatureItem(
              icon: Icon(
                Icons.water_drop_outlined,
                color: NeuColors.primary,
                size: 24,
              ),
              title: 'Your data, understood',
              subtitle: 'Glucose, movement and sleep sync automatically.',
            ),
            SizedBox(height: 22.h),
            _FeatureItem(
              icon: NeuLogo(size: 26.r, color: NeuColors.primary),
              title: 'Guided by Maya',
              subtitle: 'A warm AI coach who adapts to what your body shows.',
            ),
            SizedBox(height: 22.h),
            _FeatureItem(
              icon: Icon(
                Icons.task_alt_rounded,
                color: NeuColors.primary,
                size: 24,
              ),
              title: 'Progress that lasts',
              subtitle: 'Short treatment cycles you can actually keep up with.',
            ),
            SizedBox(height: 60.h),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: icon,
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13.5.sp,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

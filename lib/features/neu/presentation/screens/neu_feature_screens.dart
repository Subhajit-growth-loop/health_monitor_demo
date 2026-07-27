import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../widgets/neu_dot_indicator.dart';
import '../widgets/neu_image_placeholder.dart';
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
          duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
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
        systemNavigationBarColor: NeuColors.featureBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: NeuColors.featureBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background photo placeholder (replace with Image.asset later)
            Positioned.fill(
              child: NeuImagePlaceholder(
                icon: Icons.person_rounded,
                backgroundColor: const Color(0xFF2A1A10),
                iconColor: const Color(0xFF4A3020),
                borderRadius: BorderRadius.zero,
              ),
            ),
            // Dark gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA1C1008),
                    Color(0xCC1C1008),
                    Color(0xFF1C1008),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Page content
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [
                      _FeaturePage1(),
                      _FeaturePage2(),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
                    child: Column(
                      children: [
                        NeuDotIndicator(
                          count: 2,
                          currentIndex: _page,
                          activeColor: Colors.white,
                          dotSize: 7,
                        ),
                        SizedBox(height: 20.h),
                        NeuPrimaryButton(
                          label: _page == 0 ? 'Next' : 'Get Started',
                          onPressed: _next,
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
            SizedBox(height: 16.h),
            NeuLogo(size: 44.r, color: NeuColors.primary),
            const Spacer(),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
                children: const [
                  TextSpan(text: 'Your metabolic\nhealth, '),
                  TextSpan(
                    text: 'finally\nprecise.',
                    style: TextStyle(color: NeuColors.primary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Personalized coaching for people managing MASLD — '
              'guided by your own data and Maya, your AI health coach.',
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.6,
              ),
            ),
            SizedBox(height: 80.h),
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
            SizedBox(height: 16.h),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'HOW NEU WORKS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Small, followable\nsteps – built\naround you.',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 32.h),
            _FeatureItem(
              icon: Icons.water_drop_rounded,
              title: 'Your data, understood',
              subtitle:
                  'Glucose, movement and sleep sync automatically.',
            ),
            SizedBox(height: 20.h),
            _FeatureItem(
              icon: Icons.self_improvement_rounded,
              title: 'Guided by Maya',
              subtitle:
                  'A warm AI coach who adapts to what your body shows.',
            ),
            SizedBox(height: 20.h),
            _FeatureItem(
              icon: Icons.track_changes_rounded,
              title: 'Progress that lasts',
              subtitle:
                  'Short treatment cycles you can actually keep up with.',
            ),
            SizedBox(height: 80.h),
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

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NeuColors.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: NeuColors.primary, size: 22),
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
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13.sp,
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

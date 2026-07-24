import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/theme/neu_colors.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_logo.dart';
import '../widgets/neu_primary_button.dart';
import '../widgets/neu_text_field.dart';
import 'neu_login_screen.dart';
import 'neu_onboarding_base_screen.dart';

class NeuWelcomeScreen extends StatefulWidget {
  const NeuWelcomeScreen({super.key});

  @override
  State<NeuWelcomeScreen> createState() => _NeuWelcomeScreenState();
}

class _NeuWelcomeScreenState extends State<NeuWelcomeScreen> {
  final _codeController = TextEditingController();
  _CodeState _codeState = _CodeState.idle;
  String _verifiedName = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() => _codeState = _CodeState.idle);
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    // Simulate network call — replace with real API
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // Mock: any non-empty code is "valid"
      _codeState = _CodeState.verified;
      _verifiedName = 'Harry';
    });
  }

  void _startOnboarding() {
    if (_codeState != _CodeState.verified) {
      _verifyCode();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NeuOnboardingBaseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuBaseScreen(
      backgroundColor: NeuColors.screenBackground,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 32.h),
            Center(
              child: NeuLogo(size: 72.r, color: NeuColors.primary),
            ),
            SizedBox(height: 12.h),
            Center(
              child: Text(
                'Neu Health',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: NeuColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SizedBox(height: 36.h),
            Text(
              'Welcome to Neu',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: NeuColors.textDark,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Enter the referral code from your care team to begin your onboarding.',
              style: TextStyle(
                fontSize: 15.sp,
                color: NeuColors.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            NeuTextField(
              controller: _codeController,
              label: 'Referral Code',
              hint: 'e.g. NEU-7F2A',
              onChanged: _onCodeChanged,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyCode(),
              suffixIcon: _codeState == _CodeState.verified
                  ? Container(
                      margin: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: NeuColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                    )
                  : null,
            ),
            if (_codeState == _CodeState.verified) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: NeuColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Code verified - welcome, $_verifiedName.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: NeuColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            NeuPrimaryButton(
              label: _codeState == _CodeState.verified
                  ? 'Start Onboarding'
                  : 'Verify Code',
              onPressed: _startOnboarding,
              isLoading: _isLoading,
            ),
            SizedBox(height: 20.h),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const NeuLoginScreen()),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: NeuColors.textSecondary,
                    ),
                    children: const [
                      TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Log In',
                        style: TextStyle(
                          color: NeuColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

enum _CodeState { idle, verified }

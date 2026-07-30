import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/app_error_handler.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_logo.dart';
import '../widgets/neu_primary_button.dart';
import '../widgets/neu_text_field.dart';
import 'neu_create_password_screen.dart';
import 'neu_login_screen.dart';

class NeuWelcomeScreen extends ConsumerStatefulWidget {
  const NeuWelcomeScreen({super.key});

  @override
  ConsumerState<NeuWelcomeScreen> createState() => _NeuWelcomeScreenState();
}

class _NeuWelcomeScreenState extends ConsumerState<NeuWelcomeScreen> {
  final _codeController = TextEditingController();
  _CodeState _codeState = _CodeState.idle;
  String _verifiedEmail = '';
  bool _isLoading = false;
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() {
      _codeState = _CodeState.idle;
      _codeError = null;
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter the referral code');
      return;
    }

    setState(() {
      _isLoading = true;
      _codeError = null;
    });
    try {
      final result = await ref
          .read(onboardingRepositoryProvider)
          .verifyReferral(code);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result.valid) {
          _codeState = _CodeState.verified;
          _verifiedEmail = result.email ?? '';
        } else {
          _codeState = _CodeState.idle;
        }
      });
      if (!result.valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That referral code was not recognised.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _codeError =
            AppErrorHandler.instance.handle(e, context: 'Verify referral') ??
                'Code not recognised';
      });
    }
  }

  void _startOnboarding() {
    if (_codeState != _CodeState.verified) {
      _verifyCode();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NeuCreatePasswordScreen(
          referralCode: _codeController.text.trim(),
          initialEmail: _verifiedEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuBaseScreen(
      backgroundColor: NeuColors.darkBackground,
      backgroundImage: 'assets/images/auth_sc_dark_bg.png',
      lightStatusIcons: true,
      navigationBarColor: NeuColors.darkBackground,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 32.h),
                  Center(
                    child: NeuLogo(
                      size: 60.r,
                      color: NeuColors.primary,
                      asset: 'assets/icons/logo_white.png',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: Text(
                      'Neu Health',
                      style: NeuTypography.serif(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    'Welcome to Neu',
                    style: NeuTypography.serif(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter the referral code from your care team to begin your onboarding.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white60,
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
                    errorText: _codeError,
                    dark: true,
                    maxLength: 8,
                    suffixIcon: _codeState == _CodeState.verified
                        ? Container(
                            margin: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: NeuColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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
                        Expanded(
                          child: Text(
                            'Code verified — continue as $_verifiedEmail',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: NeuColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
          // Pinned bottom actions.
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
            child: Column(
              children: [
                NeuPrimaryButton(
                  label: _codeState == _CodeState.verified
                      ? 'Continue'
                      : 'Verify Code',
                  onPressed: _startOnboarding,
                  isLoading: _isLoading,
                ),
                SizedBox(height: 20.h),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const NeuLoginScreen()),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white60,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _CodeState { idle, verified }

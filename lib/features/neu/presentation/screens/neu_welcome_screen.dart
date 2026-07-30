import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/app_error_handler.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../onboarding/domain/entities/referral_code_formatter.dart';
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
  bool _isLoading = false;
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String _) {
    if (_codeError != null) setState(() => _codeError = null);
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
      setState(() => _isLoading = false);
      if (result.valid) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NeuCreatePasswordScreen(
              referralCode: code,
              initialEmail: result.email ?? '',
              showVerifiedBanner: true,
            ),
          ),
        );
      } else {
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

  @override
  Widget build(BuildContext context) {
    final s = NeuSurface.of(context);
    return NeuBaseScreen(
      backgroundColor: s.background,
      backgroundImage: s.isDark
          ? 'assets/images/auth_sc_dark_bg.png'
          : 'assets/images/auth_sc_bg.png',
      lightStatusIcons: s.isDark,
      navigationBarColor: s.background,
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
                      asset: s.isDark
                    ? 'assets/icons/logo_white.png'
                    : 'assets/icons/logo_primary.png',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: Text(
                      'Neu Health',
                      style: NeuTypography.serif(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface,
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
                      color: s.textMuted,
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
                    // Upper-cases and inserts the hyphen after `NEU`, on typing
                    // and on paste. The keyboard hint matches so the shift key
                    // isn't fighting the formatter.
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: const [ReferralCodeFormatter()],
                    maxLength: 8,
                  ),
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
                  label: 'Verify Code',
                  onPressed: _verifyCode,
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
                        color: s.textMuted,
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


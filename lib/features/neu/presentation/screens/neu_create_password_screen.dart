import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/session/app_error_handler.dart';
import '../../../../../core/session/current_user.dart';
import '../../../../../core/session/onboarding_progress.dart';
import '../../../../../core/session/token_manager.dart';
import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../../../core/theme/neu_typography.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_primary_button.dart';
import '../widgets/neu_text_field.dart';
import 'neu_login_screen.dart';
import 'neu_onboarding_flow_screen.dart';

/// Account-creation step shown after the referral code is verified and before
/// the guided onboarding begins. Collects the user's email and a password,
/// signs the account up via the API, then hands off to
/// [NeuOnboardingFlowScreen].
class NeuCreatePasswordScreen extends ConsumerStatefulWidget {
  const NeuCreatePasswordScreen({
    super.key,
    this.initialEmail,
    this.referralCode,
  });

  final String? initialEmail;
  final String? referralCode;

  @override
  ConsumerState<NeuCreatePasswordScreen> createState() =>
      _NeuCreatePasswordScreenState();
}

class _NeuCreatePasswordScreenState
    extends ConsumerState<NeuCreatePasswordScreen> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    String? emailErr;
    String? passErr;
    String? confirmErr;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      emailErr = 'Email is required';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'Enter a valid email address';
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      passErr = 'Password is required';
    } else if (password.length < 8) {
      passErr = 'Use at least 8 characters';
    }

    if (_confirmController.text.isEmpty) {
      confirmErr = 'Confirm your password';
    } else if (_confirmController.text != password) {
      confirmErr = 'Passwords do not match';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
      _confirmError = confirmErr;
    });
    return emailErr == null && passErr == null && confirmErr == null;
  }

  Future<void> _startOnboarding() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Step 1: Register the account
      final registered = await repo.signup(
        email: email,
        password: password,
        referralCode: widget.referralCode,
        confirmPassword: _confirmController.text,
      );

      // Step 2: Login to get an auth token (register response has no token)
      final auth = await repo.login(email: email, password: password);

      await TokenManager.instance.setTokens(
        accessToken: auth.token.isNotEmpty ? auth.token : registered.userId,
        refreshToken: auth.refreshToken,
      );
      await CurrentUser.instance.set(
        id: auth.userId.isNotEmpty ? auth.userId : registered.userId,
        email: email,
        name: auth.name ?? registered.name ?? '',
        role: auth.role ?? registered.role ?? '',
        gender: auth.gender ?? '',
      );
      // Fresh account — start the flow at step 1 with no saved answers.
      final prefs = ref.read(sharedPreferencesProvider);
      await OnboardingProgress.markIncomplete(prefs, email);
      await OnboardingProgress.clearDraft(prefs, email);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NeuOnboardingFlowScreen()),
      );
    } catch (e) {
      if (mounted) {
        final msg = AppErrorHandler.instance.handle(e, context: 'Sign up') ??
            'Sign up failed';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuBaseScreen(
      backgroundColor: NeuColors.darkBackground,
      backgroundImage: 'assets/images/auth_sc_dark_bg.png',
      lightStatusIcons: true,
      navigationBarColor: NeuColors.darkBackground,
      resizeToAvoidBottomInset: true,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12.h),
                  _BackButton(onTap: () => Navigator.of(context).maybePop()),
                  SizedBox(height: 20.h),
                  Text(
                    'Create a Password',
                    style: NeuTypography.serif(
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w700,
                      color: NeuColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Set the email and password you\'ll use to sign in to '
                    'your Neu Health account.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  NeuTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    errorText: _emailError,
                    dark: true,
                    onChanged: (_) => setState(() => _emailError = null),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: NeuColors.darkTextMuted,
                      size: 20,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  NeuTextField(
                    controller: _passwordController,
                    label: 'New Password',
                    hint: 'New Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    errorText: _passwordError,
                    dark: true,
                    onChanged: (_) => setState(() => _passwordError = null),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: NeuColors.darkTextMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: NeuColors.darkTextMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  NeuTextField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    hint: 'Confirm Password',
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    errorText: _confirmError,
                    dark: true,
                    onChanged: (_) => setState(() => _confirmError = null),
                    onSubmitted: (_) => _startOnboarding(),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: NeuColors.darkTextMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: NeuColors.darkTextMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
            child: Column(
              children: [
                NeuPrimaryButton(
                  label: 'Start Onboarding',
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.r,
        height: 44.r,
        decoration: BoxDecoration(
          color: NeuColors.darkCard,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: NeuColors.darkBorder),
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

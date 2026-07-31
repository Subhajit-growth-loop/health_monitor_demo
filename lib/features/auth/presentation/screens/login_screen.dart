import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/session/app_error_handler.dart';
import '../../../../core/session/current_user.dart';
import '../../../../core/session/onboarding_progress.dart';
import '../../../../core/session/token_manager.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/neu_colors.dart';
import '../../../../core/theme/neu_typography.dart';
import '../../../onboarding/presentation/view_model/onboarding_view_model.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../core/widgets/neu_base_screen.dart';
import '../../../../core/widgets/neu_logo.dart';
import '../../../../core/widgets/neu_primary_button.dart';
import '../../../../core/widgets/neu_text_field.dart';
import '../../../onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    String? emailErr;
    String? passErr;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      emailErr = 'Email is required';
    } else if (!email.contains('@')) {
      emailErr = 'Enter a valid email address';
    }

    if (_passwordController.text.isEmpty) {
      passErr = 'Password is required';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });
    return emailErr == null && passErr == null;
  }

  Future<void> _login() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final auth = await ref
          .read(onboardingRepositoryProvider)
          .login(email: email, password: _passwordController.text);

      await TokenManager.instance.setTokens(
        accessToken: auth.token,
        refreshToken: auth.refreshToken,
        expiresIn: auth.expiresIn,
      );
      await CurrentUser.instance.set(
        id: auth.userId,
        email: auth.email ?? email,
        name: auth.name ?? '',
        role: auth.role ?? '',
        gender: auth.gender ?? '',
      );
      // Resume onboarding if this email never finished it — the saved step and
      // answers are restored by the onboarding controller.
      final prefs = ref.read(sharedPreferencesProvider);
      final done = OnboardingProgress.isComplete(prefs, auth.email ?? email);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => done
              ? const DashboardScreen()
              : const OnboardingFlowScreen(),
        ),
      );
    } catch (e) {
      if (mounted) {
        final msg = AppErrorHandler.instance.handle(e, context: 'Login') ??
            'Login failed';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset coming soon.')),
    );
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
      resizeToAvoidBottomInset: true,
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
              'Welcome Back!',
              style: NeuTypography.serif(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: NeuColors.primary,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 24.h),
            NeuTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _emailError,
              onChanged: (_) => setState(() => _emailError = null),
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: s.textMuted,
                size: 20,
              ),
            ),
            SizedBox(height: 16.h),
            NeuTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _passwordError,
              onChanged: (_) => setState(() => _passwordError = null),
              onSubmitted: (_) => _login(),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: s.textMuted,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: s.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: _forgotPassword,
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: s.textMuted,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 28.h),
            NeuPrimaryButton(
              label: 'Log In',
              onPressed: _login,
              isLoading: _isLoading,
            ),
            SizedBox(height: 20.h),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: s.textMuted,
                    ),
                    children: const [
                      TextSpan(text: 'I have a '),
                      TextSpan(
                        text: 'referral code',
                        style: TextStyle(
                          color: NeuColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' instead'),
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

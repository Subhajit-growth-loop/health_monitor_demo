import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/settings/app_settings.dart';
import '../../../../../core/theme/neu_colors.dart';
import '../../../health/presentation/screens/dashboard_screen.dart';
import '../widgets/neu_base_screen.dart';
import '../widgets/neu_logo.dart';
import '../widgets/neu_primary_button.dart';
import '../widgets/neu_text_field.dart';
import 'neu_welcome_screen.dart';

class NeuLoginScreen extends ConsumerStatefulWidget {
  const NeuLoginScreen({super.key});

  @override
  ConsumerState<NeuLoginScreen> createState() => _NeuLoginScreenState();
}

class _NeuLoginScreenState extends ConsumerState<NeuLoginScreen> {
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
    // Simulate network call — replace with real API
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // Mock: store credentials and navigate to dashboard
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('neu_email', _emailController.text.trim());
    await prefs.setString('neu_token', 'mock_token_${DateTime.now().millisecondsSinceEpoch}');

    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuBaseScreen(
      backgroundColor: NeuColors.screenBackground,
      resizeToAvoidBottomInset: true,
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
              'Welcome Back!',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                color: NeuColors.textDark,
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
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                color: NeuColors.textMuted,
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
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: NeuColors.textMuted,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: NeuColors.textMuted,
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
                  color: NeuColors.primaryDark,
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
                  MaterialPageRoute(builder: (_) => const NeuWelcomeScreen()),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: NeuColors.textSecondary,
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

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'widgets/social_media_card.dart';

/// US-04, US-05, US-06, US-07: Authentication Sign-In Screen
class LoginScreen extends StatefulWidget {
  final VoidCallback onToRegistration;
  final VoidCallback onToForgotPassword;
  final Function(String email) onLoginSuccess;
  final VoidCallback onSkipAuth;
  final bool initialRememberDevice;
  final ValueChanged<bool>? onRememberDeviceChanged;

  const LoginScreen({
    super.key,
    required this.onToRegistration,
    required this.onToForgotPassword,
    required this.onLoginSuccess,
    required this.onSkipAuth,
    this.initialRememberDevice = true,
    this.onRememberDeviceChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late bool _rememberDevice;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rememberDevice = widget.initialRememberDevice;
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRememberDevice != widget.initialRememberDevice) {
      _rememberDevice = widget.initialRememberDevice;
    }
  }

  void _handleSignIn() {
    final input = _identifierController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email or Nepali mobile number.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }

    widget.onRememberDeviceChanged?.call(_rememberDevice);
    widget.onLoginSuccess(input);
  }

  void _handleGoogleSignIn() {
    widget.onRememberDeviceChanged?.call(_rememberDevice);
    widget.onLoginSuccess('citizen.google@wakil.ai');
  }

  void _toggleRememberDevice(bool? value) {
    final nextValue = value ?? widget.initialRememberDevice;
    setState(() {
      _rememberDevice = nextValue;
    });
    widget.onRememberDeviceChanged?.call(nextValue);
  }

  InputDecoration _buildFieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryBlack,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePure,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('login_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlack,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.balance,
                        color: AppColors.surfacePure,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to Wakil',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 30 / 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to access your legal queries and saved statutes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 21 / 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // US-04: Email / Phone Input
                  const Text(
                    'Email or Mobile (+977)',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('email_phone_input'),
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _buildFieldDecoration(
                      hintText: 'name@example.com or 98XXXXXXXX',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // US-04 & US-05: Password Input with Toggle
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('password_input'),
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _buildFieldDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        key: const Key('password_visibility_toggle'),
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // US-07: Remember Device Checkbox & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              key: const Key('remember_device_checkbox'),
                              value: _rememberDevice,
                              activeColor: AppColors.primaryBlack,
                              checkColor: AppColors.surfacePure,
                              side: const BorderSide(
                                color: AppColors.textMuted,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: _toggleRememberDevice,
                            ),
                            Flexible(
                              child: GestureDetector(
                                onTap: () =>
                                    _toggleRememberDevice(!_rememberDevice),
                                child: const Text(
                                  'Remember Device',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('forgot_password_button'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryBlack,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: widget.onToForgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.crimsonError,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              key: const Key('auth_error_message'),
                              style: const TextStyle(
                                color: AppColors.onErrorContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  // Submit Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('sign_in_submit_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack,
                        foregroundColor: AppColors.surfacePure,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _handleSignIn,
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.surfaceHighest,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'or continue with',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.surfaceHighest,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // US-06: Google OAuth / Social Sign-In Pill
                  SocialMediaCard(
                    key: const Key('google_signin_button'),
                    label: 'Continue with Google',
                    icon: Icons.account_circle,
                    onTap: _handleGoogleSignIn,
                  ),
                  const SizedBox(height: 12),

                  // US-07: Skip Auth (Test Mode)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('skip_auth_test_mode_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                          color: AppColors.surfaceHighest,
                          width: 1,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: widget.onSkipAuth,
                      child: const Text(
                        'Skip Auth (Test Mode)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation to Sign Up (US-08)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      InkWell(
                        key: const Key('to_signup_button'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: widget.onToRegistration,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: AppColors.primaryBlack,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

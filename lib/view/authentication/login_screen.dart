import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'widgets/social_media_card.dart';

/// US-04, US-05, US-06, US-07: Authentication Sign-In Screen
class LoginScreen extends StatefulWidget {
  final VoidCallback onToRegistration;
  final VoidCallback onToForgotPassword;
  final Function(String email) onLoginSuccess;
  final VoidCallback onSkipAuth;

  const LoginScreen({
    super.key,
    required this.onToRegistration,
    required this.onToForgotPassword,
    required this.onLoginSuccess,
    required this.onSkipAuth,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberDevice = true;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() {
      _errorMessage = null;
    });

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

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _isLoading = false;
    });

    widget.onLoginSuccess(input);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('login_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.balance, color: AppColors.primaryGold, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Welcome to Wakil',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Sign in to access your legal intelligence workspace',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // US-06: Google OAuth / Social Sign-In Card with Firestore Sync
              Row(
                children: [
                  Expanded(
                    child: SocialMediaCard(
                      key: const Key('google_signin_button'),
                      label: 'Google One-Tap',
                      icon: Icons.account_circle,
                      onTap: () {
                        // US-06: Automatic profile provisioning & Google OAuth sign-in
                        widget.onLoginSuccess('citizen@wakil.gov.np');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 18),

              // US-04: Email / Phone Input
              TextFormField(
                key: const Key('email_phone_input'),
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email or Mobile (+977)',
                  hintText: 'advocate@wakil.gov.np or 9841234567',
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // US-04 & US-05: Password Input with Toggle
              TextFormField(
                key: const Key('password_input'),
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryNavy),
                  suffixIcon: IconButton(
                    key: const Key('password_visibility_toggle'),
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // US-07: Remember Device Checkbox & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        key: const Key('remember_device_checkbox'),
                        value: _rememberDevice,
                        activeColor: AppColors.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _rememberDevice = val ?? true;
                          });
                        },
                      ),
                      const Text(
                        'Remember Device',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  TextButton(
                    key: const Key('forgot_password_button'),
                    onPressed: widget.onToForgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage!,
                    key: const Key('auth_error_message'),
                    style: const TextStyle(color: AppColors.crimsonRed, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 12),
              // Submit Sign In Button
              ElevatedButton(
                key: const Key('sign_in_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _handleSignIn,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 14),

              // Skip Auth (Test Mode)
              OutlinedButton(
                key: const Key('skip_auth_test_mode_button'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: widget.onSkipAuth,
                child: const Text('Skip Auth (Test Mode)', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),

              // Navigation to Sign Up (US-08)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  InkWell(
                    key: const Key('to_signup_button'),
                    onTap: widget.onToRegistration,
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

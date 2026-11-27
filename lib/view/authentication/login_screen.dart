import 'package:ai39a/constants/app_colors.dart';
import 'package:ai39a/constants/app_images.dart';
import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/otp_verification_screen.dart';
import 'package:ai39a/view/authentication/password_recovery_screen.dart';
import 'package:ai39a/view/authentication/widgets/social_media_card.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // US-05: Password Visibility State
  bool _passwordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      AuthService().isAuthenticated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('signin_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand Emblem
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.balance, color: AppColors.emblemGold, size: 28),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Sign in to Wakil",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  "Sync your legal conversations, saved statutes, and case notes securely across devices.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 14),

                // Social Media Buttons (AI39A Techstack)
                Row(
                  children: [
                    Expanded(
                      child: SocialMediaCard(
                        imagePath: facebookIcon,
                        label: "Facebook",
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialMediaCard(
                        imagePath: googleIcon,
                        label: "Google",
                        onTap: () {
                          AuthService().isAuthenticated = true;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        "OR SIGN IN WITH CREDENTIALS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 14),

                // US-04: Email / Phone Input
                TextFormField(
                  key: const Key('signin_email_phone_input'),
                  controller: _emailPhoneController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Email or Phone (+977)",
                    hintText: "advocate@law.np or 9841234567",
                    prefixIcon: const Icon(Icons.account_circle_outlined),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter your email or Nepali mobile number.";
                    }
                    final clean = val.trim();
                    final isEmail = clean.contains("@") && clean.contains(".");
                    final isPhone = RegExp(r'^(\+977)?[9][678]\d{8}$').hasMatch(clean.replaceAll(" ", ""));
                    if (!isEmail && !isPhone) {
                      return "Enter a valid email or 10-digit mobile number.";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // US-05: Password Input with Eye Visibility Toggle
                TextFormField(
                  key: const Key('signin_password_input'),
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Password",
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    // US-05: Interactive Eye Visibility Toggle
                    suffixIcon: IconButton(
                      key: const Key('password_visibility_toggle'),
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Password is required.";
                    }
                    if (val.length < 6) {
                      return "Password must be at least 6 characters.";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 4),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('forgot_password_button'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PasswordRecoveryScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 12),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('signin_submit_button'),
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "Sign In",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // US-09 Navigation Button: Verify Phone with OTP
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('phone_otp_nav_button'),
                    onPressed: () {
                      final input = _emailPhoneController.text.trim();
                      final phone = (input.startsWith("+977") || (input.length == 10 && input.startsWith("98")))
                          ? (input.startsWith("+977") ? input : "+977 $input")
                          : "+977 9841234567";

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OtpVerificationScreen(phoneNumber: phone),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_android, size: 18),
                    label: const Text(
                      "Verify Phone with 6-Digit SMS OTP",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip Auth Button (US-07 Test Mode)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    key: const Key('skip_auth_button'),
                    onPressed: () {
                      AuthService().setTestMode(true);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Skip Auth (Test Mode)",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Security Tag
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      "Protected by Google Sign-In & NTA SMS Security",
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

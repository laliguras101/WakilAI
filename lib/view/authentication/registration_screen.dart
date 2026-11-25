import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-08: Registration – User Account Sign-Up Screen (Swiss / Gemini Light Monochrome)
class RegistrationScreen extends StatefulWidget {
  final VoidCallback onToSignIn;
  final Function(String fullName, String email, String phone, String password)
      onRegistrationSuccess;

  const RegistrationScreen({
    super.key,
    required this.onToSignIn,
    required this.onRegistrationSuccess,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  String? _errorMessage;

  void _validateAndSubmit() {
    setState(() {
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone =
        _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Full Name is required.';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    final digitsOnly = phone.startsWith('+977') ? phone.substring(4) : phone;
    if (digitsOnly.length != 10 ||
        (!digitsOnly.startsWith('98') && !digitsOnly.startsWith('97'))) {
      setState(() {
        _errorMessage =
            'Please enter a valid 10-digit Nepali mobile number (starts with 98 or 97).';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    final formattedPhone = phone.startsWith('+977') ? phone : '+977$digitsOnly';
    widget.onRegistrationSuccess(name, email, formattedPhone, password);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textOnVariant,
        ),
      ),
    );
  }

  InputDecoration _buildPillInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9999),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 0),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      border: pillBorder,
      enabledBorder: pillBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: const BorderSide(color: AppColors.primaryBlack, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePure,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Swiss top bar with circular back button & WAKIL pill badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      key: const Key('registration_back_button'),
                      onPressed: widget.onToSignIn,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceLow,
                        foregroundColor: AppColors.textPrimary,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 19),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.balance,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'WAKIL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.55,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Registration Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          key: Key('registration_title'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                            height: 28 / 24,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Get instant legal reference and document guidance',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 18 / 13,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Full Name
                        _buildFieldLabel('Full Name'),
                        TextFormField(
                          key: const Key('registration_name_input'),
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _buildPillInputDecoration(
                            hintText: 'e.g. Bhugol Gautam',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                Icons.person_outline,
                                size: 19,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Email Address
                        _buildFieldLabel('Email Address'),
                        TextFormField(
                          key: const Key('registration_email_input'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _buildPillInputDecoration(
                            hintText: 'name@example.com',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                Icons.mail_outline,
                                size: 19,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Nepali Mobile Number with +977 pill prefix
                        _buildFieldLabel('Mobile Number'),
                        TextFormField(
                          key: const Key('registration_phone_input'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _buildPillInputDecoration(
                            hintText: '98XXXXXXXX',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: const Text(
                                  '+977',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Password with visibility toggle
                        _buildFieldLabel('Password'),
                        TextFormField(
                          key: const Key('registration_password_input'),
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _buildPillInputDecoration(
                            hintText: 'Minimum 6 characters',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                Icons.lock_outline,
                                size: 19,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: IconButton(
                                key: const Key('registration_password_toggle'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
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
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(14),
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
                                    key: const Key('registration_error_message'),
                                    style: const TextStyle(
                                      color: AppColors.onErrorContainer,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('registration_submit_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlack,
                              foregroundColor: AppColors.surfacePure,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _validateAndSubmit,
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            InkWell(
                              key: const Key('to_signin_button'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: widget.onToSignIn,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: AppColors.primaryBlack,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

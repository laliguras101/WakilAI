import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-08: Registration – User Account Sign-Up Composable/Screen
class RegistrationScreen extends StatefulWidget {
  final VoidCallback onToSignIn;
  final Function(String fullName, String email, String phone, String password) onRegistrationSuccess;

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
    final phone = _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
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
    if (digitsOnly.length != 10 || (!digitsOnly.startsWith('98') && !digitsOnly.startsWith('97'))) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit Nepali mobile number (starts with 98 or 97).';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('registration_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: widget.onToSignIn,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1, color: AppColors.primaryGold, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Create Wakil Account',
                  key: Key('registration_title'),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Join Nepal\'s AI-powered legal intelligence network',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                key: const Key('registration_name_input'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'e.g. Bhugol Gautam',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                key: const Key('registration_email_input'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g. bhugol.gautam1@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Nepali Mobile Number
              TextFormField(
                key: const Key('registration_phone_input'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nepali Mobile Number (+977)',
                  hintText: '9841234567 or +977 9841234567',
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Password with Toggle
              TextFormField(
                key: const Key('registration_password_input'),
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Minimum 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryNavy),
                  suffixIcon: IconButton(
                    key: const Key('registration_password_toggle'),
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage!,
                    key: const Key('registration_error_message'),
                    style: const TextStyle(color: AppColors.crimsonRed, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('registration_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _validateAndSubmit,
                child: const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  InkWell(
                    key: const Key('to_signin_button'),
                    onTap: widget.onToSignIn,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

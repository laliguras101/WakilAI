import 'package:ai39a/constants/app_colors.dart';
import 'package:ai39a/services/auth_service.dart';
import 'package:flutter/material.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _revokeOtherSessions = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int get _passwordStrength {
    final password = _newPasswordController.text;
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_~`\-+=/\\]').hasMatch(password)) score++;

    if (score == 0 && password.isNotEmpty) score = 1;
    if (password.length < 6 && score > 1) score = 1;
    return score.clamp(0, 4);
  }

  String _getStrengthLabel(int strength) {
    switch (strength) {
      case 1:
        return 'WEAK KEY';
      case 2:
        return 'FAIR KEY';
      case 3:
        return 'GOOD KEY';
      case 4:
        return 'STRONG KEY';
      default:
        return 'PASSWORD STRENGTH';
    }
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 1:
        return AppColors.error;
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF0D9488);
      case 4:
        return AppColors.success;
      default:
        return AppColors.cardBorder;
    }
  }

  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  Future<void> _handleUpdatePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a new password.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().updatePasswordWithRevocation(
        newPassword: newPassword,
        revokeOtherSessions: _revokeOtherSessions,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully. Please sign in.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength;
    final strengthColor = _getStrengthColor(strength);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Reset Password",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Scales of Justice Emblem
                Container(
                  key: const Key('scales_of_justice_emblem'),
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.balance, color: AppColors.emblemGold, size: 34),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Create new password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ensure your legal account remains secure with an updated, high-entropy key.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                // Field 1: New Password
                TextFormField(
                  key: const Key('new_password_field'),
                  controller: _newPasswordController,
                  obscureText: !_newPasswordVisible,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      key: const Key('toggle_new_password_visibility'),
                      icon: Icon(
                        _newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _newPasswordVisible = !_newPasswordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // Dynamic 4-Bar Strength Meter
                Column(
                  key: const Key('password_strength_meter'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(4, (index) {
                        final isLit = index < strength;
                        final barColor = isLit ? strengthColor : const Color(0xFFE2E8F0);
                        return Expanded(
                          child: Container(
                            key: Key('strength_bar_$index'),
                            margin: EdgeInsets.only(right: index < 3 ? 6.0 : 0.0),
                            height: 6,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getStrengthLabel(strength),
                          key: const Key('password_strength_label'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: strength > 0 ? strengthColor : AppColors.textSecondary,
                          ),
                        ),
                        const Text(
                          'Min. 8 chars, mixed cases & symbols',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Field 2: Confirm Password
                TextFormField(
                  key: const Key('confirm_password_field'),
                  controller: _confirmPasswordController,
                  obscureText: !_confirmPasswordVisible,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      key: const Key('toggle_confirm_password_visibility'),
                      icon: Icon(
                        _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // Match Indicator
                if (_confirmPasswordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    key: const Key('match_indicator'),
                    children: [
                      Icon(
                        _passwordsMatch ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: _passwordsMatch ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _passwordsMatch ? 'Passwords match securely' : 'Passwords do not match',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _passwordsMatch ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Security Micro-Context Card ('Active Session Renewal')
                Container(
                  key: const Key('active_session_renewal_card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Session Renewal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Updating your credentials will invalidate previous queries across auxiliary browsers.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        key: const Key('global_session_revocation_toggle'),
                        value: _revokeOtherSessions,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                        onChanged: (val) {
                          setState(() {
                            _revokeOtherSessions = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    key: const Key('recovery_error_message'),
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Button: Update Password
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('update_password_button'),
                    onPressed: _isLoading ? null : _handleUpdatePassword,
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
                            'Update Password',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Link: Cancel and return to Sign in
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    key: const Key('cancel_button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel and return to Sign in',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-12 & US-13: Password Recovery Screen & Password Strength Gauge
class PasswordRecoveryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String identity, String newPassword, bool revokeAllSessions) onResetSuccess;

  const PasswordRecoveryScreen({
    super.key,
    required this.onBack,
    required this.onResetSuccess,
  });

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isIdentityVerified = false;
  bool _isPasswordVisible = false;
  bool _revokeAllSessions = true;
  String? _errorMessage;
  String? _statusMessage;

  // US-12: 4-Bar Strength evaluation logic
  int _evaluatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]')) || password.length >= 12) score++;
    return score.clamp(1, 4);
  }

  void _verifyIdentity() {
    setState(() {
      _errorMessage = null;
    });
    final identity = _identityController.text.trim();
    if (identity.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your registered email or phone.';
      });
      return;
    }
    setState(() {
      _isIdentityVerified = true;
      _statusMessage = 'Identity verified for $identity. Please set your new password.';
    });
  }

  void _handleSubmitReset() {
    setState(() {
      _errorMessage = null;
    });
    final password = _passwordController.text;
    final score = _evaluatePasswordStrength(password);
    if (score < 2) {
      setState(() {
        _errorMessage = 'Password is too weak. Please use at least 8 characters with letters and numbers.';
      });
      return;
    }
    widget.onResetSuccess(_identityController.text.trim(), password, _revokeAllSessions);
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = _evaluatePasswordStrength(_passwordController.text);
    final String strengthLabel;
    final Color strengthColor;
    switch (strength) {
      case 1:
        strengthLabel = 'Weak';
        strengthColor = AppColors.crimsonRed;
        break;
      case 2:
        strengthLabel = 'Fair';
        strengthColor = AppColors.amberWarning;
        break;
      case 3:
        strengthLabel = 'Strong';
        strengthColor = Colors.blue;
        break;
      case 4:
        strengthLabel = 'Very Strong';
        strengthColor = AppColors.emeraldGreen;
        break;
      default:
        strengthLabel = 'None';
        strengthColor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('recovery_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: widget.onBack,
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
                  child: const Icon(Icons.lock_reset, color: AppColors.primaryGold, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Password Recovery',
                  key: Key('recovery_title'),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Verify identity and update your Wakil credentials',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // Step 1: Identity verification
              TextFormField(
                key: const Key('recovery_identity_input'),
                controller: _identityController,
                decoration: InputDecoration(
                  labelText: 'Account Email or Phone Number',
                  hintText: 'e.g. bhugol.gautam1@gmail.com',
                  prefixIcon: const Icon(Icons.perm_identity, color: AppColors.primaryNavy),
                  filled: true,
                  fillColor: AppColors.surfaceBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSubtle)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              if (!_isIdentityVerified)
                ElevatedButton(
                  key: const Key('recovery_verify_identity_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _verifyIdentity,
                  child: const Text('Verify Identity', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: AppColors.emeraldGreen, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Step 2: New Password & Strength Gauge
              if (_isIdentityVerified) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('recovery_new_password_input'),
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new secure password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryNavy),
                    suffixIcon: IconButton(
                      key: const Key('recovery_password_toggle'),
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

                // US-12: 4-Bar Password Strength Gauge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Password Strength:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      strengthLabel,
                      key: const Key('password_strength_label'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: strengthColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  key: const Key('password_strength_gauge'),
                  children: List.generate(4, (index) {
                    final isFilled = (index + 1) <= strength;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: isFilled ? strengthColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),

                // US-13: Global Session Revocation Toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Global Session Revocation',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Invalidate all tokens on other devices immediately',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('global_session_revocation_switch'),
                        value: _revokeAllSessions,
                        activeThumbColor: AppColors.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _revokeAllSessions = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  key: const Key('recovery_submit_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleSubmitReset,
                  child: const Text('Update Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _errorMessage!,
                    key: const Key('recovery_error_message'),
                    style: const TextStyle(color: AppColors.crimsonRed, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

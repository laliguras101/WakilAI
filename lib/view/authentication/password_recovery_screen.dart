import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-12 & US-13: Password Recovery Screen & 4-Bar Monochrome Strength Gauge
class PasswordRecoveryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String identity, String newPassword, bool revokeAllSessions)
      onResetSuccess;

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
    if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]')) || password.length >= 12) {
      score++;
    }
    return score.clamp(1, 4);
  }

  String _strengthLabelFor(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Strong';
      case 4:
        return 'Very Strong';
      default:
        return 'None';
    }
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
      _statusMessage =
          'Identity verified for $identity. Please set your new password.';
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
        _errorMessage =
            'Password is too weak. Please use at least 8 characters with letters and numbers.';
      });
      return;
    }
    widget.onResetSuccess(
      _identityController.text.trim(),
      password,
      _revokeAllSessions,
    );
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textOnVariant,
        ),
      ),
    );
  }

  InputDecoration _buildPillInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9999),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(
          prefixIcon,
          size: 19,
          color: AppColors.textSecondary,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      border: pillBorder,
      enabledBorder: pillBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: const BorderSide(color: AppColors.primaryBlack, width: 1.5),
      ),
    );
  }

  Widget _buildFrostedHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfacePure.withValues(alpha: 0.80),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlack.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('recovery_back_button'),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlack,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.balance,
                  color: AppColors.surfacePure,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Forgot Password',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlack,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.surfacePure,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _evaluatePasswordStrength(_passwordController.text);
    final strengthLabel = _strengthLabelFor(strength);

    return Scaffold(
      backgroundColor: AppColors.surfacePure,
      body: SafeArea(
        child: Column(
          children: [
            _buildFrostedHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceHigh,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_reset,
                                color: AppColors.primaryBlack,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create new password',
                                    key: Key('recovery_title'),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.6,
                                      height: 30 / 24,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Ensure your legal account remains secure with an updated, high-entropy key.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textSecondary,
                                      height: 18 / 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Step 1: Dual Identity Verification (US-12)
                        _buildFieldLabel('Account Email or Phone Number'),
                        TextFormField(
                          key: const Key('recovery_identity_input'),
                          controller: _identityController,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: _buildPillInputDecoration(
                            hintText: 'name@example.com or 98XXXXXXXX',
                            prefixIcon: Icons.perm_identity,
                          ),
                        ),

                        if (!_isIdentityVerified) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              key: const Key(
                                  'recovery_verify_identity_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlack,
                                foregroundColor: AppColors.surfacePure,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _verifyIdentity,
                              child: const Text(
                                'Verify Identity',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (_statusMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: const Border.fromBorderSide(
                                BorderSide(color: AppColors.surfaceHighest),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: AppColors.primaryBlack,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Step 2: New Password, 4-Bar Monochrome Strength Gauge & Global Revocation
                        if (_isIdentityVerified) ...[
                          const SizedBox(height: 12),
                          _buildFieldLabel('New Password'),
                          TextFormField(
                            key: const Key('recovery_new_password_input'),
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            decoration: _buildPillInputDecoration(
                              hintText: 'Enter new secure password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: IconButton(
                                  key: const Key('recovery_password_toggle'),
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
                          const SizedBox(height: 10),

                          // US-12: 4-Bar Monochrome Strength Gauge
                          Row(
                            key: const Key('password_strength_gauge'),
                            children: List.generate(4, (index) {
                              final isFilled = (index + 1) <= strength;
                              return Expanded(
                                child: Container(
                                  height: 4,
                                  margin:
                                      EdgeInsets.only(right: index < 3 ? 6 : 0),
                                  decoration: BoxDecoration(
                                    color: isFilled
                                        ? AppColors.primaryBlack
                                        : AppColors.surfaceHighest,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                strengthLabel,
                                key: const Key('password_strength_label'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: strength == 0
                                      ? AppColors.textMuted
                                      : AppColors.primaryBlack,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Min. 8 chars, mixed cases & symbols',
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // US-13: Global Session Revocation Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.gpp_good_outlined,
                                  size: 20,
                                  color: AppColors.primaryBlack,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Global Session Revocation',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        'Invalidate all tokens on other devices immediately',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  key: const Key(
                                      'global_session_revocation_switch'),
                                  value: _revokeAllSessions,
                                  thumbColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                            ? AppColors.surfacePure
                                            : AppColors.textMuted,
                                  ),
                                  trackColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                            ? AppColors.primaryBlack
                                            : AppColors.surfaceHighest,
                                  ),
                                  trackOutlineColor: WidgetStateProperty.all(
                                      Colors.transparent),
                                  onChanged: (val) {
                                    setState(() {
                                      _revokeAllSessions = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              key: const Key('recovery_submit_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlack,
                                foregroundColor: AppColors.surfacePure,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _handleSubmitReset,
                              child: const Text(
                                'Update Password',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: AppColors.crimsonError,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    key: const Key('recovery_error_message'),
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
                        ],

                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: widget.onBack,
                            child: const Text(
                              'Cancel and return to Sign in',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
            ),
          ],
        ),
      ),
    );
  }
}

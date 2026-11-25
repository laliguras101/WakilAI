import 'dart:async';
import 'package:ai39a/constants/app_colors.dart';
import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/widgets/otp_input_box.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final int countdownSeconds;

  const OtpVerificationScreen({
    super.key,
    this.phoneNumber = "+977 9841234567",
    this.countdownSeconds = 120,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 120;
  Timer? _countdownTimer;
  bool _isVerifying = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.countdownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _currentOtp.length == 6 && RegExp(r'^\d{6}$').hasMatch(_currentOtp);
  bool get _isLockedOut => _authService.isLockedOut;

  void _handleDigitInput(int index, String value) {
    if (_isLockedOut) return;

    if (value.length > 1) {
      // Full paste handling (e.g. 6-digit code pasted into box 0)
      final clean = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < clean.length; i++) {
        _controllers[i].text = clean[i];
      }
      final nextFocus = (clean.length < 6) ? clean.length : 5;
      _focusNodes[nextFocus].requestFocus();
      setState(() {});
      if (_isComplete) {
        _submitVerification();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    setState(() {});

    if (_isComplete) {
      _submitVerification();
    }
  }

  void _handleBackspace(int index) {
    if (index > 0 && _controllers[index].text.isEmpty) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  void _clearCode() {
    for (var c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _errorMessage = null;
    });
  }

  void _resendOtp() {
    _authService.resetLockout();
    _clearCode();
    setState(() {
      _secondsLeft = widget.countdownSeconds;
      _errorMessage = null;
    });
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("A fresh 6-digit OTP has been sent to ${widget.phoneNumber}"),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _submitVerification() async {
    if (!_isComplete || _isVerifying || _isLockedOut) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyOtp(widget.phoneNumber, _currentOtp);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Phone verification successful! Welcome to Wakil."),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isLockedOut;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('otp_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Security Verification",
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Brand Emblem
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.balance, color: AppColors.emblemGold, size: 32),
                ),
              ),

              const SizedBox(height: 24),

              // Elevated OTP Verification Card (US-09)
              Card(
                key: const Key('otp_verification_card'),
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Lock Emblem Badge
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: locked ? AppColors.errorContainer : AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            locked ? Icons.lock : Icons.phone_android,
                            color: locked ? AppColors.error : AppColors.primary,
                            size: 28,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        locked ? "Account Locked Out" : "SMS Verification",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: locked ? AppColors.error : AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        locked
                            ? "Security lockout active. Anti-brute force triggered."
                            : "Enter the 6-digit code sent to",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),

                      const SizedBox(height: 8),

                      // Destination Phone Badge
                      Container(
                        key: const Key('otp_phone_destination'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Extreme Security: 3-Attempt Lockout Warning Banner
                      if (locked) ...[
                        Container(
                          key: const Key('otp_lockout_warning'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock, color: AppColors.error, size: 24),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Anti-Brute Force Protection Active",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "Maximum limit of 3 failed attempts reached. System locked for 15 minutes to protect your credentials. Tap 'Resend via SMS' to request a new code.",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF7F1D1D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 6 PIN Input Boxes (US-09)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return OtpInputBox(
                            index: index,
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            hasError: _errorMessage != null || locked,
                            isLockedOut: locked,
                            onChanged: (val) => _handleDigitInput(index, val),
                            onBackspace: () => _handleBackspace(index),
                          );
                        }),
                      ),

                      // Error message display
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          key: const Key('otp_error_message'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Action Row: Clear Code & Resend Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            key: const Key('clear_otp_button'),
                            onPressed: _clearCode,
                            icon: const Icon(Icons.clear, size: 14, color: AppColors.textSecondary),
                            label: const Text(
                              "Clear Code",
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          if (_secondsLeft > 0 && !locked) ...[
                            Text(
                              "Resend in ${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}",
                              key: const Key('otp_countdown_timer'),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ] else ...[
                            TextButton.icon(
                              key: const Key('resend_otp_button'),
                              onPressed: _resendOtp,
                              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                              label: const Text(
                                "Resend via SMS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Verify & Proceed Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('verify_otp_button'),
                          onPressed: (_isComplete && !_isVerifying && !locked)
                              ? _submitVerification
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Verify & Proceed",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Footer Security Badge
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    "Protected by Nepal Law Commission & NTA SMS Security",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

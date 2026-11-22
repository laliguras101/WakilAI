import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-09, US-10, US-11: OTP Security Verification Screen
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onBack;
  final VoidCallback onOtpVerified;
  final int initialTimerSeconds;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.onBack,
    required this.onOtpVerified,
    this.initialTimerSeconds = 120,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late int _timerSeconds;
  Timer? _countdownTimer;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _timerSeconds = widget.initialTimerSeconds;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // US-11: Clear all 6 boxes and refocus Box 1
  void _clearCodeAction() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _errorMessage = null;
    });
    _focusNodes[0].requestFocus();
  }

  // US-10: Resend SMS code when timer expires
  void _resendCodeAction() {
    if (_timerSeconds == 0) {
      setState(() {
        _timerSeconds = 120;
        _clearCodeAction();
        _statusMessage = 'A new 6-digit security OTP was sent to ${widget.phoneNumber}.';
      });
      _startTimer();
    }
  }

  void _verifyOtp() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      widget.onOtpVerified();
    } else {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP code.';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final bool isAllFilled = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('otp_back_button'),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryNavy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                '6-Digit SMS Verification',
                key: Key('otp_title'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the verification code sent to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),

              // US-09: Elevated Card with 6 individual PIN boxes
              Card(
                key: const Key('otp_card'),
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: AppColors.surfaceBackground,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 44,
                        height: 52,
                        child: TextFormField(
                          key: Key('otp_box_$index'),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            setState(() {});
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // US-11: Clear Code Action Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('otp_clear_button'),
                  onPressed: _clearCodeAction,
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                  label: const Text('Clear Code', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),

              // US-10: Live 2-Minute Countdown Timer & Resend Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _formatTimer(_timerSeconds),
                          key: const Key('otp_timer_text'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _timerSeconds > 0 ? AppColors.primaryNavy : AppColors.crimsonRed,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      key: const Key('otp_resend_button'),
                      onPressed: _timerSeconds == 0 ? _resendCodeAction : null,
                      child: Text(
                        'Resend via SMS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _timerSeconds == 0 ? AppColors.primaryNavy : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: AppColors.emeraldGreen, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.crimsonRed, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('otp_verify_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isAllFilled ? _verifyOtp : null,
                  child: const Text('Verify & Proceed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

/// US-09, US-10, US-11: OTP Security Verification Screen (Swiss / Gemini Light Monochrome)
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
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
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
    if (_timerSeconds <= 0) {
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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

  void _resetOtpBoxes() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _errorMessage = null;
  }

  // US-11: Clear all 6 boxes and refocus Box 1
  void _clearCodeAction() {
    setState(_resetOtpBoxes);
    _focusNodes[0].requestFocus();
  }

  // US-10: Resend SMS code when timer expires
  void _resendCodeAction() {
    if (_timerSeconds == 0) {
      setState(() {
        _timerSeconds = 120;
        _resetOtpBoxes();
        _statusMessage =
            'A new 6-digit security OTP was sent to ${widget.phoneNumber}.';
      });
      _focusNodes[0].requestFocus();
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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _buildOtpBox(int index) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: index < 5 ? 6 : 0),
        child: ListenableBuilder(
          listenable: _focusNodes[index],
          builder: (context, _) {
            final isFocused = _focusNodes[index].hasFocus;
            final pillBorder = OutlineInputBorder(
              borderRadius: BorderRadius.circular(9999),
              borderSide: BorderSide.none,
            );
            return SizedBox(
              height: 48,
              child: TextFormField(
                key: Key('otp_box_$index'),
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlack,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '·',
                  hintStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor:
                      isFocused ? AppColors.surfaceHigh : AppColors.surfaceLow,
                  contentPadding: EdgeInsets.zero,
                  border: pillBorder,
                  enabledBorder: pillBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9999),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlack,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _focusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllFilled = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Clean minimal header with circular back button & WAKIL badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      key: const Key('otp_back_button'),
                      onPressed: widget.onBack,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfacePure,
                        foregroundColor: AppColors.textPrimary,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
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

            // Centered elevated OTP card
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryBlack.withValues(alpha: 0.10),
                            blurRadius: 25,
                            spreadRadius: -5,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color:
                                AppColors.primaryBlack.withValues(alpha: 0.10),
                            blurRadius: 10,
                            spreadRadius: -6,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Card(
                        key: const Key('otp_card'),
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: AppColors.surfacePure,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                            color: AppColors.surfaceHighest,
                            width: 0.75,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top icon + quick edit-phone button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.surfaceLow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: AppColors.primaryBlack,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      onPressed: widget.onBack,
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Edit phone number',
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.surfaceLow,
                                        foregroundColor:
                                            AppColors.textSecondary,
                                        shape: const CircleBorder(),
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              const Text(
                                'Enter 6-digit code',
                                key: Key('otp_title'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.45,
                                  color: AppColors.primaryBlack,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text.rich(
                                TextSpan(
                                  text: 'Sent via SMS to ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 18 / 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: widget.phoneNumber,
                                      style: const TextStyle(
                                        color: AppColors.primaryBlack,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // US-09: 6 pill OTP boxes
                              Row(
                                children: List.generate(6, _buildOtpBox),
                              ),
                              const SizedBox(height: 8),

                              // US-11: Clear Code action
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  key: const Key('otp_clear_button'),
                                  onPressed: _clearCodeAction,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.close, size: 15),
                                  label: const Text(
                                    'Clear Code',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // US-10: Live countdown timer & Resend via SMS
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Resend code in ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          _formatTimer(_timerSeconds),
                                          key: const Key('otp_timer_text'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: _timerSeconds > 0
                                                ? AppColors.primaryBlack
                                                : AppColors.crimsonError,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Opacity(
                                      opacity: _timerSeconds == 0 ? 1.0 : 0.5,
                                      child: TextButton(
                                        key: const Key('otp_resend_button'),
                                        onPressed: _timerSeconds == 0
                                            ? _resendCodeAction
                                            : null,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Resend via SMS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _timerSeconds == 0
                                                ? AppColors.primaryBlack
                                                : AppColors.textMuted,
                                            decoration: _timerSeconds == 0
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_statusMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
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

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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

                              const SizedBox(height: 20),

                              // Verify & Proceed pill CTA
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  key: const Key('otp_verify_button'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlack,
                                    foregroundColor: AppColors.surfacePure,
                                    disabledBackgroundColor:
                                        AppColors.surfaceHighest,
                                    disabledForegroundColor:
                                        AppColors.textMuted,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: isAllFilled ? _verifyOtp : null,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Verify & Proceed',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Direct encrypted authentication',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

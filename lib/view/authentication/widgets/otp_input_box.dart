import 'package:ai39a/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInputBox extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final bool isLockedOut;
  final VoidCallback? onBackspace;

  const OtpInputBox({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
    this.isLockedOut = false,
    this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace?.call();
          }
        },
        child: TextFormField(
          key: Key('otp_input_box_$index'),
          controller: controller,
          focusNode: focusNode,
          enabled: !isLockedOut,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isLockedOut ? Colors.grey : AppColors.textPrimary,
          ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(6), // Allows paste distribution
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: isLockedOut
                ? Colors.grey.shade200
                : (focusNode.hasFocus ? Colors.blue.shade50 : Colors.grey.shade100),
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.cardBorder,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

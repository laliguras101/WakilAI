import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// US-02 & US-03: Mandatory Legal Disclaimer Bottom Sheet with Consent Validation
class LegalDisclaimerSheet extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onSkip;

  const LegalDisclaimerSheet({
    super.key,
    required this.onAccepted,
    required this.onSkip,
  });

  @override
  State<LegalDisclaimerSheet> createState() => _LegalDisclaimerSheetState();
}

class _LegalDisclaimerSheetState extends State<LegalDisclaimerSheet> {
  bool _isScopeExpanded = false;
  bool _hasAgreed = false;
  String? _errorMessage;

  void _validateAndProceed() {
    if (!_hasAgreed) {
      setState(() {
        _errorMessage = 'You must agree to the Terms & Legal Disclaimer to continue.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
    });
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.gavel, color: AppColors.primaryNavy, size: 28),
              SizedBox(width: 10),
              Text(
                'AI Legal Information Notice',
                key: Key('disclaimer_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Wakil uses advanced AI to help navigate Nepali legal statutes, court procedures, and legal documents. It is provided strictly for informational purposes and does not constitute formal legal counsel.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          // Collapsible Terms Accordion
          InkWell(
            key: const Key('scope_accordion_toggle'),
            onTap: () {
              setState(() {
                _isScopeExpanded = !_isScopeExpanded;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scope & Limitations of Advice',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Icon(
                    _isScopeExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryNavy,
                  ),
                ],
              ),
            ),
          ),
          if (_isScopeExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '• Grounded exclusively in Constitution of Nepal & Muluki Codes.\n• Real-time advocate consultation required for official court proceedings.\n• All communications are encrypted.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          const SizedBox(height: 16),
          // US-03: Mandatory Agreement Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const Key('consent_checkbox'),
                value: _hasAgreed,
                activeColor: AppColors.primaryNavy,
                onChanged: (val) {
                  setState(() {
                    _hasAgreed = val ?? false;
                    if (_hasAgreed) _errorMessage = null;
                  });
                },
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Text(
                    'I acknowledge that Wakil provides legal information only, and I agree to the Terms of Service.',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.crimsonRed, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('accept_continue_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _validateAndProceed,
            child: const Text('Accept & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('skip_auth_button'),
            onPressed: widget.onSkip,
            child: const Text('Skip Auth (Test Mode)', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
      ),
    );
  }
}

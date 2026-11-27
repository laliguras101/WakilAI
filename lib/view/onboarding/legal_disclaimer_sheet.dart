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
        _errorMessage =
            'You must agree to the Terms & Legal Disclaimer to continue.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
    });
    widget.onAccepted();
  }

  void _toggleAgreement(bool? value) {
    setState(() {
      _hasAgreed = value ?? false;
      if (_hasAgreed) {
        _errorMessage = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfacePure,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.10),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.primaryBlack.withValues(alpha: 0.10),
            blurRadius: 10,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AI Legal Information • कानुनी सूचना',
                key: Key('disclaimer_title'),
                style: TextStyle(
                  fontSize: 19,
                  height: 24 / 19,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Wakil uses advanced AI to help navigate Nepali legal statutes, court procedures, and legal documents. It is provided strictly for informational purposes and does not constitute formal legal counsel. (वकिलले नेपाली ऐन, नियम र कार्यविधि बुझ्न सहयोग गर्दछ।)',
                style: TextStyle(
                  fontSize: 13,
                  height: 19 / 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              // Collapsible Terms Accordion
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      key: const Key('scope_accordion_toggle'),
                      onTap: () {
                        setState(() {
                          _isScopeExpanded = !_isScopeExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Coverage & Statutory Scope',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  height: 18 / 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              _isScopeExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isScopeExpanded)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                              color: AppColors.surfaceHighest,
                              height: 1,
                              thickness: 1,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Grounded exclusively in Constitution of Nepal & Muluki Codes (मुलुकी संहिता).\n• Under the Legal Practitioners Act 2050 (नेपाल कानुन व्यवसायी परिषद ऐन, २०५०), this AI provides statutory legal reference, not certified courtroom advocacy.\n• Real-time advocate consultation required for official court proceedings.\n• All communications are encrypted.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // US-03: Mandatory Agreement Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: const Key('consent_checkbox'),
                    value: _hasAgreed,
                    activeColor: AppColors.primaryBlack,
                    checkColor: AppColors.surfacePure,
                    side: const BorderSide(
                      color: AppColors.textMuted,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: _toggleAgreement,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleAgreement(!_hasAgreed),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Text(
                          'I understand Wakil provides legal information, not formal legal counsel. (म स्वीकार गर्दछु कि वकिलले कानुनी जानकारी मात्र प्रदान गर्दछ।)',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 4),
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
                            color: AppColors.crimsonError,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('accept_continue_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlack,
                    foregroundColor: AppColors.surfacePure,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _validateAndProceed,
                  child: const Text(
                    'Accept & Continue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('skip_auth_button'),
                onPressed: widget.onSkip,
                child: const Text(
                  'Skip Auth (Test Mode)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

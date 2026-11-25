import 'package:ai39a/constants/app_colors.dart';
import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/login_screen.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _termsChecked = false;
  bool _scopeExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Legal Disclaimer",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Emblem
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.balance, color: AppColors.emblemGold, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "AI Legal Information",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Wakil uses legal AI to help navigate Nepali statutes, Muluki Codes, and court procedures for informational purposes.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Interactive Accordion
              InkWell(
                key: const Key('scope_accordion_toggle'),
                onTap: () {
                  setState(() {
                    _scopeExpanded = !_scopeExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Coverage & Statutory Scope",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Icon(
                            _scopeExpanded ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      if (_scopeExpanded) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Covers Muluki Civil Code 2074, Muluki Criminal Code 2074, Company Act 2063, Labor Act 2074, and the Constitution of Nepal 2072. Always consult a licensed advocate for official courtroom representation.",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Checkbox
              InkWell(
                key: const Key('disclaimer_checkbox'),
                onTap: () {
                  setState(() {
                    _termsChecked = !_termsChecked;
                  });
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _termsChecked,
                      onChanged: (val) {
                        setState(() {
                          _termsChecked = val ?? false;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const Expanded(
                      child: Text(
                        "I understand Wakil provides AI legal information, not formal courtroom counsel.",
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('disclaimer_continue_button'),
                  onPressed: _termsChecked
                      ? () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue to Sign In",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Skip Auth (Test Mode) Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  key: const Key('skip_auth_splash_button'),
                  onPressed: () {
                    AuthService().setTestMode(true);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Skip Auth (Test Mode)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                    ],
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

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'legal_disclaimer_sheet.dart';

/// US-01: Onboarding Splash Screen & Emblem Branding
class SplashScreen extends StatelessWidget {
  final VoidCallback onContinueToAuth;
  final VoidCallback onSkipAuth;

  const SplashScreen({
    super.key,
    required this.onContinueToAuth,
    required this.onSkipAuth,
  });

  void _showDisclaimer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LegalDisclaimerSheet(
        onAccepted: () {
          Navigator.pop(ctx);
          onContinueToAuth();
        },
        onSkip: () {
          Navigator.pop(ctx);
          onSkipAuth();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePure,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Spacer(),
                            // Centered Brand Stage
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    key: const Key('splash_emblem'),
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLow,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryBlack.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryBlack,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.balance,
                                            size: 32,
                                            color: AppColors.surfacePure,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Wakil',
                                    key: Key('app_title'),
                                    style: TextStyle(
                                      fontSize: 32,
                                      height: 38 / 32,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Legal Intelligence for Nepal',
                                    key: Key('app_tagline'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 21 / 14,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryBlack,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Flexible(
                                          child: Text(
                                            'CONSTITUTION • MULUKI CODES',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 14 / 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.55,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Bottom Pinned Actions
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      key: const Key('get_started_button'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlack,
                                        foregroundColor: AppColors.surfacePure,
                                        elevation: 0,
                                        shape: const StadiumBorder(),
                                      ),
                                      onPressed: () => _showDisclaimer(context),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    key: const Key('skip_to_test_mode'),
                                    onPressed: onSkipAuth,
                                    child: const Text(
                                      'Explore in Test Mode',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:ai39a/constants/app_colors.dart';
import 'package:ai39a/services/auth_service.dart';
import 'package:ai39a/view/authentication/disclaimer_screen.dart';
import 'package:ai39a/view/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final int autoAdvanceDelayMs;

  const SplashScreen({
    super.key,
    this.autoAdvanceDelayMs = 1500,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(Duration(milliseconds: widget.autoAdvanceDelayMs), () {
      if (!mounted) return;
      final auth = AuthService();
      if (auth.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DisclaimerScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash_screen'),
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Scales of Justice Emblem
              Container(
                key: const Key('wakil_emblem'),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.emblemGold.withOpacity(0.6),
                    width: 2.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.balance,
                    key: Key('emblem_icon'),
                    size: 46,
                    color: AppColors.emblemGold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Text(
                "Wakil",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                "Legal Intelligence for Nepal",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

              const SizedBox(height: 20),

              // Version Status Pill (US-01 Acceptance Criteria)
              Container(
                key: const Key('version_status_pill'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Text(
                  "CONSTITUTION • MULUKI CODES",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),

              const Spacer(),

              // Footer Legal Tag
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  "AI Statute & Muluki Code Intelligence",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
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

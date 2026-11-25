import 'package:flutter/material.dart';

/// Swiss / Gemini Light Monochrome color palette for Wakil Legal Intelligence.
class AppColors {
  AppColors._();

  // Surface Hierarchy (pure white to subtle neutral elevations)
  static const Color surfacePure = Color(0xFFFFFFFF);
  static const Color surfaceCanvas = Color(0xFFF9F9FA);
  static const Color surfaceLow = Color(0xFFF3F3F4);
  static const Color surfaceContainer = Color(0xFFEEEEEF);
  static const Color surfaceHigh = Color(0xFFE8E8E9);
  static const Color surfaceHighest = Color(0xFFE2E2E3);

  // Primary Brand Ink
  static const Color primaryBlack = Color(0xFF000000);

  // Typography & Ink Hierarchy
  static const Color textPrimary = Color(0xFF1A1C1D);
  static const Color textOnVariant = Color(0xFF47464B);
  static const Color textSecondary = Color(0xFF5D5E66);
  static const Color textMuted = Color(0xFF77767B);

  // Outlines & Dividers
  static const Color outlineVariant = Color(0xFFC8C5CB);

  // Semantic Error Tokens
  static const Color crimsonError = Color(0xFFBA1A1A);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Google 4-Color Brand Mark Tokens
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  // Semantic Aliases
  static const Color surfaceCard = surfacePure;
  static const Color surfaceBackground = surfaceCanvas;
  static const Color borderSubtle = surfaceHighest;
  static const Color crimsonRed = crimsonError;
}

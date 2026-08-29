import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color deepBlue = Color(0xFF1D4ED8);
  static const Color softBlue = Color(0xFFDBEAFE);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Backgrounds
  static const Color background = Color(0xFFF6F9FC);
  static const Color surfaceBlue = Color(0xFFF0F7FF);
  static const Color white = Color(0xFFFFFFFF);

  // Text hierarchy
  static const Color navy = Color(0xFF0F172A);
  static const Color slate = Color(0xFF334155);
  static const Color text = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color muted = Color(0xFF94A3B8);

  // Glass
  static const Color glass = Color(0xBFFFFFFF); // white at ~75% opacity
  static const Color glassBorder = Color(0x33FFFFFF); // white at ~20%

  // Borders & surfaces
  static const Color border = Color(0xFFE2E8F0);
  static const Color cardSurface = Color(0xFFFAFBFD);

  // Aliases
  static const Color textDark = navy;
  static const Color textSecondary = secondaryText;

  // Gradients
  static const LinearGradient blueToCyan = LinearGradient(
    colors: [primaryBlue, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueToIndigo = LinearGradient(
    colors: [primaryBlue, deepBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleBlueFade = LinearGradient(
    colors: [Color(0xFFEFF6FF), Color(0xFFF0F7FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueGradient = blueToIndigo;
  static const LinearGradient cyanGradient = blueToCyan;
}

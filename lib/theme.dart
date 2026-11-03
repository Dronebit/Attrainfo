import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0C1016);
  static const panel = Color(0xFF141C29);
  static const panel2 = Color(0xFF1A2434);
  static const line = Color(0xFF233046);
  static const line2 = Color(0xFF2E3D58);
  static const txt = Color(0xFFE8EEF7);
  static const mut = Color(0xFF93A1B8);
  static const dim = Color(0xFF64748B);
  static const amb = Color(0xFFFFB224);
  static const amb2 = Color(0xFFFFD37A);
  static const red = Color(0xFFFF5D55);
  static const org = Color(0xFFFF9F43);
  static const pur = Color(0xFFA78BFA);
  static const cyn = Color(0xFF38BDF8);
  static const grn = Color(0xFF34D399);
  static const blu = Color(0xFF60A5FA);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.amb,
        secondary: AppColors.blu,
        surface: AppColors.panel,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.txt,
        displayColor: AppColors.txt,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E1420),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.amb),
        ),
      ),
    );
  }
}
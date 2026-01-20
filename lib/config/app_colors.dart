import 'package:flutter/material.dart';

class AppColors {
  // iOS 18 Dark Mode - Pure Black Aesthetic
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color darkSurfaceElevated = Color(0xFF1C1C1E);

  // Glassmorphism
  static const Color glassWhite = Color(0x0DFFFFFF); // 5% white
  static const Color glassBorder = Color(0x1AFFFFFF); // 10% white

  // Accent - Lime Green (used sparingly for active states)
  static const Color accent = Color(0xFFA4CD01);
  static const Color accentDim = Color(0xFF7A9A01);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  // Status Colors (muted for premium feel)
  static const Color connected = Color(0xFFA4CD01); // Lime green
  static const Color connecting = Color(0xFFFFD60A); // iOS yellow
  static const Color disconnected = Color(0xFF48484A); // Muted gray
  static const Color reconnecting = Color(0xFF0A84FF); // iOS blue
  static const Color error = Color(0xFFFF453A); // iOS red

  // Legacy Light Mode (Refined for Modern Look)
  static const Color lightPrimary = Color(
    0xFF1C1C1E,
  ); // Nearly black for primary headers
  static const Color lightSecondary = Color(0xFFA4CD01); // Lime Green Accent
  static const Color lightAccent = Color(0xFF7A9A01);
  static const Color lightBackground = Color(
    0xFFF2F2F7,
  ); // iOS Light Gray Background
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(
    0xFF000000,
  ); // Pure Black for max contrast
  static const Color lightTextSecondary = Color(0xFF3C3C43); // iOS Gray Label

  // Dark colors (Beautiful OLED + Glass)
  static const Color darkPrimary = Color(0xFF000000);
  static const Color darkSecondary = Color(0xFFA4CD01);
  static const Color darkAccent = Color(0xFF7A9A01);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5); // iOS Glass Label

  // Button Gradients - iOS 18 Style
  static const LinearGradient connectButtonGradient = LinearGradient(
    colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient disconnectButtonGradient = LinearGradient(
    colors: [Color(0xFFA4CD01), Color(0xFF7A9A01)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient connectingButtonGradient = LinearGradient(
    colors: [Color(0xFF3A3A3C), Color(0xFF2C2C2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

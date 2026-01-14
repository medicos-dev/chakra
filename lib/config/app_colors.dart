import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const Color lightPrimary = Color(0xFF1A365D); // Deep Navy
  static const Color lightSecondary = Color(0xFF00BCD4); // Cyan
  static const Color lightAccent = Color(0xFFFF7043); // Subtle Orange
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF2D3748);
  static const Color lightTextSecondary = Color(0xFF718096);

  // Dark Mode Colors
  static const Color darkPrimary = Color(0xFF0F172A); // Charcoal
  static const Color darkSecondary = Color(0xFF14B8A6); // Teal
  static const Color darkAccent = Color(0xFFF59E0B); // Soft Amber
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Status Colors
  static const Color connected = Color(0xFF10B981); // Green
  static const Color connecting = Color(0xFFF59E0B); // Amber
  static const Color disconnected = Color(0xFFEF4444); // Red
  static const Color reconnecting = Color(0xFF6366F1); // Indigo

  // Gradients
  static const LinearGradient connectButtonGradient = LinearGradient(
    colors: [Color(0xFF00BCD4), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient disconnectButtonGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient connectingButtonGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

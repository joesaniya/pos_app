import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryPurple = Color(0xFF6B4CE6);
  static const Color primaryPurpleLight = Color(0xFF8B6FED);
  static const Color primaryPurpleDark = Color(0xFF5436C9);
  
  static const Color primaryRed = Color(0xFFFF6B6B);
  static const Color primaryRedLight = Color(0xFFFF8A8A);
  static const Color primaryRedDark = Color(0xFFE55555);
  
  // Secondary Colors
  static const Color secondaryBlue = Color(0xFF4F46E5);
  static const Color secondaryGreen = Color(0xFF4CAF50);
  static const Color secondaryOrange = Color(0xFFFF9800);
  static const Color secondaryYellow = Color(0xFFFFB300);
  
  // Neutral Colors
  static const Color lightNeutral100 = Color(0xFFF8F9FA);
  static const Color lightNeutral200 = Color(0xFFF5F5F5);
  static const Color lightNeutral300 = Color(0xFFE0E0E0);
  static const Color lightNeutral400 = Color(0xFFBDBDBD);
  static const Color lightNeutral500 = Color(0xFF9E9E9E);
  static const Color lightNeutral600 = Color(0xFF757575);
  static const Color lightNeutral700 = Color(0xFF616161);
  static const Color lightNeutral800 = Color(0xFF424242);
  static const Color lightNeutral900 = Color(0xFF212121);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF2D2D2D);
  static const Color darkCard = Color(0xFF363636);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF8B8B8B);
  static const Color textTertiary = Color(0xFFB0B0B0);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textBlack = Color(0xFF000000);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFE4CC);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6B4CE6), Color(0xFF8B6FED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFFF8A65), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color borderDark = Color(0xFF757575);
  
  // Shadow Colors
  static Color shadowLight = Colors.black.withOpacity(0.05);
  static Color shadowMedium = Colors.black.withOpacity(0.1);
  static Color shadowDark = Colors.black.withOpacity(0.2);
  
  // Overlay Colors
  static Color overlayLight = Colors.black.withOpacity(0.3);
  static Color overlayMedium = Colors.black.withOpacity(0.5);
  static Color overlayDark = Colors.black.withOpacity(0.7);
  
  // Transparent
  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}
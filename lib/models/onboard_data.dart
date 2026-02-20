
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Data Model
// ─────────────────────────────────────────────
class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData iconData;
  final Color accentColor;
  final List<Color> gradientColors;

  const OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconData,
    required this.accentColor,
    required this.gradientColors,
  });
}

/*import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  Data Model
// ─────────────────────────────────────────────
class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final String iconCodePoint;   // store codePoint so provider stays UI-free
  final Color accentColor;
  final List<Color> gradientColors;

  const OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconCodePoint,
    required this.accentColor,
    required this.gradientColors,
  });
}
*/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/onboard_data.dart';

class OnboardingProvider with ChangeNotifier {
  final List<OnboardingData> pages = const [
    OnboardingData(
      title: 'Smart',
      subtitle: 'Point of Sale',
      description:
          'Streamline every transaction with lightning-fast checkout, real-time inventory sync, and intelligent sales tracking — all in one place.',
      iconData: Icons.point_of_sale_rounded,
      accentColor: Color(0xFF7C3AED),
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    ),
    OnboardingData(
      title: 'Real-time',
      subtitle: 'Analytics',
      description:
          'Watch your business grow with live dashboards, trend forecasting, and actionable insights that help you make smarter decisions daily.',
      iconData: Icons.insights_rounded,
      accentColor: Color(0xFF0EA5E9),
      gradientColors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    ),
    OnboardingData(
      title: 'Seamless',
      subtitle: 'Team Management',
      description:
          'Assign roles, track performance, and collaborate effortlessly. Empower your team with the right tools to deliver exceptional service.',
      iconData: Icons.groups_2_rounded,
      accentColor: Color(0xFF10B981),
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
  ];

  // ── State ─────────────────────────────────
  int _currentPage = 0;
  bool _isNavigatingAway = false;

  int get currentPage => _currentPage;
  bool get isNavigatingAway => _isNavigatingAway;
  bool get isFirstPage => _currentPage == 0;
  bool get isLastPage => _currentPage == pages.length - 1;
  int get totalPages => pages.length;

  OnboardingData get currentPageData => pages[_currentPage];

  // ── Page Control ──────────────────────────
  void onPageChanged(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Returns true if page actually changed (so screen can drive PageController)
  bool goToNextPage() {
    if (isLastPage) return false;
    _currentPage++;
    HapticFeedback.lightImpact();
    notifyListeners();
    return true;
  }

  bool goToPreviousPage() {
    if (isFirstPage) return false;
    _currentPage--;
    HapticFeedback.lightImpact();
    notifyListeners();
    return true;
  }

  void requestNavigateAway() {
    HapticFeedback.mediumImpact();
    _isNavigatingAway = true;
    notifyListeners();
  }

  /// Called by screen after navigation is done (good practice to reset).
  void resetNavigationIntent() {
    _isNavigatingAway = false;
    // no notifyListeners needed — screen is gone
  }
}




/*───────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/onboard_data.dart';

class OnboardingProvider with ChangeNotifier {
  // ── Pages ─────────────────────────────────
  final List<OnboardingData> pages = const [
    OnboardingData(
      title: 'Smart',
      subtitle: 'Point of Sale',
      description:
          'Streamline every transaction with lightning-fast checkout, real-time inventory sync, and intelligent sales tracking — all in one place.',
      iconCodePoint: '0xe576', // Icons.point_of_sale_rounded
      accentColor: Color(0xFF7C3AED),
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    ),
    OnboardingData(
      title: 'Real-time',
      subtitle: 'Analytics',
      description:
          'Watch your business grow with live dashboards, trend forecasting, and actionable insights that help you make smarter decisions daily.',
      iconCodePoint: '0xe65e', // Icons.insights_rounded
      accentColor: Color(0xFF0EA5E9),
      gradientColors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    ),
    OnboardingData(
      title: 'Seamless',
      subtitle: 'Team Management',
      description:
          'Assign roles, track performance, and collaborate effortlessly. Empower your team with the right tools to deliver exceptional service.',
      iconCodePoint: '0xf07c7', // Icons.groups_2_rounded
      accentColor: Color(0xFF10B981),
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    ),
  ];

  // ── State ─────────────────────────────────
  int _currentPage = 0;
  bool _isNavigatingAway = false;

  int  get currentPage        => _currentPage;
  bool get isNavigatingAway   => _isNavigatingAway;
  bool get isFirstPage        => _currentPage == 0;
  bool get isLastPage         => _currentPage == pages.length - 1;
  int  get totalPages         => pages.length;

  OnboardingData get currentPageData => pages[_currentPage];

  // ── Page Control ──────────────────────────
  void onPageChanged(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Returns true if page actually changed (so screen can drive PageController)
  bool goToNextPage() {
    if (isLastPage) return false;
    _currentPage++;
    HapticFeedback.lightImpact();
    notifyListeners();
    return true;
  }

  bool goToPreviousPage() {
    if (isFirstPage) return false;
    _currentPage--;
    HapticFeedback.lightImpact();
    notifyListeners();
    return true;
  }

  // ── Navigation Intent ─────────────────────
  /// Called by screen when user taps Next on last page or Skip.
  /// Provider marks intent; screen handles the actual Navigator call.
  void requestNavigateAway() {
    HapticFeedback.mediumImpact();
    _isNavigatingAway = true;
    notifyListeners();
  }

  /// Called by screen after navigation is done (good practice to reset).
  void resetNavigationIntent() {
    _isNavigatingAway = false;
    // no notifyListeners needed — screen is gone
  }
}*/
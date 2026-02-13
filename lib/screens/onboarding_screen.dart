import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/models/onboard_data.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── PageController (view concern — stays in the screen) ──────
  late final PageController _pageController;

  // ── Animation controllers ────────────────────────────────────
  late List<AnimationController> _pageAnimControllers;
  late List<Animation<double>> _iconScaleAnims;
  late List<Animation<double>> _iconFadeAnims;
  late List<Animation<Offset>> _titleSlideAnims;
  late List<Animation<double>> _titleFadeAnims;
  late List<Animation<Offset>> _descSlideAnims;
  late List<Animation<double>> _descFadeAnims;

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  late AnimationController _btnController;
  late Animation<double> _btnScaleAnim;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _pageController = PageController(initialPage: provider.currentPage);
    _setupAnimations(provider.totalPages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playPageAnimation(provider.currentPage);
    });
  }

  void _setupAnimations(int pageCount) {
    _pageAnimControllers = List.generate(
      pageCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      ),
    );

    _iconScaleAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
            ),
          ),
        )
        .toList();

    _iconFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    _titleSlideAnims = _pageAnimControllers
        .map(
          (c) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: c,
                  curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
                ),
              ),
        )
        .toList();

    _titleFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    _descSlideAnims = _pageAnimControllers
        .map(
          (c) => Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: c,
                  curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
                ),
              ),
        )
        .toList();

    _descFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    // Floating orbs pulse — runs continuously
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _orbAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));

    // Button press-scale
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
  }

  void _playPageAnimation(int page) {
    _pageAnimControllers[page]
      ..reset()
      ..forward();
  }

  // ── Callbacks — delegate all logic to provider ───────────────

  void _onPageChanged(int index) {
    context.read<OnboardingProvider>().onPageChanged(index);
    _playPageAnimation(index);
  }

  void _onNextTap() {
    final provider = context.read<OnboardingProvider>();
    if (provider.isLastPage) {
      provider.requestNavigateAway();
      _navigateToLogin();
    } else {
      if (provider.goToNextPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _onBackTap() {
    if (context.read<OnboardingProvider>().goToPreviousPage()) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onSkipTap() {
    context.read<OnboardingProvider>().requestNavigateAway();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: LoginScreen()),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _pageAnimControllers) {
      c.dispose();
    }
    _orbController.dispose();
    _btnController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD — pure rendering, no logic
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Consumer<OnboardingProvider>(
        builder: (context, provider, _) {
          final page = provider.currentPageData;
          return Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    page.accentColor.withOpacity(0.15),
                    AppColors.lightNeutral100,
                    AppColors.lightNeutral100,
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    _buildBackgroundOrbs(page),
                    Column(
                      children: [
                        _buildTopBar(provider),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: provider.totalPages,
                            itemBuilder: (_, index) =>
                                _buildPage(index, provider.pages[index]),
                          ),
                        ),
                        _buildBottomSection(provider),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE WIDGET BUILDERS
  // ════════════════════════════════════════════════════════════

  Widget _buildBackgroundOrbs(OnboardingData page) {
    return AnimatedBuilder(
      animation: _orbAnimation,
      builder: (_, __) {
        final t = _orbAnimation.value;
        return Stack(
          children: [
            Positioned(
              top: -60 + (t * 20),
              right: -80 + (t * 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 280.w,
                height: 280.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.18),
                      page.accentColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100 - (t * 15),
              left: -50 + (t * 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.12),
                      page.accentColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: page.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppColors.white,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'POS App',
                style: AppTheme.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          AnimatedOpacity(
            opacity: provider.isLastPage ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: provider.isLastPage ? null : _onSkipTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.lightNeutral200,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Skip',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, OnboardingData page) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 16.h),
          FadeTransition(
            opacity: _iconFadeAnims[index],
            child: ScaleTransition(
              scale: _iconScaleAnims[index],
              child: _buildIllustration(page),
            ),
          ),
          SizedBox(height: 48.h),
          FadeTransition(
            opacity: _titleFadeAnims[index],
            child: SlideTransition(
              position: _titleSlideAnims[index],
              child: Column(
                children: [
                  Text(
                    page.title,
                    style: AppTheme.displaySmall.copyWith(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.0,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: page.gradientColors,
                        ).createShader(Rect.fromLTWH(0, 0, 200.w, 60.h)),
                    ),
                  ),
                  Text(
                    page.subtitle,
                    style: AppTheme.displaySmall.copyWith(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),
          FadeTransition(
            opacity: _descFadeAnims[index],
            child: SlideTransition(
              position: _descSlideAnims[index],
              child: Text(
                page.description,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.65,
                  fontSize: 15.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildIllustration(OnboardingData page) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 220.w,
          height: 220.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                page.accentColor.withOpacity(0.12),
                page.accentColor.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 170.w,
          height: 170.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: page.accentColor.withOpacity(0.15),
              width: 1.5,
            ),
          ),
        ),
        Container(
          width: 130.w,
          height: 130.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: page.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withOpacity(0.35),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: page.accentColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(page.iconData, size: 58.w, color: AppColors.white),
        ),
      ],
    );
  }

  Widget _buildBottomSection(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 36.h),
      child: Column(
        children: [
          _buildPageIndicators(provider),
          SizedBox(height: 32.h),
          Row(
            children: [
              // Back button
              AnimatedOpacity(
                opacity: provider.isFirstPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedSlide(
                  offset: provider.isFirstPage
                      ? const Offset(-0.3, 0)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: provider.isFirstPage ? null : _onBackTap,
                    child: Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: AppColors.lightNeutral200,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 22.w,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (!provider.isFirstPage) SizedBox(width: 16.w),

              // Next / Get Started
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => _btnController.forward(),
                  onTapUp: (_) {
                    _btnController.reverse();
                    _onNextTap();
                  },
                  onTapCancel: () => _btnController.reverse(),
                  child: ScaleTransition(
                    scale: _btnScaleAnim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: page.gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: page.accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.isLastPage ? 'Get Started' : 'Next',
                            style: AppTheme.buttonLarge.copyWith(
                              color: AppColors.white,
                              fontSize: 16.sp,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              provider.isLastPage
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              key: ValueKey(provider.isLastPage),
                              color: AppColors.white,
                              size: 20.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(provider.totalPages, (index) {
        final isActive = index == provider.currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: isActive ? 28.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: isActive
                ? page.accentColor
                : page.accentColor.withOpacity(0.25),
          ),
        );
      }),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/models/onboard_data.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── PageController (view concern — stays in the screen) ──────
  late final PageController _pageController;

  // ── Animation controllers ────────────────────────────────────
  late List<AnimationController> _pageAnimControllers;
  late List<Animation<double>> _iconScaleAnims;
  late List<Animation<double>> _iconFadeAnims;
  late List<Animation<Offset>> _titleSlideAnims;
  late List<Animation<double>> _titleFadeAnims;
  late List<Animation<Offset>> _descSlideAnims;
  late List<Animation<double>> _descFadeAnims;

  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  late AnimationController _btnController;
  late Animation<double> _btnScaleAnim;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _pageController = PageController(initialPage: provider.currentPage);
    _setupAnimations(provider.totalPages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playPageAnimation(provider.currentPage);
    });
  }

  void _setupAnimations(int pageCount) {
    _pageAnimControllers = List.generate(
      pageCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      ),
    );

    _iconScaleAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
            ),
          ),
        )
        .toList();

    _iconFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    _titleSlideAnims = _pageAnimControllers
        .map(
          (c) => Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: c,
                  curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
                ),
              ),
        )
        .toList();

    _titleFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    _descSlideAnims = _pageAnimControllers
        .map(
          (c) => Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: c,
                  curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
                ),
              ),
        )
        .toList();

    _descFadeAnims = _pageAnimControllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: c,
              curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
            ),
          ),
        )
        .toList();

    // Floating orbs pulse — runs continuously
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _orbAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));

    // Button press-scale
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _btnScaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
  }

  void _playPageAnimation(int page) {
    _pageAnimControllers[page]
      ..reset()
      ..forward();
  }

  // ── Callbacks — delegate all logic to provider ───────────────

  void _onPageChanged(int index) {
    context.read<OnboardingProvider>().onPageChanged(index);
    _playPageAnimation(index);
  }

  void _onNextTap() {
    final provider = context.read<OnboardingProvider>();
    if (provider.isLastPage) {
      provider.requestNavigateAway();
      _navigateToLogin();
    } else {
      if (provider.goToNextPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _onBackTap() {
    if (context.read<OnboardingProvider>().goToPreviousPage()) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onSkipTap() {
    context.read<OnboardingProvider>().requestNavigateAway();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: LoginScreen()),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _pageAnimControllers) c.dispose();
    _orbController.dispose();
    _btnController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD — pure rendering, no logic
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Consumer<OnboardingProvider>(
        builder: (context, provider, _) {
          final page = provider.currentPageData;
          return Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    page.accentColor.withOpacity(0.15),
                    AppColors.lightNeutral100,
                    AppColors.lightNeutral100,
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    _buildBackgroundOrbs(page),
                    Column(
                      children: [
                        _buildTopBar(provider),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: provider.totalPages,
                            itemBuilder: (_, index) =>
                                _buildPage(index, provider.pages[index]),
                          ),
                        ),
                        _buildBottomSection(provider),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE WIDGET BUILDERS
  // ════════════════════════════════════════════════════════════

  Widget _buildBackgroundOrbs(OnboardingData page) {
    return AnimatedBuilder(
      animation: _orbAnimation,
      builder: (_, __) {
        final t = _orbAnimation.value;
        return Stack(
          children: [
            Positioned(
              top: -60 + (t * 20),
              right: -80 + (t * 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 280.w,
                height: 280.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.18),
                      page.accentColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100 - (t * 15),
              left: -50 + (t * 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.12),
                      page.accentColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: page.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppColors.white,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'POS App',
                style: AppTheme.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          AnimatedOpacity(
            opacity: provider.isLastPage ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: provider.isLastPage ? null : _onSkipTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.lightNeutral200,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Skip',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, OnboardingData page) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 16.h),
          FadeTransition(
            opacity: _iconFadeAnims[index],
            child: ScaleTransition(
              scale: _iconScaleAnims[index],
              child: _buildIllustration(page),
            ),
          ),
          SizedBox(height: 48.h),
          FadeTransition(
            opacity: _titleFadeAnims[index],
            child: SlideTransition(
              position: _titleSlideAnims[index],
              child: Column(
                children: [
                  Text(
                    page.title,
                    style: AppTheme.displaySmall.copyWith(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.0,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: page.gradientColors,
                        ).createShader(Rect.fromLTWH(0, 0, 200.w, 60.h)),
                    ),
                  ),
                  Text(
                    page.subtitle,
                    style: AppTheme.displaySmall.copyWith(
                      fontSize: 38.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),
          FadeTransition(
            opacity: _descFadeAnims[index],
            child: SlideTransition(
              position: _descSlideAnims[index],
              child: Text(
                page.description,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.65,
                  fontSize: 15.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildIllustration(OnboardingData page) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 220.w,
          height: 220.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                page.accentColor.withOpacity(0.12),
                page.accentColor.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 170.w,
          height: 170.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: page.accentColor.withOpacity(0.15),
              width: 1.5,
            ),
          ),
        ),
        Container(
          width: 130.w,
          height: 130.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: page.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: page.accentColor.withOpacity(0.35),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: page.accentColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            IconData(
              int.parse(page.iconCodePoint.replaceFirst('0x', ''), radix: 16),
              fontFamily: 'MaterialIcons',
            ),
            size: 58.w,
            color: AppColors.white,
          ),
        ),
        // ... rest of the positioned widgets
      ],
    );
  }

  Widget _buildBottomSection(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 36.h),
      child: Column(
        children: [
          _buildPageIndicators(provider),
          SizedBox(height: 32.h),
          Row(
            children: [
              // Back button
              AnimatedOpacity(
                opacity: provider.isFirstPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedSlide(
                  offset: provider.isFirstPage
                      ? const Offset(-0.3, 0)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onTap: provider.isFirstPage ? null : _onBackTap,
                    child: Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: AppColors.lightNeutral200,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 22.w,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (!provider.isFirstPage) SizedBox(width: 16.w),

              // Next / Get Started
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => _btnController.forward(),
                  onTapUp: (_) {
                    _btnController.reverse();
                    _onNextTap();
                  },
                  onTapCancel: () => _btnController.reverse(),
                  child: ScaleTransition(
                    scale: _btnScaleAnim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: page.gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: page.accentColor.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.isLastPage ? 'Get Started' : 'Next',
                            style: AppTheme.buttonLarge.copyWith(
                              color: AppColors.white,
                              fontSize: 16.sp,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              provider.isLastPage
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              key: ValueKey(provider.isLastPage),
                              color: AppColors.white,
                              size: 20.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(OnboardingProvider provider) {
    final page = provider.currentPageData;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(provider.totalPages, (index) {
        final isActive = index == provider.currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: isActive ? 28.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: isActive
                ? page.accentColor
                : page.accentColor.withOpacity(0.25),
          ),
        );
      }),
    );
  }
}*/

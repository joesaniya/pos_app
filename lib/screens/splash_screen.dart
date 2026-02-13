import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/splash_provider.dart';
import 'package:pos_app/screens/dashboard_screen.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeScaleController;
  late AnimationController _scrollController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _scrollAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  void _setupAnimations() {
    _fadeScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeScaleController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeScaleController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scrollAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
          CurvedAnimation(parent: _scrollController, curve: Curves.easeInBack),
        );

    _fadeScaleController.forward();
  }

  Future<void> _initializeApp() async {
    // Safe to call — we're guaranteed to be post-frame here
    final splashProvider = context.read<SplashProvider>();

    await splashProvider.initializeApp();

    if (!mounted) return;

    // Play scroll-out animation before navigating
    await _scrollController.forward();

    if (!mounted) return;

    if (splashProvider.isFirstLaunch) {
      _navigateToOnboarding();
    } else if (splashProvider.isLoggedIn) {
      _navigateToHome();
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _fadeScaleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlideTransition(
        position: _scrollAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated Logo
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildLogo(),
                  ),
                ),

                SizedBox(height: 24.h),

                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'POS App',
                    style: AppTheme.displayLarge.copyWith(
                      color: AppColors.white,
                      fontSize: 32.sp,
                    ),
                  ),
                ),

                SizedBox(height: 8.h),

                // Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Connect & Collaborate',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppColors.white.withOpacity(0.8),
                      fontSize: 14.sp,
                    ),
                  ),
                ),

                const Spacer(),

                // Loading / Error state
                Consumer<SplashProvider>(
                  builder: (context, provider, child) {
                    if (provider.errorMessage.isNotEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Text(
                          provider.errorMessage,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(
                          width: 36.w,
                          height: 36.w,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                            strokeWidth: 3.w,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Loading...',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                SizedBox(height: 48.h),

                Text(
                  'Version 1.0.0',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppColors.white.withOpacity(0.5),
                    fontSize: 10.sp,
                  ),
                ),

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120.w,
      height: 120.w,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.connect_without_contact_rounded,
          size: 60.w,
          color: AppColors.primaryPurple,
        ),
      ),
    );
  }
}

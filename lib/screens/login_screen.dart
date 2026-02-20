import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/auth_provider.dart';
import 'package:pos_app/screens/forgot_pwd_screen.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/signup_screen.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_divider_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
import 'package:pos_app/screens/widgets/auth_step_footer_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_btn_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_container_widget.dart';
import 'package:pos_app/screens/widgets/checkbox_widget.dart';
import 'package:pos_app/screens/widgets/pwd_visiblity_check_widget.dart';
import 'package:pos_app/screens/widgets/resend_otp_row_widget.dart';
import 'package:pos_app/screens/widgets/social_media_login_btn_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────

  Future<void> _handleLogin(AuthProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    bool success = false;

    if (provider.isEmailPasswordMethod) {
      success = await provider.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      if (provider.otpSent) {
        success = await provider.verifyOTP(
          phone: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );
      } else {
        success = await provider.sendOTP(phone: _phoneController.text.trim());
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('OTP sent successfully!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }
        }
        return;
      }
    }

    if (mounted) {
      if (success) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PageSwitcher(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        /* ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login successful!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PageSwitcher(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
            transitionDuration: const Duration(milliseconds: 450),
          ),
        );*/
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleResendOTP(AuthProvider provider) async {
    final success = await provider.resendOTP(
      phone: _phoneController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'OTP resent successfully!' : 'Failed to resend OTP',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }

  Future<void> _handleSocialLogin(AuthProvider provider, String type) async {
    final success = await provider.socialLogin(provider: type);

    if (mounted) {
      if (success) {
        // TODO: Navigate to home screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type login successful!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const SignupScreen()),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.lightNeutral100,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Consumer<AuthProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 40.h),
                          _buildHeader(),
                          SizedBox(height: 48.h),
                          _buildLoginMethodTabs(provider),
                          SizedBox(height: 32.h),
                          _buildForm(provider),
                          SizedBox(height: 24.h),
                          if (provider.isEmailPasswordMethod)
                            _buildRememberMeAndForgot(provider),
                          SizedBox(height: 32.h),
                          _buildActionButton(provider),
                          SizedBox(height: 24.h),
                          _buildDivider(),
                          SizedBox(height: 24.h),
                          _buildSocialLogin(provider),
                          SizedBox(height: 32.h),
                          /*_buildFooter(),
                          SizedBox(height: 24.h),*/
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────

  Widget _buildHeader() {
    return const AuthHeader(
      title: 'Welcome Back!',
      subtitle: 'Sign in to continue to your account',
      showLogo: true,
    );
  }

  Widget _buildLoginMethodTabs(AuthProvider provider) {
    return AuthTabContainer(
      children: [
        AuthTabButton(
          label: 'Email / Password',
          isActive: provider.isEmailPasswordMethod,
          onTap: provider.switchToEmailPassword,
        ),
        AuthTabButton(
          label: 'Phone / OTP',
          isActive: provider.isPhoneOtpMethod,
          onTap: provider.switchToPhoneOtp,
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider provider) {
    return Form(
      key: _formKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: provider.isEmailPasswordMethod
            ? _buildEmailPasswordForm(provider)
            : _buildPhoneOTPForm(provider),
      ),
    );
  }

  Widget _buildEmailPasswordForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('email-password'),
      children: [
        AuthTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: !provider.isPasswordVisible,
          suffixIcon: PasswordVisibilityButton(
            isVisible: provider.isPasswordVisible,
            onToggle: provider.togglePasswordVisibility,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneOTPForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('phone-otp'),
      children: [
        AuthTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          enabled: !provider.otpSent,
          maxLength: 10,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        if (provider.otpSent) ...[
          SizedBox(height: 16.h),
          AuthTextField(
            controller: _otpController,
            label: 'OTP',
            hint: 'Enter 6-digit OTP',
            prefixIcon: Icons.lock_clock_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter OTP';
              }
              if (value.length < 4) {
                return 'Please enter a valid OTP';
              }
              return null;
            },
          ),
          SizedBox(height: 12.h),
          ResendOTPRow(onResend: () => _handleResendOTP(provider)),
        ],
      ],
    );
  }

  Widget _buildRememberMeAndForgot(AuthProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AuthCheckbox(
          value: provider.rememberMe,
          onChanged: provider.toggleRememberMe,
          label: 'Remember me',
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            );
          },
          child: Text(
            'Forgot Password?',
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(AuthProvider provider) {
    return AuthPrimaryButton(
      label: provider.isPhoneOtpMethod && !provider.otpSent
          ? 'Send OTP'
          : 'Sign In',
      isLoading: provider.isLoading,
      onTap: () => _handleLogin(provider),
    );
  }

  Widget _buildDivider() {
    return const AuthDivider();
  }

  Widget _buildSocialLogin(AuthProvider provider) {
    return Column(
      children: [
        SocialLoginButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          color: const Color(0xFFDB4437),
          onTap: () => _handleSocialLogin(provider, 'Google'),
        ),
        SizedBox(height: 12.h),
        SocialLoginButton(
          icon: Icons.apple_rounded,
          label: 'Continue with Apple',
          color: AppColors.textPrimary,
          onTap: () => _handleSocialLogin(provider, 'Apple'),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return AuthFooterText(
      text: 'Don\'t have an account? ',
      actionText: 'Sign Up',
      onActionTap: _navigateToSignup,
    );
  }
}




/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/auth_provider.dart';
import 'package:pos_app/screens/forgot_pwd_screen.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/signup_screen.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_divider_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
import 'package:pos_app/screens/widgets/auth_step_footer_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_btn_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_container_widget.dart';
import 'package:pos_app/screens/widgets/checkbox_widget.dart';
import 'package:pos_app/screens/widgets/pwd_visiblity_check_widget.dart';
import 'package:pos_app/screens/widgets/resend_otp_row_widget.dart';
import 'package:pos_app/screens/widgets/social_media_login_btn_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _showSnackBar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PageSwitcher(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────

  Future<void> _handleLogin(AuthProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    if (provider.isEmailPasswordMethod) {
      // ── Email / Password Login ────────────────────────────────
      final result = await provider.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        _navigateToHome();
      } else {
        _showSnackBar(result.error ?? 'Login failed. Please try again.', false);
      }
    } else {
      // ── Phone / OTP Login ─────────────────────────────────────
      if (!provider.otpSent) {
        // Step 1: Send OTP
        final result =
            await provider.sendOTP(phone: _phoneController.text.trim());

        if (!mounted) return;

        if (result.success) {
          _showSnackBar('OTP sent successfully!', true);
        } else {
          _showSnackBar(
              result.error ?? 'Failed to send OTP. Please try again.', false);
        }
      } else {
        // Step 2: Verify OTP
        final result = await provider.verifyOTP(
          phone: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );

        if (!mounted) return;

        if (result.success) {
          _navigateToHome();
        } else {
          _showSnackBar(
              result.error ?? 'Invalid OTP. Please try again.', false);
        }
      }
    }
  }

  Future<void> _handleResendOTP(AuthProvider provider) async {
    final result =
        await provider.resendOTP(phone: _phoneController.text.trim());

    if (!mounted) return;

    _showSnackBar(
      result.success
          ? 'OTP resent successfully!'
          : result.error ?? 'Failed to resend OTP',
      result.success,
    );
  }

  Future<void> _handleSocialLogin(AuthProvider provider, String type) async {
    final result = await provider.socialLogin(provider: type);

    if (!mounted) return;

    if (result.success) {
      _navigateToHome();
    } else {
      _showSnackBar(result.error ?? '$type sign in failed.', false);
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: const SignupScreen()),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.lightNeutral100,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Consumer<AuthProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 40.h),
                          _buildHeader(),
                          SizedBox(height: 48.h),
                          _buildLoginMethodTabs(provider),
                          SizedBox(height: 32.h),
                          _buildForm(provider),
                          SizedBox(height: 24.h),
                          if (provider.isEmailPasswordMethod)
                            _buildRememberMeAndForgot(provider),
                          SizedBox(height: 32.h),
                          _buildActionButton(provider),
                          SizedBox(height: 24.h),
                          _buildDivider(),
                          SizedBox(height: 24.h),
                          _buildSocialLogin(provider),
                          SizedBox(height: 32.h),
                          _buildFooter(),
                          SizedBox(height: 24.h),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────

  Widget _buildHeader() {
    return const AuthHeader(
      title: 'Welcome Back!',
      subtitle: 'Sign in to continue to your account',
      showLogo: true,
    );
  }

  Widget _buildLoginMethodTabs(AuthProvider provider) {
    return AuthTabContainer(
      children: [
        AuthTabButton(
          label: 'Email / Password',
          isActive: provider.isEmailPasswordMethod,
          onTap: provider.switchToEmailPassword,
        ),
        AuthTabButton(
          label: 'Phone / OTP',
          isActive: provider.isPhoneOtpMethod,
          onTap: provider.switchToPhoneOtp,
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider provider) {
    return Form(
      key: _formKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: provider.isEmailPasswordMethod
            ? _buildEmailPasswordForm(provider)
            : _buildPhoneOTPForm(provider),
      ),
    );
  }

  Widget _buildEmailPasswordForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('email-password'),
      children: [
        AuthTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: 16.h),
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: !provider.isPasswordVisible,
          suffixIcon: PasswordVisibilityButton(
            isVisible: provider.isPasswordVisible,
            onToggle: provider.togglePasswordVisibility,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneOTPForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('phone-otp'),
      children: [
        AuthTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          enabled: !provider.otpSent,
          maxLength: 10,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        if (provider.otpSent) ...[
          SizedBox(height: 16.h),
          AuthTextField(
            controller: _otpController,
            label: 'OTP',
            hint: 'Enter 6-digit OTP',
            prefixIcon: Icons.lock_clock_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter OTP';
              }
              if (value.length < 4) {
                return 'Please enter a valid OTP';
              }
              return null;
            },
          ),
          SizedBox(height: 12.h),
          ResendOTPRow(onResend: () => _handleResendOTP(provider)),
        ],
      ],
    );
  }

  Widget _buildRememberMeAndForgot(AuthProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AuthCheckbox(
          value: provider.rememberMe,
          onChanged: provider.toggleRememberMe,
          label: 'Remember me',
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen()),
            );
          },
          child: Text(
            'Forgot Password?',
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(AuthProvider provider) {
    return AuthPrimaryButton(
      label: provider.isPhoneOtpMethod && !provider.otpSent
          ? 'Send OTP'
          : 'Sign In',
      isLoading: provider.isLoading,
      onTap: () => _handleLogin(provider),
    );
  }

  Widget _buildDivider() => const AuthDivider();

  Widget _buildSocialLogin(AuthProvider provider) {
    return Column(
      children: [
        SocialLoginButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          color: const Color(0xFFDB4437),
          onTap: () => _handleSocialLogin(provider, 'Google'),
        ),
        SizedBox(height: 12.h),
        SocialLoginButton(
          icon: Icons.apple_rounded,
          label: 'Continue with Apple',
          color: AppColors.textPrimary,
          onTap: () => _handleSocialLogin(provider, 'Apple'),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return AuthFooterText(
      text: 'Don\'t have an account? ',
      actionText: 'Sign Up',
      onActionTap: _navigateToSignup,
    );
  }
}
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/screens/forgot_pwd_screen.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/subscription_expired_screen.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_divider_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _autoFillBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initRememberMe());
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

  Future<void> _initRememberMe() async {
    final provider = Provider.of<AppAuthenticationProvider>(
      context,
      listen: false,
    );
    await provider.loadRememberedCredentials();

    if (!mounted) return;

    final creds = provider.rememberedCredentials;
    if (creds == null) return;

    if (creds.isEmailMethod) {
      _emailController.text = creds.email;
      _passwordController.text = creds.password;
    } else if (creds.isPhoneMethod) {
      _phoneController.text = creds.phone;
    }

    setState(() => _autoFillBannerDismissed = false);
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

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;

    Provider.of<AppAuthenticationProvider>(
      context,
      listen: false,
    ).clearNavigatingFlag();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const PageSwitcher(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToSubscriptionExpired() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const SubscriptionExpiredScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  Future<void> _handleEmailLogin(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await provider.loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    switch (result) {
      case LoginResult.success:
        _navigateToHome();
        break;

      case LoginResult.emailNotFound:
        _showSnackBar('Username not found.');
        break;

      case LoginResult.wrongPassword:
        _handleWrongPassword(provider);
        _showSnackBar('Invalid password.');
        break;

      case LoginResult.invalidCredentials:
        _showSnackBar('Invalid credentials.');
        break;

      case LoginResult.inactive:
        _showSnackBar('Your account is inactive. Please contact your admin.');
        break;

      case LoginResult.subscriptionExpired:
        // Redirect to the subscription expired screen — same as phone OTP flow.
        _navigateToSubscriptionExpired();
        break;

      case LoginResult.error:
        _showSnackBar('Something went wrong. Please try again.');
        break;
    }
    /*switch (result) {
      case LoginResult.success:
        _navigateToHome();
        break;
      case LoginResult.emailNotFound:
        _showSnackBar('Username not found.');
        break;
      case LoginResult.wrongPassword:
       
        _handleWrongPassword(provider);
        _showSnackBar('Invalid password.');
        break;
      case LoginResult.invalidCredentials:
        _showSnackBar('Invalid credentials.');
        break;
      case LoginResult.inactive:
        _showSnackBar('Your account is inactive. Please contact your admin.');
        break;
      case LoginResult.error:
        _showSnackBar('Something went wrong. Please try again.');
        break;
    }*/
  }

  void _handleWrongPassword(AppAuthenticationProvider provider) {
    _passwordController.clear();
    if (provider.hasRememberedCredentials) {
      provider.clearRememberedCredentials();
      setState(() => _autoFillBannerDismissed = true);
    }
  }

  Future<void> _handleSocialLogin(
    AppAuthenticationProvider provider,
    String type,
  ) async {
    if (type == 'Google') {
      final result = await provider.signInWithGoogle();
      if (!mounted) return;
      switch (result) {
        case 'success':
          _navigateToHome();
          break;
        case 'not_found':
          _showSnackBar('No record found.');
          break;
        case 'inactive':
          _showSnackBar('Your account is inactive. Please contact your admin.');
          break;
        case 'cancelled':
          break;
        default:
          _showSnackBar('Google sign-in failed. Please try again.');
      }
      return;
    }

    final success = await provider.socialLogin(provider: type);
    if (mounted && success) {
      _showSnackBar('$type login successful!', isSuccess: true);
    }
  }

  Future<void> _handleSendOTP(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await provider.sendOTP(phone: _phoneController.text.trim());

    if (!mounted) return;

    switch (result) {
      case 'success':
        _showSnackBar('OTP sent successfully!', isSuccess: true);
        break;
      case 'not_found':
        _showSnackBar(
          'This phone number is not registered. Please contact your admin.',
        );
        break;
      case 'inactive':
        _showSnackBar('Your account is inactive. Please contact your admin.');
        break;
      default:
        _showSnackBar('Failed to send OTP. Please try again.');
    }
  }

  Future<void> _handleVerifyOTP(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await provider.verifyOTP(
      phone: _phoneController.text.trim(),
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;

    switch (result) {
      case OtpResult.success:
        _navigateToHome();
        break;
      case OtpResult.subscriptionExpired:
        // Redirect to the subscription expired screen — same as email flow.
        _navigateToSubscriptionExpired();
        break;
      case OtpResult.error:
        _showSnackBar('Invalid OTP. Please check and try again.');
        break;
    }
  }

  Future<void> _handleAction(AppAuthenticationProvider provider) async {
    if (provider.isEmailPasswordMethod) {
      await _handleEmailLogin(provider);
    } else {
      if (!provider.otpSent) {
        await _handleSendOTP(provider);
      } else {
        await _handleVerifyOTP(provider);
      }
    }
  }

  Future<void> _handleResendOTP(AppAuthenticationProvider provider) async {
    final result = await provider.resendOTP(
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (result == 'success') {
      _showSnackBar('OTP resent successfully!', isSuccess: true);
    } else {
      _showSnackBar('Failed to resend OTP. Please try again.');
    }
  }

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
                  child: Consumer<AppAuthenticationProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 40.h),
                          _buildHeader(),
                          SizedBox(height: 32.h),

                          if (provider.hasRememberedCredentials &&
                              !_autoFillBannerDismissed)
                            _buildAutoFillBanner(provider),

                          SizedBox(height: 16.h),
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

  Widget _buildHeader() {
    return const AuthHeader(
      title: 'Welcome Back!',
      subtitle: 'Sign in to continue to your account',
      showLogo: true,
    );
  }

  Widget _buildAutoFillBanner(AppAuthenticationProvider provider) {
    final creds = provider.rememberedCredentials!;
    final label = creds.isEmailMethod ? creds.email : creds.phone;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16.sp,
            color: AppColors.primaryPurple,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTheme.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
                children: [
                  const TextSpan(text: 'Auto-filled for '),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await provider.clearRememberedCredentials();
              _emailController.clear();
              _passwordController.clear();
              _phoneController.clear();
              setState(() => _autoFillBannerDismissed = true);
            },
            child: Text(
              'Not you?',
              style: AppTheme.labelSmall.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMethodTabs(AppAuthenticationProvider provider) {
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

  Widget _buildForm(AppAuthenticationProvider provider) {
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

  Widget _buildEmailPasswordForm(AppAuthenticationProvider provider) {
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
            if (value == null || value.isEmpty)
              return 'Please enter your email';
            if (!value.contains('@')) return 'Please enter a valid email';
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
            if (value == null || value.isEmpty)
              return 'Please enter your password';
            if (value.length < 6)
              return 'Password must be at least 6 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneOTPForm(AppAuthenticationProvider provider) {
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
            if (value == null || value.isEmpty)
              return 'Please enter your phone number';
            if (value.length < 10)
              return 'Please enter a valid 10-digit phone number';
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
              if (value == null || value.isEmpty) return 'Please enter OTP';
              if (value.length < 6) return 'OTP must be 6 digits';
              return null;
            },
          ),
          SizedBox(height: 12.h),
          ResendOTPRow(onResend: () => _handleResendOTP(provider)),
        ],
      ],
    );
  }

  Widget _buildRememberMeAndForgot(AppAuthenticationProvider provider) {
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

  Widget _buildActionButton(AppAuthenticationProvider provider) {
    String label;
    if (provider.isEmailPasswordMethod) {
      label = 'Sign In';
    } else if (!provider.otpSent) {
      label = 'Send OTP';
    } else {
      label = 'Verify & Sign In';
    }

    return AuthPrimaryButton(
      label: label,
      isLoading: provider.isLoading,
      onTap: () => _handleAction(provider),
    );
  }

  Widget _buildDivider() => const AuthDivider();

  Widget _buildSocialLogin(AppAuthenticationProvider provider) {
    return Column(
      children: [
        SocialLoginButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          color: const Color(0xFFDB4437),
          onTap: () => _handleSocialLogin(provider, 'Google'),
        ),
        SizedBox(height: 12.h),
        /* SocialLoginButton(
          icon: Icons.apple_rounded,
          label: 'Continue with Apple',
          color: AppColors.textPrimary,
          onTap: () => _handleSocialLogin(provider, 'Apple'),
        ),*/
      ],
    );
  }
}



/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/screens/forgot_pwd_screen.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_divider_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
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

  // ── Track if auto-fill banner was dismissed ───────────────────
  bool _autoFillBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Load remembered credentials after first frame so provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRememberMe());
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

  /// Loads remembered credentials and auto-fills fields.
  Future<void> _initRememberMe() async {
    final provider = Provider.of<AppAuthenticationProvider>(
      context,
      listen: false,
    );
    await provider.loadRememberedCredentials();

    if (!mounted) return;

    final creds = provider.rememberedCredentials;
    if (creds == null) return;

    if (creds.isEmailMethod) {
      _emailController.text = creds.email;
      _passwordController.text = creds.password;
    } else if (creds.isPhoneMethod) {
      _phoneController.text = creds.phone;
    }

    // Show the auto-fill banner
    setState(() => _autoFillBannerDismissed = false);
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

  // ── Snackbar Helper ───────────────────────────────────────────
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  // ── Navigate to Home ──────────────────────────────────────────
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const PageSwitcher(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Handle Login (Email/Password) ─────────────────────────────
  Future<void> _handleEmailLogin(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await provider.loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    switch (result) {
      case LoginResult.success:
        _navigateToHome();
        break;
      case LoginResult.emailNotFound:
        _showSnackBar('Username not found.');
        break;
      case LoginResult.wrongPassword:
        // If remembered password is wrong, clear it so user isn't stuck
        _handleWrongPassword(provider);
        _showSnackBar('Invalid password.');
        break;
      case LoginResult.invalidCredentials:
        _showSnackBar('Invalid credentials.');
        break;
      case LoginResult.inactive:
        _showSnackBar('Your account is inactive. Please contact your admin.');
        break;
      case LoginResult.error:
        _showSnackBar('Something went wrong. Please try again.');
        break;
    }
  }

  /// Called on wrong password — clears saved password so the user
  /// must re-enter it; prevents them being permanently locked out
  /// of the auto-fill loop.
  void _handleWrongPassword(AppAuthenticationProvider provider) {
    _passwordController.clear();
    if (provider.hasRememberedCredentials) {
      provider.clearRememberedCredentials();
      setState(() => _autoFillBannerDismissed = true);
    }
  }

  // ── Social Login ──────────────────────────────────────────────
  Future<void> _handleSocialLogin(
    AppAuthenticationProvider provider,
    String type,
  ) async {
    if (type == 'Google') {
      final result = await provider.signInWithGoogle();
      if (!mounted) return;
      switch (result) {
        case 'success':
          _navigateToHome();
          break;
        case 'not_found':
          _showSnackBar('No record found.');
          break;
        case 'inactive':
          _showSnackBar('Your account is inactive. Please contact your admin.');
          break;
        case 'cancelled':
          break;
        default:
          _showSnackBar('Google sign-in failed. Please try again.');
      }
      return;
    }

    final success = await provider.socialLogin(provider: type);
    if (mounted && success) {
      _showSnackBar('$type login successful!', isSuccess: true);
    }
  }

  // ── Handle Send OTP ───────────────────────────────────────────
  Future<void> _handleSendOTP(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await provider.sendOTP(phone: _phoneController.text.trim());

    if (!mounted) return;

    switch (result) {
      case 'success':
        _showSnackBar('OTP sent successfully!', isSuccess: true);
        break;
      case 'not_found':
        _showSnackBar(
          'This phone number is not registered. Please contact your admin.',
        );
        break;
      case 'inactive':
        _showSnackBar('Your account is inactive. Please contact your admin.');
        break;
      default:
        _showSnackBar('Failed to send OTP. Please try again.');
    }
  }

  // ── Handle Verify OTP ─────────────────────────────────────────
  Future<void> _handleVerifyOTP(AppAuthenticationProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await provider.verifyOTP(
      phone: _phoneController.text.trim(),
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _navigateToHome();
    } else {
      _showSnackBar('Invalid OTP. Please check and try again.');
    }
  }

  // ── Unified action button handler ─────────────────────────────
  Future<void> _handleAction(AppAuthenticationProvider provider) async {
    if (provider.isEmailPasswordMethod) {
      await _handleEmailLogin(provider);
    } else {
      if (!provider.otpSent) {
        await _handleSendOTP(provider);
      } else {
        await _handleVerifyOTP(provider);
      }
    }
  }

  // ── Handle Resend OTP ─────────────────────────────────────────
  Future<void> _handleResendOTP(AppAuthenticationProvider provider) async {
    final result = await provider.resendOTP(
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (result == 'success') {
      _showSnackBar('OTP resent successfully!', isSuccess: true);
    } else {
      _showSnackBar('Failed to resend OTP. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
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
                  child: Consumer<AppAuthenticationProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 40.h),
                          _buildHeader(),
                          SizedBox(height: 32.h),

                          // ── Auto-fill banner ──────────────────
                          if (provider.hasRememberedCredentials &&
                              !_autoFillBannerDismissed)
                            _buildAutoFillBanner(provider),

                          SizedBox(height: 16.h),
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

  // ═══════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return const AuthHeader(
      title: 'Welcome Back!',
      subtitle: 'Sign in to continue to your account',
      showLogo: true,
    );
  }

  /// Small banner that tells the user their credentials were auto-filled,
  /// with a "Not you?" button to clear and start fresh.
  Widget _buildAutoFillBanner(AppAuthenticationProvider provider) {
    final creds = provider.rememberedCredentials!;
    final label = creds.isEmailMethod ? creds.email : creds.phone;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16.sp,
            color: AppColors.primaryPurple,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTheme.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
                children: [
                  const TextSpan(text: 'Auto-filled for '),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await provider.clearRememberedCredentials();
              _emailController.clear();
              _passwordController.clear();
              _phoneController.clear();
              setState(() => _autoFillBannerDismissed = true);
            },
            child: Text(
              'Not you?',
              style: AppTheme.labelSmall.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMethodTabs(AppAuthenticationProvider provider) {
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

  Widget _buildForm(AppAuthenticationProvider provider) {
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

  Widget _buildEmailPasswordForm(AppAuthenticationProvider provider) {
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
            if (value == null || value.isEmpty)
              return 'Please enter your email';
            if (!value.contains('@')) return 'Please enter a valid email';
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
            if (value == null || value.isEmpty)
              return 'Please enter your password';
            if (value.length < 6)
              return 'Password must be at least 6 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneOTPForm(AppAuthenticationProvider provider) {
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
            if (value == null || value.isEmpty)
              return 'Please enter your phone number';
            if (value.length < 10)
              return 'Please enter a valid 10-digit phone number';
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
              if (value == null || value.isEmpty) return 'Please enter OTP';
              if (value.length < 6) return 'OTP must be 6 digits';
              return null;
            },
          ),
          SizedBox(height: 12.h),
          ResendOTPRow(onResend: () => _handleResendOTP(provider)),
        ],
      ],
    );
  }

  Widget _buildRememberMeAndForgot(AppAuthenticationProvider provider) {
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

  Widget _buildActionButton(AppAuthenticationProvider provider) {
    String label;
    if (provider.isEmailPasswordMethod) {
      label = 'Sign In';
    } else if (!provider.otpSent) {
      label = 'Send OTP';
    } else {
      label = 'Verify & Sign In';
    }

    return AuthPrimaryButton(
      label: label,
      isLoading: provider.isLoading,
      onTap: () => _handleAction(provider),
    );
  }

  Widget _buildDivider() => const AuthDivider();

  Widget _buildSocialLogin(AppAuthenticationProvider provider) {
    return Column(
      children: [
        SocialLoginButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          color: const Color(0xFFDB4437),
          onTap: () => _handleSocialLogin(provider, 'Google'),
        ),
        /*  SizedBox(height: 12.h),
        SocialLoginButton(
          icon: Icons.apple_rounded,
          label: 'Continue with Apple',
          color: AppColors.textPrimary,
          onTap: () => _handleSocialLogin(provider, 'Apple'),
        ),*/
      ],
    );
  }
}*/
//phoneotp login issue


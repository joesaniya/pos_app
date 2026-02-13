import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/auth_provider.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_backbtn_widget.dart';
import 'package:pos_app/screens/widgets/auth_divider_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
import 'package:pos_app/screens/widgets/auth_step_footer_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_btn_widget.dart';
import 'package:pos_app/screens/widgets/auth_tab_container_widget.dart';
import 'package:pos_app/screens/widgets/pwd_visiblity_check_widget.dart';
import 'package:pos_app/screens/widgets/resend_otp_row_widget.dart';
import 'package:pos_app/screens/widgets/social_media_login_btn_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Snackbar Helper ───────────────────────────────────────────
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────

  Future<void> _handleSignup(AuthProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    if (!provider.agreedToTerms) {
      _showSnackBar('Please agree to Terms & Conditions', AppColors.warning);
      return;
    }

    bool success = false;

    if (provider.isEmailPasswordMethod) {
      success = await provider.signupWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
      );
    } else {
      if (provider.otpSent) {
        success = await provider.signupWithPhone(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );
      } else {
        success = await provider.sendOTP(phone: _phoneController.text.trim());
        if (success && mounted) {
          _showSnackBar('OTP sent successfully!', AppColors.success);
        }
        return;
      }
    }

    if (mounted) {
      _showSnackBar(
        success
            ? 'Account created successfully!'
            : 'Signup failed. Please try again.',
        success ? AppColors.success : AppColors.error,
      );
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
  }

  Future<void> _handleResendOTP(AuthProvider provider) async {
    final success = await provider.resendOTP(
      phone: _phoneController.text.trim(),
    );
    if (mounted) {
      _showSnackBar(
        success ? 'OTP resent successfully!' : 'Failed to resend OTP',
        success ? AppColors.success : AppColors.error,
      );
    }
  }

  Future<void> _handleSocialSignup(AuthProvider provider, String type) async {
    final success = await provider.socialLogin(provider: type);
    if (mounted && success) {
      // TODO: Navigate to home screen
      _showSnackBar('$type signup successful!', AppColors.success);
    }
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
                          SizedBox(height: 24.h),

                          // ── Back Button (reusable) ──────────
                          AuthBackButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                          SizedBox(height: 24.h),

                          // ── Header (reusable) ───────────────
                          AuthHeader(
                            title: 'Create Account',
                            subtitle:
                                'Sign up to get started with your account',
                            showLogo: false,
                          ),
                          SizedBox(height: 40.h),

                          // ── Method Tabs (reusable) ──────────
                          AuthTabContainer(
                            children: [
                              AuthTabButton(
                                label: 'Email',
                                isActive: provider.isEmailPasswordMethod,
                                onTap: provider.switchToEmailPassword,
                              ),
                              AuthTabButton(
                                label: 'Phone',
                                isActive: provider.isPhoneOtpMethod,
                                onTap: provider.switchToPhoneOtp,
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),

                          // ── Animated Form ───────────────────
                          _buildForm(provider),
                          SizedBox(height: 24.h),

                          // ── Terms Checkbox ──────────────────
                          _buildTermsCheckbox(provider),
                          SizedBox(height: 32.h),

                          // ── Action Button (reusable) ────────
                          AuthPrimaryButton(
                            label:
                                provider.isPhoneOtpMethod && !provider.otpSent
                                ? 'Send OTP'
                                : 'Create Account',
                            onTap: () => _handleSignup(provider),
                            isLoading: provider.isLoading,
                          ),
                          SizedBox(height: 24.h),

                          // ── Divider (reusable) ──────────────
                          const AuthDivider(),
                          SizedBox(height: 24.h),

                          // ── Social Signup (reusable) ────────
                          _buildSocialSignup(provider),
                          SizedBox(height: 32.h),

                          // ── Footer (reusable) ───────────────
                          AuthFooterText(
                            text: 'Already have an account? ',
                            actionText: 'Sign In',
                            onActionTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
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

  // ── Form Router ───────────────────────────────────────────────

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
            ? _buildEmailSignupForm(provider)
            : _buildPhoneSignupForm(provider),
      ),
    );
  }

  // ── Email Form ────────────────────────────────────────────────

  Widget _buildEmailSignupForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('email-signup'),
      children: [
        // Full Name (reusable)
        AuthTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your name';
            if (value.length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        SizedBox(height: 16.h),

        // Email (reusable)
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

        // Phone (reusable)
        AuthTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Please enter your phone number';
            if (value.length < 10) return 'Please enter a valid phone number';
            return null;
          },
        ),
        SizedBox(height: 16.h),

        // Password (reusable)
        AuthTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a password',
          prefixIcon: Icons.lock_outline,
          obscureText: !provider.isPasswordVisible,
          suffixIcon: PasswordVisibilityButton(
            isVisible: provider.isPasswordVisible,
            onToggle: provider.togglePasswordVisibility,
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Please enter a password';
            if (value.length < 6)
              return 'Password must be at least 6 characters';
            return null;
          },
        ),
        SizedBox(height: 16.h),

        // Confirm Password (reusable)
        AuthTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: !provider.isConfirmPasswordVisible,
          suffixIcon: PasswordVisibilityButton(
            isVisible: provider.isConfirmPasswordVisible,
            onToggle: provider.toggleConfirmPasswordVisibility,
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Please confirm your password';
            if (value != _passwordController.text)
              return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }

  // ── Phone Form ────────────────────────────────────────────────

  Widget _buildPhoneSignupForm(AuthProvider provider) {
    return Column(
      key: const ValueKey('phone-signup'),
      children: [
        // Full Name (reusable) — disabled after OTP sent
        AuthTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          keyboardType: TextInputType.name,
          enabled: !provider.otpSent,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your name';
            if (value.length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        SizedBox(height: 16.h),

        // Phone (reusable) — disabled after OTP sent
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
            if (value.length < 10) return 'Please enter a valid phone number';
            return null;
          },
        ),

        // OTP Field + Resend — shown only after OTP sent
        if (provider.otpSent) ...[
          SizedBox(height: 16.h),

          // OTP (reusable)
          AuthTextField(
            controller: _otpController,
            label: 'OTP',
            hint: 'Enter 6-digit OTP',
            prefixIcon: Icons.lock_clock_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter OTP';
              if (value.length < 4) return 'Please enter a valid OTP';
              return null;
            },
          ),
          SizedBox(height: 12.h),

          // Resend Row (reusable)
          ResendOTPRow(onResend: () => _handleResendOTP(provider)),
        ],
      ],
    );
  }

  // ── Terms Checkbox ────────────────────────────────────────────
  // kept inline: needs RichText with TapGestureRecognizer for Terms & Privacy links

  Widget _buildTermsCheckbox(AuthProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20.w,
          height: 20.w,
          child: Checkbox(
            value: provider.agreedToTerms,
            onChanged: (_) => provider.toggleAgreedToTerms(),
            activeColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTheme.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      HapticFeedback.lightImpact();
                      // TODO: Show terms and conditions
                    },
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      HapticFeedback.lightImpact();
                      // TODO: Show privacy policy
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Social Signup ─────────────────────────────────────────────

  Widget _buildSocialSignup(AuthProvider provider) {
    return Column(
      children: [
        // Google (reusable)
        SocialLoginButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Sign up with Google',
          color: const Color(0xFFDB4437),
          onTap: () => _handleSocialSignup(provider, 'Google'),
        ),
        SizedBox(height: 12.h),

        // Apple (reusable)
        SocialLoginButton(
          icon: Icons.apple_rounded,
          label: 'Sign up with Apple',
          color: AppColors.textPrimary,
          onTap: () => _handleSocialSignup(provider, 'Apple'),
        ),
      ],
    );
  }
}

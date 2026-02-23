import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
import 'package:pos_app/screens/widgets/auth_backbtn_widget.dart';
import 'package:pos_app/screens/widgets/auth_header_widget.dart';
import 'package:pos_app/screens/widgets/auth_icon_container_widget.dart';
import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
import 'package:pos_app/screens/widgets/auth_step_indicator_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppAuthenticationProvider>().resetForgotPasswordFlow();
    });
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
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
    _animController.dispose();
    super.dispose();
  }

  // ── Step Animation Helper ─────────────────────────────────────
  void _playStepAnimation() {
    _animController.reset();
    _animController.forward();
  }

  // ── Handlers ──────────────────────────────────────────────────

  /// Validates email, checks Firestore, sends Firebase reset email,
  /// then jumps straight to the success/confirmation screen.
  Future<void> _handleSendResetEmail(AppAuthenticationProvider provider) async {
    if (!_emailFormKey.currentState!.validate()) return;

    final success = await provider.sendPasswordResetOTP(
      email: _emailController.text.trim(),
    );

    if (mounted) {
      if (success) {
        // Jump directly to success — Firebase handles reset via the email link
        provider.setForgotPasswordStep(ForgotPasswordStep.success);
        _playStepAnimation();
      } else {
        _showSnackBar(
          'This email is not registered. Please check and try again.',
          false,
        );
      }
    }
  }

  /// Resend the Firebase reset email from the success screen.
  Future<void> _handleResendEmail(AppAuthenticationProvider provider) async {
    final success = await provider.resendPasswordResetOTP(
      email: _emailController.text.trim(),
    );

    if (mounted) {
      _showSnackBar(
        success
            ? 'Reset email resent successfully!'
            : 'Failed to resend. Please try again.',
        success,
      );
    }
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
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
          child: Consumer<AppAuthenticationProvider>(
            builder: (context, provider, _) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      SizedBox(height: 24.h),

                      // ── Back Button ────────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AuthBackButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      SizedBox(height: 40.h),

                      // ── Step Indicator ─────────────────────────
                      // Only 2 visual steps: "Enter Email" and "Done"
                      AuthStepIndicator(
                        currentStep:
                            provider.forgotPasswordStep ==
                                ForgotPasswordStep.success
                            ? 1
                            : 0,
                        totalSteps: 2,
                      ),
                      SizedBox(height: 40.h),

                      // ── Animated Step Content ──────────────────
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildCurrentStep(provider),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Step Router ───────────────────────────────────────────────

  Widget _buildCurrentStep(AppAuthenticationProvider provider) {
    switch (provider.forgotPasswordStep) {
      case ForgotPasswordStep.enterEmail:
        return _buildEnterEmailStep(provider);

      // verifyOtp and resetPassword are skipped —
      // Firebase handles everything via the emailed link
      case ForgotPasswordStep.verifyOtp:
      case ForgotPasswordStep.resetPassword:
      case ForgotPasswordStep.success:
        return _buildSuccessStep(provider);
    }
  }

  // ── Step 1: Enter Email ───────────────────────────────────────

  Widget _buildEnterEmailStep(AppAuthenticationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        AuthIconContainer(
          icon: Icons.lock_reset_rounded,
          gradientColors: AppColors.primaryGradient.colors,
        ),
        SizedBox(height: 24.h),

        // Title + Subtitle
        AuthHeader(
          title: 'Forgot Password?',
          subtitle:
              'Enter your registered email address and we\'ll send you a link to reset your password.',
          showLogo: false,
        ),
        SizedBox(height: 32.h),

        // Email Field
        Form(
          key: _emailFormKey,
          child: AuthTextField(
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
        ),
        SizedBox(height: 32.h),

        // Send Reset Link Button
        AuthPrimaryButton(
          label: 'Send Reset Link',
          onTap: () => _handleSendResetEmail(provider),
          isLoading: provider.isLoading,
        ),
      ],
    );
  }

  // ── Step 2: Success / Check Email ─────────────────────────────

  Widget _buildSuccessStep(AppAuthenticationProvider provider) {
    return Column(
      children: [
        SizedBox(height: 40.h),

        // Success Icon
        AuthIconContainer(
          icon: Icons.mark_email_read_outlined,
          gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
          size: 120.w,
        ),
        SizedBox(height: 40.h),

        // Title
        Text(
          'Check Your Email!',
          textAlign: TextAlign.center,
          style: AppTheme.displayMedium.copyWith(
            fontSize: 28.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 16.h),

        // Description with email highlighted
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTheme.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15.sp,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'We\'ve sent a password reset link to\n'),
              TextSpan(
                text: _emailController.text.trim(),
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text:
                    '\n\nClick the link in the email to set your new password. '
                    'The link will expire in 1 hour.',
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Spam note
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18.w,
                color: AppColors.primaryPurple,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Didn\'t see it? Please check your spam or junk folder.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.primaryPurple,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32.h),

        // Resend Button (outlined style via TextButton)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () => _handleResendEmail(provider),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              side: BorderSide(color: AppColors.primaryPurple, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: provider.isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryPurple,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primaryPurple,
                    size: 18.w,
                  ),
            label: Text(
              'Resend Reset Link',
              style: AppTheme.labelMedium.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Back to Login Button
        AuthPrimaryButton(
          label: 'Back to Login',
          onTap: () => Navigator.pop(context),
          gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
        ),
        SizedBox(height: 80.h),
      ],
    );
  }
}


//forgotpwd issue
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:pos_app/providers/app_auth_provider.dart';
// import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
// import 'package:pos_app/screens/widgets/auth_backbtn_widget.dart';
// import 'package:pos_app/screens/widgets/auth_header_widget.dart';
// import 'package:pos_app/screens/widgets/auth_icon_container_widget.dart';
// import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
// import 'package:pos_app/screens/widgets/auth_step_indicator_widget.dart';
// import 'package:pos_app/screens/widgets/pwd_visiblity_check_widget.dart';
// import 'package:pos_app/screens/widgets/resend_otp_row_widget.dart';
// import 'package:pos_app/theme/app_colors.dart';
// import 'package:pos_app/theme/app_theme.dart';
// import 'package:provider/provider.dart';

// class ForgotPasswordScreen extends StatefulWidget {
//   const ForgotPasswordScreen({super.key});

//   @override
//   State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
// }

// class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
//     with SingleTickerProviderStateMixin {
//   // ── Controllers ───────────────────────────────────────────────
//   final _emailFormKey = GlobalKey<FormState>();
//   final _otpFormKey = GlobalKey<FormState>();
//   final _passwordFormKey = GlobalKey<FormState>();

//   final _emailController = TextEditingController();
//   final _otpController = TextEditingController();
//   final _newPasswordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();

//   // ── Animation ─────────────────────────────────────────────────
//   late AnimationController _animController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _setupAnimations();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<AppAuthenticationProvider>().resetForgotPasswordFlow();
//     });
//   }

//   void _setupAnimations() {
//     _animController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animController,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
//       ),
//     );

//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _animController,
//             curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
//           ),
//         );

//     _animController.forward();
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _otpController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     _animController.dispose();
//     super.dispose();
//   }

//   // ── Step Animation Helper ─────────────────────────────────────
//   void _playStepAnimation() {
//     _animController.reset();
//     _animController.forward();
//   }

//   // ── Handlers ──────────────────────────────────────────────────

//   Future<void> _handleSendOTP(AppAuthenticationProvider provider) async {
//     if (!_emailFormKey.currentState!.validate()) return;

//     final success = await provider.sendPasswordResetOTP(
//       email: _emailController.text.trim(),
//     );

//     if (mounted) {
//       _showSnackBar(
//         success
//             ? 'OTP sent to your email!'
//             : 'Failed to send OTP. Please try again.',
//         success,
//       );
//       if (success) {
//         provider.goToNextForgotPasswordStep();
//         _playStepAnimation();
//       }
//     }
//   }

//   Future<void> _handleVerifyOTP(AppAuthenticationProvider provider) async {
//     if (!_otpFormKey.currentState!.validate()) return;

//     final success = await provider.verifyPasswordResetOTP(
//       email: _emailController.text.trim(),
//       otp: _otpController.text.trim(),
//     );

//     if (mounted) {
//       _showSnackBar(
//         success
//             ? 'OTP verified successfully!'
//             : 'Invalid OTP. Please try again.',
//         success,
//       );
//       if (success) {
//         provider.goToNextForgotPasswordStep();
//         _playStepAnimation();
//       }
//     }
//   }

//   Future<void> _handleResetPassword(AppAuthenticationProvider provider) async {
//     if (!_passwordFormKey.currentState!.validate()) return;

//     final success = await provider.resetPassword(
//       email: _emailController.text.trim(),
//       otp: _otpController.text.trim(),
//       newPassword: _newPasswordController.text,
//     );

//     if (mounted) {
//       if (success) {
//         provider.goToNextForgotPasswordStep();
//         _playStepAnimation();
//       } else {
//         _showSnackBar('Failed to reset password. Please try again.', false);
//       }
//     }
//   }

//   Future<void> _handleResendOTP(AppAuthenticationProvider provider) async {
//     final success = await provider.resendPasswordResetOTP(
//       email: _emailController.text.trim(),
//     );

//     if (mounted) {
//       _showSnackBar(
//         success ? 'OTP resent successfully!' : 'Failed to resend OTP',
//         success,
//       );
//     }
//   }

//   void _showSnackBar(String message, bool isSuccess) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isSuccess ? AppColors.success : AppColors.error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
//       ),
//     );
//   }

//   // ── Build ─────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//       child: Scaffold(
//         backgroundColor: AppColors.lightNeutral100,
//         body: SafeArea(
//           child: Consumer<AppAuthenticationProvider>(
//             builder: (context, provider, _) {
//               return SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 24.w),
//                   child: Column(
//                     children: [
//                       SizedBox(height: 24.h),

//                       // ── Back Button (reusable) ──────────────
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: AuthBackButton(
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             Navigator.pop(context);
//                           },
//                         ),
//                       ),
//                       SizedBox(height: 40.h),

//                       // ── Step Indicator (reusable) ───────────
//                       AuthStepIndicator(
//                         currentStep: provider.forgotPasswordStep.index,
//                         totalSteps: 3, // enterEmail, verifyOtp, resetPassword
//                       ),
//                       SizedBox(height: 40.h),

//                       // ── Animated Step Content ───────────────
//                       FadeTransition(
//                         opacity: _fadeAnimation,
//                         child: SlideTransition(
//                           position: _slideAnimation,
//                           child: _buildCurrentStep(provider),
//                         ),
//                       ),
//                       SizedBox(height: 24.h),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Step Router ───────────────────────────────────────────────

//   Widget _buildCurrentStep(AppAuthenticationProvider provider) {
//     switch (provider.forgotPasswordStep) {
//       case ForgotPasswordStep.enterEmail:
//         return _buildEnterEmailStep(provider);
//       case ForgotPasswordStep.verifyOtp:
//         return _buildVerifyOtpStep(provider);
//       case ForgotPasswordStep.resetPassword:
//         return _buildResetPasswordStep(provider);
//       case ForgotPasswordStep.success:
//         return _buildSuccessStep();
//     }
//   }

//   // ── Step 1: Enter Email ───────────────────────────────────────

//   Widget _buildEnterEmailStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Icon (reusable)
//         AuthIconContainer(
//           icon: Icons.lock_reset_rounded,
//           gradientColors: AppColors.primaryGradient.colors,
//         ),
//         SizedBox(height: 24.h),

//         // Title + Subtitle (reusable)
//         AuthHeader(
//           title: 'Forgot Password?',
//           subtitle:
//               'Enter your email address and we\'ll send you a code to reset your password',
//           showLogo: false,
//         ),
//         SizedBox(height: 32.h),

//         // Email Field (reusable)
//         Form(
//           key: _emailFormKey,
//           child: AuthTextField(
//             controller: _emailController,
//             label: 'Email Address',
//             hint: 'Enter your email',
//             prefixIcon: Icons.email_outlined,
//             keyboardType: TextInputType.emailAddress,
//             validator: (value) {
//               if (value == null || value.isEmpty)
//                 return 'Please enter your email';
//               if (!value.contains('@')) return 'Please enter a valid email';
//               return null;
//             },
//           ),
//         ),
//         SizedBox(height: 32.h),

//         // Send Code Button (reusable)
//         AuthPrimaryButton(
//           label: 'Send Code',
//           onTap: () => _handleSendOTP(provider),
//           isLoading: provider.isLoading,
//         ),
//       ],
//     );
//   }

//   // ── Step 2: Verify OTP ────────────────────────────────────────

//   Widget _buildVerifyOtpStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Icon (reusable)
//         AuthIconContainer(
//           icon: Icons.mark_email_read_outlined,
//           gradientColors: AppColors.blueGradient.colors,
//         ),
//         SizedBox(height: 24.h),

//         // Title
//         Text(
//           'Verify Code',
//           style: AppTheme.displayMedium.copyWith(
//             fontSize: 28.sp,
//             fontWeight: FontWeight.w800,
//             letterSpacing: -0.5,
//           ),
//         ),
//         SizedBox(height: 8.h),

//         // Subtitle with email highlight
//         RichText(
//           text: TextSpan(
//             style: AppTheme.bodyLarge.copyWith(
//               color: AppColors.textSecondary,
//               fontSize: 15.sp,
//               height: 1.5,
//             ),
//             children: [
//               const TextSpan(text: 'We\'ve sent a verification code to\n'),
//               TextSpan(
//                 text: _emailController.text.trim(),
//                 style: TextStyle(
//                   color: AppColors.primaryPurple,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 32.h),

//         // OTP Field (reusable)
//         Form(
//           key: _otpFormKey,
//           child: AuthTextField(
//             controller: _otpController,
//             label: 'Verification Code',
//             hint: 'Enter 6-digit code',
//             prefixIcon: Icons.lock_clock_outlined,
//             keyboardType: TextInputType.number,
//             maxLength: 6,
//             validator: (value) {
//               if (value == null || value.isEmpty)
//                 return 'Please enter the code';
//               if (value.length < 4) return 'Please enter a valid code';
//               return null;
//             },
//           ),
//         ),
//         SizedBox(height: 16.h),

//         // Resend Row (reusable)
//         ResendOTPRow(onResend: () => _handleResendOTP(provider)),
//         SizedBox(height: 32.h),

//         // Verify Button (reusable)
//         AuthPrimaryButton(
//           label: 'Verify Code',
//           onTap: () => _handleVerifyOTP(provider),
//           isLoading: provider.isLoading,
//         ),
//       ],
//     );
//   }

//   // ── Step 3: Reset Password ────────────────────────────────────

//   Widget _buildResetPasswordStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Icon (reusable)
//         AuthIconContainer(
//           icon: Icons.vpn_key_rounded,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//         SizedBox(height: 24.h),

//         // Header (reusable)
//         AuthHeader(
//           title: 'Reset Password',
//           subtitle: 'Create a new strong password for your account',
//           showLogo: false,
//         ),
//         SizedBox(height: 32.h),

//         // Password Fields (reusable)
//         Form(
//           key: _passwordFormKey,
//           child: Column(
//             children: [
//               AuthTextField(
//                 controller: _newPasswordController,
//                 label: 'New Password',
//                 hint: 'Enter new password',
//                 prefixIcon: Icons.lock_outline,
//                 obscureText: !provider.isPasswordVisible,
//                 suffixIcon: PasswordVisibilityButton(
//                   isVisible: provider.isPasswordVisible,
//                   onToggle: provider.togglePasswordVisibility,
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty)
//                     return 'Please enter a password';
//                   if (value.length < 6)
//                     return 'Password must be at least 6 characters';
//                   return null;
//                 },
//               ),
//               SizedBox(height: 16.h),
//               AuthTextField(
//                 controller: _confirmPasswordController,
//                 label: 'Confirm Password',
//                 hint: 'Re-enter new password',
//                 prefixIcon: Icons.lock_outline,
//                 obscureText: !provider.isConfirmPasswordVisible,
//                 suffixIcon: PasswordVisibilityButton(
//                   isVisible: provider.isConfirmPasswordVisible,
//                   onToggle: provider.toggleConfirmPasswordVisibility,
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty)
//                     return 'Please confirm your password';
//                   if (value != _newPasswordController.text)
//                     return 'Passwords do not match';
//                   return null;
//                 },
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 32.h),

//         // Reset Button (reusable)
//         AuthPrimaryButton(
//           label: 'Reset Password',
//           onTap: () => _handleResetPassword(provider),
//           isLoading: provider.isLoading,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//       ],
//     );
//   }

//   // ── Step 4: Success ───────────────────────────────────────────

//   Widget _buildSuccessStep() {
//     return Column(
//       children: [
//         SizedBox(height: 40.h),

//         // Success Icon (reusable, larger size)
//         AuthIconContainer(
//           icon: Icons.check_circle_outline_rounded,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//           size: 120.w,
//         ),
//         SizedBox(height: 40.h),

//         // Title
//         Text(
//           'Password Reset\nSuccessful!',
//           textAlign: TextAlign.center,
//           style: AppTheme.displayMedium.copyWith(
//             fontSize: 28.sp,
//             fontWeight: FontWeight.w800,
//             letterSpacing: -0.5,
//             height: 1.2,
//           ),
//         ),
//         SizedBox(height: 16.h),

//         // Description
//         Text(
//           'Your password has been reset successfully.\nYou can now login with your new password.',
//           textAlign: TextAlign.center,
//           style: AppTheme.bodyLarge.copyWith(
//             color: AppColors.textSecondary,
//             fontSize: 15.sp,
//             height: 1.6,
//           ),
//         ),
//         SizedBox(height: 48.h),

//         // Back to Login Button (reusable)
//         AuthPrimaryButton(
//           label: 'Back to Login',
//           onTap: () => Navigator.pop(context),
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//         SizedBox(height: 80.h),
//       ],
//     );
//   }
// }





// /*import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:pos_app/providers/auth_provider.dart';
// import 'package:pos_app/screens/widgets/AuthTextField_widgets.dart';
// import 'package:pos_app/screens/widgets/auth_backbtn_widget.dart';
// import 'package:pos_app/screens/widgets/auth_header_widget.dart';
// import 'package:pos_app/screens/widgets/auth_icon_container_widget.dart';
// import 'package:pos_app/screens/widgets/auth_primary_button_widget.dart';
// import 'package:pos_app/screens/widgets/auth_step_indicator_widget.dart';
// import 'package:pos_app/screens/widgets/pwd_visiblity_check_widget.dart';
// import 'package:pos_app/screens/widgets/resend_otp_row_widget.dart';
// import 'package:pos_app/theme/app_colors.dart';
// import 'package:pos_app/theme/app_theme.dart';
// import 'package:provider/provider.dart';

// class ForgotPasswordScreen extends StatefulWidget {
//   const ForgotPasswordScreen({super.key});

//   @override
//   State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
// }

// class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
//     with SingleTickerProviderStateMixin {
//   // ── Controllers ───────────────────────────────────────────────
//   final _emailFormKey = GlobalKey<FormState>();
//   final _otpFormKey = GlobalKey<FormState>();
//   final _passwordFormKey = GlobalKey<FormState>();

//   final _emailController = TextEditingController();
//   final _otpController = TextEditingController();
//   final _newPasswordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();

//   // ── Animation ─────────────────────────────────────────────────
//   late AnimationController _animController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _setupAnimations();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<AppAuthenticationProvider>().resetForgotPasswordFlow();
//     });
//   }

//   void _setupAnimations() {
//     _animController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animController,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
//       ),
//     );

//     _slideAnimation =
//         Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
//           CurvedAnimation(
//             parent: _animController,
//             curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
//           ),
//         );

//     _animController.forward();
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _otpController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     _animController.dispose();
//     super.dispose();
//   }

//   // ── Step Animation Helper ─────────────────────────────────────
//   void _playStepAnimation() {
//     _animController.reset();
//     _animController.forward();
//   }

//   // ── Helpers ───────────────────────────────────────────────────
//   void _showSnackBar(String message, bool isSuccess) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isSuccess ? AppColors.success : AppColors.error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8.r),
//         ),
//       ),
//     );
//   }

//   // ── Handlers ──────────────────────────────────────────────────

//   /// Step 1 — Send reset email
//   Future<void> _handleSendOTP(AppAuthenticationProvider provider) async {
//     if (!_emailFormKey.currentState!.validate()) return;

//     final result = await provider.sendPasswordResetOTP(
//       email: _emailController.text.trim(),
//     );

//     if (!mounted) return;

//     if (result.success) {
//       _showSnackBar('Reset code sent to your email!', true);
//       provider.goToNextForgotPasswordStep();
//       _playStepAnimation();
//     } else {
//       _showSnackBar(
//           result.error ?? 'Failed to send reset email. Please try again.',
//           false);
//     }
//   }

//   /// Step 2 — Verify OTP / action code from email
//   Future<void> _handleVerifyOTP(AppAuthenticationProvider provider) async {
//     if (!_otpFormKey.currentState!.validate()) return;

//     final result = await provider.verifyPasswordResetOTP(
//       email: _emailController.text.trim(),
//       otp: _otpController.text.trim(),
//     );

//     if (!mounted) return;

//     if (result.success) {
//       _showSnackBar('Code verified successfully!', true);
//       provider.goToNextForgotPasswordStep();
//       _playStepAnimation();
//     } else {
//       _showSnackBar(
//           result.error ?? 'Invalid code. Please try again.', false);
//     }
//   }

//   /// Step 3 — Confirm new password
//   Future<void> _handleResetPassword(AppAuthenticationProvider provider) async {
//     if (!_passwordFormKey.currentState!.validate()) return;

//     final result = await provider.resetPassword(
//       email: _emailController.text.trim(),
//       otp: _otpController.text.trim(),
//       newPassword: _newPasswordController.text,
//     );

//     if (!mounted) return;

//     if (result.success) {
//       provider.goToNextForgotPasswordStep();
//       _playStepAnimation();
//     } else {
//       _showSnackBar(
//           result.error ?? 'Failed to reset password. Please try again.',
//           false);
//     }
//   }

//   /// Resend reset email
//   Future<void> _handleResendOTP(AppAuthenticationProvider provider) async {
//     final result = await provider.resendPasswordResetOTP(
//       email: _emailController.text.trim(),
//     );

//     if (!mounted) return;

//     _showSnackBar(
//       result.success
//           ? 'Reset email resent successfully!'
//           : result.error ?? 'Failed to resend. Please try again.',
//       result.success,
//     );
//   }

//   // ── Build ─────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//       child: Scaffold(
//         backgroundColor: AppColors.lightNeutral100,
//         body: SafeArea(
//           child: Consumer<AppAuthenticationProvider>(
//             builder: (context, provider, _) {
//               return SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 24.w),
//                   child: Column(
//                     children: [
//                       SizedBox(height: 24.h),

//                       // ── Back Button ──────────────────────────
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: AuthBackButton(
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             Navigator.pop(context);
//                           },
//                         ),
//                       ),
//                       SizedBox(height: 40.h),

//                       // ── Step Indicator ───────────────────────
//                       AuthStepIndicator(
//                         currentStep: provider.forgotPasswordStep.index,
//                         totalSteps: 3,
//                       ),
//                       SizedBox(height: 40.h),

//                       // ── Animated Step Content ────────────────
//                       FadeTransition(
//                         opacity: _fadeAnimation,
//                         child: SlideTransition(
//                           position: _slideAnimation,
//                           child: _buildCurrentStep(provider),
//                         ),
//                       ),
//                       SizedBox(height: 24.h),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Step Router ───────────────────────────────────────────────

//   Widget _buildCurrentStep(AppAuthenticationProvider provider) {
//     switch (provider.forgotPasswordStep) {
//       case ForgotPasswordStep.enterEmail:
//         return _buildEnterEmailStep(provider);
//       case ForgotPasswordStep.verifyOtp:
//         return _buildVerifyOtpStep(provider);
//       case ForgotPasswordStep.resetPassword:
//         return _buildResetPasswordStep(provider);
//       case ForgotPasswordStep.success:
//         return _buildSuccessStep();
//     }
//   }

//   // ── Step 1: Enter Email ───────────────────────────────────────

//   Widget _buildEnterEmailStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         AuthIconContainer(
//           icon: Icons.lock_reset_rounded,
//           gradientColors: AppColors.primaryGradient.colors,
//         ),
//         SizedBox(height: 24.h),
//         const AuthHeader(
//           title: 'Forgot Password?',
//           subtitle:
//               'Enter your email address and we\'ll send you a code to reset your password',
//           showLogo: false,
//         ),
//         SizedBox(height: 32.h),
//         Form(
//           key: _emailFormKey,
//           child: AuthTextField(
//             controller: _emailController,
//             label: 'Email Address',
//             hint: 'Enter your email',
//             prefixIcon: Icons.email_outlined,
//             keyboardType: TextInputType.emailAddress,
//             validator: (value) {
//               if (value == null || value.isEmpty)
//                 return 'Please enter your email';
//               if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
//                 return 'Please enter a valid email';
//               return null;
//             },
//           ),
//         ),
//         SizedBox(height: 32.h),

//         // ── Firebase Note ─────────────────────────────────────
//         Container(
//           padding: EdgeInsets.all(12.w),
//           decoration: BoxDecoration(
//             color: AppColors.primaryPurple.withOpacity(0.08),
//             borderRadius: BorderRadius.circular(10.r),
//             border: Border.all(
//               color: AppColors.primaryPurple.withOpacity(0.2),
//             ),
//           ),
//           child: Row(
//             children: [
//               Icon(
//                 Icons.info_outline_rounded,
//                 size: 16.sp,
//                 color: AppColors.primaryPurple,
//               ),
//               SizedBox(width: 8.w),
//               Expanded(
//                 child: Text(
//                   'A password reset link will be sent to your email. Open the link and copy the code here.',
//                   style: AppTheme.bodySmall.copyWith(
//                     color: AppColors.primaryPurple,
//                     fontSize: 11.sp,
//                     height: 1.5,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 24.h),

//         AuthPrimaryButton(
//           label: 'Send Code',
//           onTap: () => _handleSendOTP(provider),
//           isLoading: provider.isLoading,
//         ),
//       ],
//     );
//   }

//   // ── Step 2: Verify OTP ────────────────────────────────────────

//   Widget _buildVerifyOtpStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         AuthIconContainer(
//           icon: Icons.mark_email_read_outlined,
//           gradientColors: AppColors.blueGradient.colors,
//         ),
//         SizedBox(height: 24.h),
//         Text(
//           'Verify Code',
//           style: AppTheme.displayMedium.copyWith(
//             fontSize: 28.sp,
//             fontWeight: FontWeight.w800,
//             letterSpacing: -0.5,
//           ),
//         ),
//         SizedBox(height: 8.h),
//         RichText(
//           text: TextSpan(
//             style: AppTheme.bodyLarge.copyWith(
//               color: AppColors.textSecondary,
//               fontSize: 15.sp,
//               height: 1.5,
//             ),
//             children: [
//               const TextSpan(
//                   text: 'We\'ve sent a verification link to\n'),
//               TextSpan(
//                 text: _emailController.text.trim(),
//                 style: TextStyle(
//                   color: AppColors.primaryPurple,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const TextSpan(
//                   text:
//                       '\n\nOpen the email, copy the action code from the reset link and paste it below.'),
//             ],
//           ),
//         ),
//         SizedBox(height: 32.h),
//         Form(
//           key: _otpFormKey,
//           child: AuthTextField(
//             controller: _otpController,
//             label: 'Reset Code',
//             hint: 'Paste the code from your email',
//             prefixIcon: Icons.lock_clock_outlined,
//             keyboardType: TextInputType.text,
//             validator: (value) {
//               if (value == null || value.isEmpty)
//                 return 'Please enter the code';
//               if (value.length < 4) return 'Please enter a valid code';
//               return null;
//             },
//           ),
//         ),
//         SizedBox(height: 16.h),
//         ResendOTPRow(onResend: () => _handleResendOTP(provider)),
//         SizedBox(height: 32.h),
//         AuthPrimaryButton(
//           label: 'Verify Code',
//           onTap: () => _handleVerifyOTP(provider),
//           isLoading: provider.isLoading,
//         ),
//       ],
//     );
//   }

//   // ── Step 3: Reset Password ────────────────────────────────────

//   Widget _buildResetPasswordStep(AppAuthenticationProvider provider) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         AuthIconContainer(
//           icon: Icons.vpn_key_rounded,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//         SizedBox(height: 24.h),
//         const AuthHeader(
//           title: 'Reset Password',
//           subtitle: 'Create a new strong password for your account',
//           showLogo: false,
//         ),
//         SizedBox(height: 32.h),
//         Form(
//           key: _passwordFormKey,
//           child: Column(
//             children: [
//               AuthTextField(
//                 controller: _newPasswordController,
//                 label: 'New Password',
//                 hint: 'Enter new password',
//                 prefixIcon: Icons.lock_outline,
//                 obscureText: !provider.isPasswordVisible,
//                 suffixIcon: PasswordVisibilityButton(
//                   isVisible: provider.isPasswordVisible,
//                   onToggle: provider.togglePasswordVisibility,
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty)
//                     return 'Please enter a password';
//                   if (value.length < 6)
//                     return 'Password must be at least 6 characters';
//                   return null;
//                 },
//               ),
//               SizedBox(height: 16.h),
//               AuthTextField(
//                 controller: _confirmPasswordController,
//                 label: 'Confirm Password',
//                 hint: 'Re-enter new password',
//                 prefixIcon: Icons.lock_outline,
//                 obscureText: !provider.isConfirmPasswordVisible,
//                 suffixIcon: PasswordVisibilityButton(
//                   isVisible: provider.isConfirmPasswordVisible,
//                   onToggle: provider.toggleConfirmPasswordVisibility,
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty)
//                     return 'Please confirm your password';
//                   if (value != _newPasswordController.text)
//                     return 'Passwords do not match';
//                   return null;
//                 },
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 32.h),
//         AuthPrimaryButton(
//           label: 'Reset Password',
//           onTap: () => _handleResetPassword(provider),
//           isLoading: provider.isLoading,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//       ],
//     );
//   }

//   // ── Step 4: Success ───────────────────────────────────────────

//   Widget _buildSuccessStep() {
//     return Column(
//       children: [
//         SizedBox(height: 40.h),
//         AuthIconContainer(
//           icon: Icons.check_circle_outline_rounded,
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//           size: 120.w,
//         ),
//         SizedBox(height: 40.h),
//         Text(
//           'Password Reset\nSuccessful!',
//           textAlign: TextAlign.center,
//           style: AppTheme.displayMedium.copyWith(
//             fontSize: 28.sp,
//             fontWeight: FontWeight.w800,
//             letterSpacing: -0.5,
//             height: 1.2,
//           ),
//         ),
//         SizedBox(height: 16.h),
//         Text(
//           'Your password has been reset successfully.\nYou can now login with your new password.',
//           textAlign: TextAlign.center,
//           style: AppTheme.bodyLarge.copyWith(
//             color: AppColors.textSecondary,
//             fontSize: 15.sp,
//             height: 1.6,
//           ),
//         ),
//         SizedBox(height: 48.h),
//         AuthPrimaryButton(
//           label: 'Back to Login',
//           onTap: () => Navigator.pop(context),
//           gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
//         ),
//         SizedBox(height: 80.h),
//       ],
//     );
//   }
// } */
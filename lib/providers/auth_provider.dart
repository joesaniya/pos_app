import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AuthMode { login, signup }

enum LoginMethod { emailPassword, phoneOtp }

enum ForgotPasswordStep { enterEmail, verifyOtp, resetPassword, success }

class AuthProvider with ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────
  AuthMode _authMode = AuthMode.login;
  LoginMethod _loginMethod = LoginMethod.emailPassword;
  ForgotPasswordStep _forgotPasswordStep = ForgotPasswordStep.enterEmail;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _otpSent = false;
  bool _agreedToTerms = false;
  String _resetEmail = '';

  // ── Getters ───────────────────────────────────────────────────
  AuthMode get authMode => _authMode;
  LoginMethod get loginMethod => _loginMethod;
  ForgotPasswordStep get forgotPasswordStep => _forgotPasswordStep;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmPasswordVisible => _isConfirmPasswordVisible;
  bool get isNewPasswordVisible => _isNewPasswordVisible;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  bool get otpSent => _otpSent;
  bool get agreedToTerms => _agreedToTerms;
  String get resetEmail => _resetEmail;

  bool get isLoginMode => _authMode == AuthMode.login;
  bool get isSignupMode => _authMode == AuthMode.signup;
  bool get isEmailPasswordMethod => _loginMethod == LoginMethod.emailPassword;
  bool get isPhoneOtpMethod => _loginMethod == LoginMethod.phoneOtp;

  // ── Auth Mode Control ─────────────────────────────────────────
  void switchToLogin() {
    if (_authMode == AuthMode.login) return;
    _authMode = AuthMode.login;
    _resetFormState();
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void switchToSignup() {
    if (_authMode == AuthMode.signup) return;
    _authMode = AuthMode.signup;
    _resetFormState();
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Login Method Control ──────────────────────────────────────
  void switchToEmailPassword() {
    if (_loginMethod == LoginMethod.emailPassword) return;
    _loginMethod = LoginMethod.emailPassword;
    _otpSent = false;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void switchToPhoneOtp() {
    if (_loginMethod == LoginMethod.phoneOtp) return;
    _loginMethod = LoginMethod.phoneOtp;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Visibility Toggles ────────────────────────────────────────
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void toggleNewPasswordVisibility() {
    _isNewPasswordVisible = !_isNewPasswordVisible;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Checkbox Toggles ──────────────────────────────────────────
  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Loading State ─────────────────────────────────────────────
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ── OTP State ─────────────────────────────────────────────────
  void setOtpSent(bool value) {
    _otpSent = value;
    notifyListeners();
  }

  // ── Forgot Password Step Control ──────────────────────────────
  void setForgotPasswordStep(ForgotPasswordStep step) {
    _forgotPasswordStep = step;
    notifyListeners();
  }

  void setResetEmail(String email) {
    _resetEmail = email;
  }

  void goToNextForgotPasswordStep() {
    switch (_forgotPasswordStep) {
      case ForgotPasswordStep.enterEmail:
        _forgotPasswordStep = ForgotPasswordStep.verifyOtp;
        break;
      case ForgotPasswordStep.verifyOtp:
        _forgotPasswordStep = ForgotPasswordStep.resetPassword;
        break;
      case ForgotPasswordStep.resetPassword:
        _forgotPasswordStep = ForgotPasswordStep.success;
        break;
      case ForgotPasswordStep.success:
        break;
    }
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void resetForgotPasswordFlow() {
    _forgotPasswordStep = ForgotPasswordStep.enterEmail;
    _resetEmail = '';
    _otpSent = false;
    notifyListeners();
  }

  // ── API Calls ─────────────────────────────────────────────────
  
  /// Login with email and password
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      setOtpSent(true);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Verify OTP
  Future<bool> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.lightImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signupWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    if (!_agreedToTerms) {
      return false;
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Sign up with phone and OTP
  Future<bool> signupWithPhone({
    required String name,
    required String phone,
    required String otp,
  }) async {
    if (!_agreedToTerms) {
      return false;
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Social login (Google, Apple, etc.)
  Future<bool> socialLogin({required String provider}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  // ── Forgot Password API Calls ─────────────────────────────────

  /// Send OTP for password reset
  Future<bool> sendPasswordResetOTP({required String email}) async {
    setLoading(true);
    setResetEmail(email);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      setOtpSent(true);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Verify OTP for password reset
  Future<bool> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Reset password with new password
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  /// Resend password reset OTP
  Future<bool> resendPasswordResetOTP({required String email}) async {
    setLoading(true);
    HapticFeedback.lightImpact();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2));
      
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  // ── Reset State ───────────────────────────────────────────────
  void _resetFormState() {
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    _isNewPasswordVisible = false;
    _otpSent = false;
    _agreedToTerms = false;
    // Don't reset rememberMe as it's user preference
  }

  void resetAll() {
    _authMode = AuthMode.login;
    _loginMethod = LoginMethod.emailPassword;
    _forgotPasswordStep = ForgotPasswordStep.enterEmail;
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    _isNewPasswordVisible = false;
    _isLoading = false;
    _rememberMe = false;
    _otpSent = false;
    _agreedToTerms = false;
    _resetEmail = '';
    notifyListeners();
  }
}
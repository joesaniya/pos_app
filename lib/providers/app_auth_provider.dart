import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/services/storage_service.dart';

enum AuthMode { login, signup }

enum LoginMethod { emailPassword, phoneOtp }

enum ForgotPasswordStep { enterEmail, verifyOtp, resetPassword, success }

class AppAuthenticationProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storage = StorageService.instance;

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

  // Stored user data after login
  Map<String, dynamic> _userData = {};

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
  Map<String, dynamic> get userData => _userData;

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

  /// Login with email and password — validates against Firestore users collection
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Sign in with Firebase Auth
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        setLoading(false);
        return false;
      }

      // 2. Fetch user document from Firestore
      final docSnapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!docSnapshot.exists) {
        // User not found in Firestore — reject login
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final data = docSnapshot.data()!;

      // 3. Check isActive flag
      if (data['isActive'] != true) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      // 4. Get fresh ID token
      final String token = await firebaseUser.getIdToken() ?? '';

      log(
        'Login successful for token $token  ==>  ${data['email']} (UID: ${firebaseUser.uid})',
      );
      await _storage.saveUserData(
        uid: data['uid'] ?? firebaseUser.uid,
        token: token,
        name: data['name'] ?? '',
        email: data['email'] ?? email,
        phone: data['phone'] ?? '',
        role: data['role'] ?? '',
        businessId: data['businessId'] ?? '',
        businessName: data['businessName'] ?? '',
        profilePhoto: data['profilePhoto'],
        isActive: data['isActive'] ?? true,
      );

      // 6. Cache locally
      _userData = {
        'uid': data['uid'] ?? firebaseUser.uid,
        'name': data['name'] ?? '',
        'email': data['email'] ?? email,
        'phone': data['phone'] ?? '',
        'role': data['role'] ?? '',
        'businessId': data['businessId'] ?? '',
        'businessName': data['businessName'] ?? '',
        'profilePhoto': data['profilePhoto'] ?? '',
        'isActive': data['isActive'] ?? true,
      };

      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('loginWithEmail error: $e');
      setLoading(false);
      return false;
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual Firebase Phone Auth
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
  Future<bool> verifyOTP({required String phone, required String otp}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Replace with actual Firebase Phone Auth verification
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
    if (!_agreedToTerms) return false;

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
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
    if (!_agreedToTerms) return false;

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
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
      // TODO: Replace with actual social login
      await Future.delayed(const Duration(seconds: 2));

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  // ── Forgot Password API Calls ─────────────────────────────────

  Future<bool> sendPasswordResetOTP({required String email}) async {
    setLoading(true);
    setResetEmail(email);
    HapticFeedback.mediumImpact();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setLoading(false);
      setOtpSent(true);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  Future<bool> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      await Future.delayed(const Duration(seconds: 2));

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      await Future.delayed(const Duration(seconds: 2));

      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  Future<bool> resendPasswordResetOTP({required String email}) async {
    setLoading(true);
    HapticFeedback.lightImpact();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setLoading(false);
      return true;
    } catch (e) {
      setLoading(false);
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    await _storage.clearUserData();
    _userData = {};
    resetAll();
  }

  // ── Reset State ───────────────────────────────────────────────
  void _resetFormState() {
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    _isNewPasswordVisible = false;
    _otpSent = false;
    _agreedToTerms = false;
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

/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthMode { login, signup }

enum LoginMethod { emailPassword, phoneOtp }

enum ForgotPasswordStep { enterEmail, verifyOtp, resetPassword, success }

class AppAuthenticationProvider with ChangeNotifier {
  // ── Firebase Instances ────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Use classic GoogleSignIn() constructor (google_sign_in: ^6.2.1)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  // ── Phone Auth State ──────────────────────────────────────────
  String? _verificationId;
  int? _resendToken;

  // ── Error Handling ────────────────────────────────────────────
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
  User? get currentUser => _auth.currentUser;

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
    _verificationId = null;
    notifyListeners();
  }

  // ── Helper: Map Firebase Error Codes ─────────────────────────
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'session-expired':
        return 'OTP has expired. Please request a new one.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // ── API Calls ─────────────────────────────────────────────────

  /// Login with email and password
  Future<({bool success, String? error})> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      setLoading(false);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'An unexpected error occurred.');
    }
  }

  /// Send OTP to phone number
  Future<({bool success, String? error})> sendOTP({
    required String phone,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    final formattedPhone =
        phone.startsWith('+') ? phone : '+91$phone';

    try {
      final completer = _AsyncCompleter<({bool success, String? error})>();

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            setLoading(false);
            setOtpSent(true);
            if (!completer.isCompleted) {
              completer.complete((success: true, error: null));
            }
          } catch (e) {
            setLoading(false);
            if (!completer.isCompleted) {
              completer.complete(
                  (success: false, error: 'Auto-verification failed.'));
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setLoading(false);
          if (!completer.isCompleted) {
            completer.complete(
                (success: false, error: _mapFirebaseError(e)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          setLoading(false);
          setOtpSent(true);
          if (!completer.isCompleted) {
            completer.complete((success: true, error: null));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete((success: false, error: 'OTP timed out.'));
          }
        },
        timeout: const Duration(seconds: 60),
      );

      return await completer.future;
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'Failed to send OTP.');
    }
  }

  /// Verify OTP for phone login
  Future<({bool success, String? error})> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    if (_verificationId == null) {
      return (
        success: false,
        error: 'Session expired. Please request a new OTP.'
      );
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final credential = PhoneAppAuthenticationProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      setLoading(false);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'Verification failed.');
    }
  }

  /// Resend OTP
  Future<({bool success, String? error})> resendOTP({
    required String phone,
  }) async {
    return sendOTP(phone: phone);
  }

  /// Sign up with email and password
  Future<({bool success, String? error})> signupWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    if (!_agreedToTerms) {
      return (
        success: false,
        error: 'Please agree to the Terms & Conditions.'
      );
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.sendEmailVerification();

      setLoading(false);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'Sign up failed. Please try again.');
    }
  }

  /// Sign up with phone and OTP
  Future<({bool success, String? error})> signupWithPhone({
    required String name,
    required String phone,
    required String otp,
  }) async {
    if (!_agreedToTerms) {
      return (
        success: false,
        error: 'Please agree to the Terms & Conditions.'
      );
    }
    return verifyOTP(phone: phone, otp: otp);
  }

  /// Google Sign In
  /// Google Sign In (requires google_sign_in: ^6.2.1 in pubspec.yaml)
  Future<({bool success, String? error})> socialLogin({
    required String provider,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      if (provider == 'Google') {
        // Classic v6 API — signIn() returns GoogleSignInAccount?
        final GoogleSignInAccount? googleUser =
            await _googleSignIn.signIn();

        if (googleUser == null) {
          // User cancelled the sign-in dialog
          setLoading(false);
          return (success: false, error: 'Google sign in was cancelled.');
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Both accessToken and idToken available in v6
        final credential = GoogleAppAuthenticationProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
        setLoading(false);
        return (success: true, error: null);
      } else if (provider == 'Apple') {
        setLoading(false);
        return (
          success: false,
          error: 'Apple Sign In not yet configured.'
        );
      }

      setLoading(false);
      return (success: false, error: 'Unknown provider.');
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (
        success: false,
        error: '$provider sign in failed: ${e.toString()}'
      );
    }
  }

  // ── Forgot Password API Calls ─────────────────────────────────

  /// Step 1 — Send password reset email
  // FIX 4: Removed fetchSignInMethodsForEmail (deprecated & removed in new SDK)
  Future<({bool success, String? error})> sendPasswordResetOTP({
    required String email,
  }) async {
    setLoading(true);
    setResetEmail(email);
    HapticFeedback.mediumImpact();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setLoading(false);
      setOtpSent(true);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'Failed to send reset email.');
    }
  }

  /// Step 2 — Verify action code from reset email
  Future<({bool success, String? error})> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      await _auth.verifyPasswordResetCode(otp);
      setLoading(false);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (
        success: false,
        error: 'Invalid code. Please check your email and try again.'
      );
    }
  }

  /// Step 3 — Confirm new password
  Future<({bool success, String? error})> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      await _auth.confirmPasswordReset(code: otp, newPassword: newPassword);
      setLoading(false);
      return (success: true, error: null);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      return (success: false, error: _mapFirebaseError(e));
    } catch (e) {
      setLoading(false);
      return (success: false, error: 'Failed to reset password.');
    }
  }

  /// Resend password reset email
  Future<({bool success, String? error})> resendPasswordResetOTP({
    required String email,
  }) async {
    return sendPasswordResetOTP(email: email);
  }

  // ── Sign Out ──────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    resetAll();
  }

  // ── Reset State ───────────────────────────────────────────────
  void _resetFormState() {
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    _isNewPasswordVisible = false;
    _otpSent = false;
    _agreedToTerms = false;
    _verificationId = null;
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
    _verificationId = null;
    _resendToken = null;
    _errorMessage = null;
    notifyListeners();
  }
}

// ── Async Completer Helper ────────────────────────────────────────────────────
class _AsyncCompleter<T> {
  final _completer = Completer<T>();
  bool _completed = false;

  bool get isCompleted => _completed;
  Future<T> get future => _completer.future;

  void complete(T value) {
    if (!_completed) {
      _completed = true;
      _completer.complete(value);
    }
  }
}
 */

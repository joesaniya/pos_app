import 'dart:async';
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

  // Firebase Phone Auth
  String? _verificationId;
  int? _resendToken;

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
    _verificationId = null;
    _resendToken = null;
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
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user;
      if (firebaseUser == null) {
        setLoading(false);
        return false;
      }

      final docSnapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!docSnapshot.exists) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final data = docSnapshot.data()!;

      if (data['isActive'] != true) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

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

  Future<String> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';

      // Firestore check (unchanged)...
      final QuerySnapshot snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      QuerySnapshot snap2 = snap;
      if (snap.docs.isEmpty) {
        snap2 = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalised)
            .limit(1)
            .get();
      }

      final QuerySnapshot result = snap.docs.isNotEmpty ? snap : snap2;

      if (result.docs.isEmpty) {
        setLoading(false);
        return 'not_found';
      }

      final data = result.docs.first.data() as Map<String, dynamic>;
      if (data['isActive'] != true) {
        setLoading(false);
        return 'inactive';
      }

      // ✅ Use a Completer to properly await the async callback
      final completer = Completer<String>();

      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          log('Auto-verification completed');
          if (!completer.isCompleted) completer.complete('success');
        },
        verificationFailed: (FirebaseAuthException e) {
          log('OTP send failed: ${e.code} — ${e.message}');
          if (!completer.isCompleted) completer.complete('error');
        },
        codeSent: (String verificationId, int? resendToken) {
          log('OTP sent. verificationId: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) completer.complete('success');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete('timeout');
        },
      );

      final result2 = await completer.future;

      setLoading(false);
      if (result2 == 'success') {
        setOtpSent(true);
      }
      return result2;
    } catch (e) {
      debugPrint('sendOTP error: $e');
      setLoading(false);
      return 'error';
    }
  }

  Future<String> sendOTP1({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      // ── 1. Normalise phone (add country code if missing) ──────
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';

      // ── 2. Check Firestore: phone field must exist & isActive ─
      final QuerySnapshot snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone) // stored without country code
          .limit(1)
          .get();

      // Also try with country code in case stored differently
      QuerySnapshot snap2 = snap;
      if (snap.docs.isEmpty) {
        snap2 = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalised)
            .limit(1)
            .get();
      }

      final QuerySnapshot result = snap.docs.isNotEmpty ? snap : snap2;

      if (result.docs.isEmpty) {
        setLoading(false);
        return 'not_found';
      }

      final data = result.docs.first.data() as Map<String, dynamic>;

      if (data['isActive'] != true) {
        setLoading(false);
        return 'inactive';
      }

      // ── 3. Send Firebase Phone OTP ────────────────────────────
      bool completed = false;

      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),

        // Auto-retrieval (Android SMS hash) — sign in immediately
        verificationCompleted: (PhoneAuthCredential credential) async {
          log('Auto-verification completed');
          // Store credential for later use if needed
        },

        verificationFailed: (FirebaseAuthException e) {
          log('OTP send failed: ${e.code} — ${e.message}');
          completed = true;
        },

        codeSent: (String verificationId, int? resendToken) {
          log('OTP sent. verificationId: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          completed = true;
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      // verifyPhoneNumber is async-internally; codeSent fires on the same call
      setLoading(false);
      setOtpSent(true);
      return 'success';
    } catch (e) {
      debugPrint('sendOTP error: $e');
      setLoading(false);
      return 'error';
    }
  }

  /// Step 2: Verify OTP entered by user — sign in via Firebase Phone Auth
  ///
  /// Returns:
  ///   true  — OTP correct, user signed in
  ///   false — wrong OTP or expired
  Future<bool> verifyOTP({required String phone, required String otp}) async {
    if (_verificationId == null) {
      debugPrint('verificationId is null — OTP was never sent');
      return false;
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        setLoading(false);
        return false;
      }

      // ── Fetch Firestore user data ─────────────────────────────
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';

      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalised)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;
      final String token = await firebaseUser.getIdToken() ?? '';

      await _storage.saveUserData(
        uid: data['uid'] ?? firebaseUser.uid,
        token: token,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? phone,
        role: data['role'] ?? '',
        businessId: data['businessId'] ?? '',
        businessName: data['businessName'] ?? '',
        profilePhoto: data['profilePhoto'],
        isActive: data['isActive'] ?? true,
      );

      _userData = {
        'uid': data['uid'] ?? firebaseUser.uid,
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? phone,
        'role': data['role'] ?? '',
        'businessId': data['businessId'] ?? '',
        'businessName': data['businessName'] ?? '',
        'profilePhoto': data['profilePhoto'] ?? '',
        'isActive': data['isActive'] ?? true,
      };

      log('Phone login successful for ${data['phone']}');

      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('verifyOTP FirebaseAuthException: ${e.code} — ${e.message}');
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('verifyOTP error: $e');
      setLoading(false);
      return false;
    }
  }

  /// Resend OTP to same phone
  Future<String> resendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.lightImpact();

    try {
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';

      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken, // required for resend
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint('Resend failed: ${e.code}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          log('OTP resent. verificationId: $verificationId');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      setLoading(false);
      return 'success';
    } catch (e) {
      debugPrint('resendOTP error: $e');
      setLoading(false);
      return 'error';
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
    _verificationId = null;
    _resendToken = null;
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
    notifyListeners();
  }
}

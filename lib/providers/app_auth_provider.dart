import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pos_app/services/storage_service.dart';

enum AuthMode { login, signup }

enum LoginMethod { emailPassword, phoneOtp }

enum ForgotPasswordStep { enterEmail, verifyOtp, resetPassword, success }

enum LoginResult {
  success,
  emailNotFound,
  wrongPassword,
  invalidCredentials,
  inactive,
  error,
}

// ── Remember Me credentials returned to the UI ───────────────
class RememberedCredentials {
  final String method; // 'email' | 'phone'
  final String email;
  final String password;
  final String phone;

  const RememberedCredentials._({
    required this.method,
    this.email = '',
    this.password = '',
    this.phone = '',
  });

  factory RememberedCredentials.email(String email, String password) =>
      RememberedCredentials._(
        method: 'email',
        email: email,
        password: password,
      );

  factory RememberedCredentials.phone(String phone) =>
      RememberedCredentials._(method: 'phone', phone: phone);

  bool get isEmailMethod => method == 'email';
  bool get isPhoneMethod => method == 'phone';
}

class AppAuthenticationProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storage = StorageService.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Active session watcher ────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _sessionWatcher;

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

  // ── Remember Me state ─────────────────────────────────────────
  /// Set to true once we've attempted to load remembered credentials
  /// on first build — prevents repeated async calls.
  bool _rememberedCredentialsLoaded = false;
  RememberedCredentials? _rememberedCredentials;

  // ── Deactivation flag ─────────────────────────────────────────
  bool _wasDeactivated = false;
  bool get wasDeactivated => _wasDeactivated;

  String? _verificationId;
  int? _resendToken;
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

  /// Non-null when valid remembered credentials exist.
  RememberedCredentials? get rememberedCredentials => _rememberedCredentials;
  bool get hasRememberedCredentials => _rememberedCredentials != null;

  // ═══════════════════════════════════════════════════════════
  // REMEMBER ME — PUBLIC API
  // ═══════════════════════════════════════════════════════════

  /// Call once from [LoginScreen.initState] to load any saved creds.
  /// Populates [rememberedCredentials] and switches to the correct
  /// login method tab automatically.
  Future<void> loadRememberedCredentials() async {
    if (_rememberedCredentialsLoaded) return;
    _rememberedCredentialsLoaded = true;

    final raw = await _storage.getRememberedCredentials();
    if (raw == null) return;

    if (raw['method'] == 'email') {
      _rememberedCredentials = RememberedCredentials.email(
        raw['email'] ?? '',
        raw['password'] ?? '',
      );
      _loginMethod = LoginMethod.emailPassword;
      _rememberMe = true;
    } else if (raw['method'] == 'phone') {
      _rememberedCredentials = RememberedCredentials.phone(raw['phone'] ?? '');
      _loginMethod = LoginMethod.phoneOtp;
      _rememberMe = true;
    }

    notifyListeners();
  }

  /// Clears remembered credentials without logging out the current session.
  /// Called when the user unchecks "Remember Me" while already logged in.
  Future<void> clearRememberedCredentials() async {
    _rememberedCredentials = null;
    await _storage.clearRememberedCredentials();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION VALIDATION
  // ═══════════════════════════════════════════════════════════
  Future<bool> validateSession() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await _storage.clearUserData();
      return false;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) {
        await _forceLogout();
        return false;
      }

      final data = doc.data()!;

      if (data['isActive'] != true) {
        _wasDeactivated = true;
        await _forceLogout();
        return false;
      }

      if (data['isDeleted'] == true) {
        await _forceLogout();
        return false;
      }

      final token = await firebaseUser.getIdToken(true) ?? '';
      await _persistUser(
        data: data,
        uid: firebaseUser.uid,
        token: token,
        fallbackEmail: firebaseUser.email ?? '',
        fallbackPhone: firebaseUser.phoneNumber ?? '',
      );

      _startSessionWatcher(firebaseUser.uid);
      return true;
    } catch (e) {
      debugPrint('validateSession error: $e');
      return _auth.currentUser != null;
    }
  }

  // ─── Real-time session watcher ────────────────────────────────
  void _startSessionWatcher(String uid) {
    _sessionWatcher?.cancel();
    _sessionWatcher = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
          if (!snap.exists) {
            await _forceLogout();
            return;
          }
          final data = snap.data()!;
          final isActive = data['isActive'] == true;
          final isDeleted = data['isDeleted'] == true;

          if (!isActive || isDeleted) {
            log(
              'Session watcher: account deactivated/deleted — forcing logout',
            );
            _wasDeactivated = true;
            notifyListeners();
            await _forceLogout();
          }
        }, onError: (e) => debugPrint('Session watcher error: $e'));
  }

  void stopSessionWatcher() {
    _sessionWatcher?.cancel();
    _sessionWatcher = null;
  }

  Future<void> _forceLogout() async {
    stopSessionWatcher();
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.clearUserData();
    _userData = {};
    resetAll();
  }

  // ─── Auth Mode / Method Control ───────────────────────────────
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

  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    // If the user is actively unchecking, wipe saved credentials immediately
    if (!_rememberMe) {
      _rememberedCredentials = null;
      _storage.clearRememberedCredentials();
    }
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setOtpSent(bool value) {
    _otpSent = value;
    notifyListeners();
  }

  void setForgotPasswordStep(ForgotPasswordStep step) {
    _forgotPasswordStep = step;
    notifyListeners();
  }

  void setResetEmail(String email) => _resetEmail = email;

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

  // ─── Helper: persist user ─────────────────────────────────────
  Future<void> _persistUser({
    required Map<String, dynamic> data,
    required String uid,
    required String token,
    String fallbackEmail = '',
    String fallbackPhone = '',
  }) async {
    await _storage.saveUserData(
      uid: data['uid'] ?? uid,
      token: token,
      name: data['name'] ?? '',
      email: data['email'] ?? fallbackEmail,
      phone: data['phone'] ?? fallbackPhone,
      role: data['role'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      profilePhoto: data['profilePhoto'],
      isActive: data['isActive'] ?? true,
    );
    _userData = {
      'uid': data['uid'] ?? uid,
      'name': data['name'] ?? '',
      'email': data['email'] ?? fallbackEmail,
      'phone': data['phone'] ?? fallbackPhone,
      'role': data['role'] ?? '',
      'businessId': data['businessId'] ?? '',
      'businessName': data['businessName'] ?? '',
      'profilePhoto': data['profilePhoto'] ?? '',
      'isActive': data['isActive'] ?? true,
    };
  }

  // ═══════════════════════════════════════════════════════════
  // EMAIL / PASSWORD LOGIN
  // ═══════════════════════════════════════════════════════════
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final emailTrimmed = email.trim().toLowerCase();

      // Step 1: Check email exists in Firestore
      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: emailTrimmed)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) {
        setLoading(false);
        return LoginResult.emailNotFound;
      }

      final firestoreData = snap.docs.first.data() as Map<String, dynamic>;

      // Step 2: Check isActive BEFORE signing in
      if (firestoreData['isActive'] != true) {
        setLoading(false);
        return LoginResult.inactive;
      }

      // Step 3: Firebase sign-in
      try {
        final UserCredential credential = await _auth
            .signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

        final User? firebaseUser = credential.user;
        if (firebaseUser == null) {
          setLoading(false);
          return LoginResult.error;
        }

        // Step 4: Re-fetch by UID
        final docSnap = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        final data = docSnap.exists ? docSnap.data()! : firestoreData;

        // Step 5: Double-check isActive
        if (data['isActive'] != true || data['isDeleted'] == true) {
          await _auth.signOut();
          setLoading(false);
          return LoginResult.inactive;
        }

        final token = await firebaseUser.getIdToken() ?? '';
        await _persistUser(
          data: data,
          uid: firebaseUser.uid,
          token: token,
          fallbackEmail: email.trim(),
        );

        // ── Step 6: Handle Remember Me ─────────────────────────
        if (_rememberMe) {
          await _storage.saveRememberedCredentials(
            email: email.trim(),
            password: password,
          );
          // Refresh the in-memory object so it's ready on next launch
          _rememberedCredentials = RememberedCredentials.email(
            email.trim(),
            password,
          );
          // Extend expiry on every successful remembered login
          await _storage.refreshRememberExpiry();
        } else {
          // User explicitly didn't check "Remember Me" — clear any old creds
          await _storage.clearRememberedCredentials();
          _rememberedCredentials = null;
        }

        // Step 7: Start real-time watcher
        _startSessionWatcher(firebaseUser.uid);

        log('Email login success: ${email.trim()} (${firebaseUser.uid})');
        setLoading(false);
        return LoginResult.success;
      } on FirebaseAuthException catch (e) {
        setLoading(false);
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          return LoginResult.wrongPassword;
        }
        return LoginResult.error;
      }
    } catch (e) {
      debugPrint('loginWithEmail error: $e');
      setLoading(false);
      return LoginResult.error;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GOOGLE SIGN-IN
  // ═══════════════════════════════════════════════════════════
  Future<String> signInWithGoogle() async {
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setLoading(false);
        return 'cancelled';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        setLoading(false);
        return 'error';
      }

      DocumentSnapshot docSnap = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      QuerySnapshot? emailSnap;
      if (!docSnap.exists && firebaseUser.email != null) {
        emailSnap = await _firestore
            .collection('users')
            .where('email', isEqualTo: firebaseUser.email!.toLowerCase())
            .limit(1)
            .get();

        if (emailSnap.docs.isEmpty) {
          emailSnap = await _firestore
              .collection('users')
              .where('email', isEqualTo: firebaseUser.email!)
              .limit(1)
              .get();
        }
      }

      final bool foundByUid = docSnap.exists;
      final bool foundByEmail = emailSnap != null && emailSnap.docs.isNotEmpty;

      if (!foundByUid && !foundByEmail) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        setLoading(false);
        return 'not_found';
      }

      final Map<String, dynamic> data = foundByUid
          ? docSnap.data() as Map<String, dynamic>
          : emailSnap!.docs.first.data() as Map<String, dynamic>;

      if (data['isActive'] != true || data['isDeleted'] == true) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        setLoading(false);
        return 'inactive';
      }

      final String token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: firebaseUser.uid,
        token: token,
        fallbackEmail: firebaseUser.email ?? '',
      );

      // Google login — no password to remember; clear any stale creds
      if (!_rememberMe) await _storage.clearRememberedCredentials();

      _startSessionWatcher(firebaseUser.uid);

      log('Google login success: ${firebaseUser.email} (${firebaseUser.uid})');
      setLoading(false);
      return 'success';
    } on FirebaseAuthException catch (e) {
      debugPrint('Google signIn FirebaseAuthException: ${e.code}');
      setLoading(false);
      return 'error';
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      setLoading(false);
      return 'error';
    }
  }

  Future<bool> socialLogin({required String provider}) async {
    if (provider == 'Google') {
      final result = await signInWithGoogle();
      return result == 'success';
    }
    setLoading(true);
    await Future.delayed(const Duration(seconds: 2));
    setLoading(false);
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // PHONE / OTP
  // ═══════════════════════════════════════════════════════════
  Future<String> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();
    try {
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';
      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (snap.docs.isEmpty)
        snap = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalised)
            .limit(1)
            .get();
      if (snap.docs.isEmpty) {
        setLoading(false);
        return 'not_found';
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;
      if (data['isActive'] != true || data['isDeleted'] == true) {
        setLoading(false);
        return 'inactive';
      }

      final completer = Completer<String>();
      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (c) {
          if (!completer.isCompleted) completer.complete('success');
        },
        verificationFailed: (e) {
          log('OTP send failed: ${e.code}');
          if (!completer.isCompleted) completer.complete('error');
        },
        codeSent: (String vId, int? resendToken) {
          _verificationId = vId;
          _resendToken = resendToken;
          if (!completer.isCompleted) completer.complete('success');
        },
        codeAutoRetrievalTimeout: (String vId) {
          _verificationId = vId;
          if (!completer.isCompleted) completer.complete('timeout');
        },
      );

      final result = await completer.future;
      setLoading(false);
      if (result == 'success') setOtpSent(true);
      return result;
    } catch (e) {
      debugPrint('sendOTP error: $e');
      setLoading(false);
      return 'error';
    }
  }

  Future<bool> verifyOTP({required String phone, required String otp}) async {
    if (_verificationId == null) return false;
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

      final String normalised = phone.startsWith('+') ? phone : '+91$phone';
      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (snap.docs.isEmpty)
        snap = await _firestore
            .collection('users')
            .where('phone', isEqualTo: normalised)
            .limit(1)
            .get();
      if (snap.docs.isEmpty) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;
      if (data['isActive'] != true || data['isDeleted'] == true) {
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final String token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: firebaseUser.uid,
        token: token,
        fallbackPhone: phone,
      );

      // ── Remember Me for phone ──────────────────────────────
      if (_rememberMe) {
        await _storage.saveRememberedPhone(phone: phone);
        _rememberedCredentials = RememberedCredentials.phone(phone);
        await _storage.refreshRememberExpiry();
      } else {
        await _storage.clearRememberedCredentials();
        _rememberedCredentials = null;
      }

      _startSessionWatcher(firebaseUser.uid);

      log('Phone login success: ${data['phone']}');
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('verifyOTP error: ${e.code}');
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('verifyOTP error: $e');
      setLoading(false);
      return false;
    }
  }

  Future<String> resendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.lightImpact();
    try {
      final String normalised = phone.startsWith('+') ? phone : '+91$phone';
      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) => debugPrint('Resend failed: ${e.code}'),
        codeSent: (String vId, int? resendToken) {
          _verificationId = vId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String vId) => _verificationId = vId,
      );
      setLoading(false);
      return 'success';
    } catch (e) {
      debugPrint('resendOTP error: $e');
      setLoading(false);
      return 'error';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FORGOT PASSWORD
  // ═══════════════════════════════════════════════════════════
  Future<bool> sendPasswordResetOTP({required String email}) async {
    setLoading(true);
    setResetEmail(email);
    HapticFeedback.mediumImpact();
    try {
      final String trimmedEmail = email.trim().toLowerCase();
      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty)
        snap = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
      if (snap.docs.isEmpty) {
        setLoading(false);
        return false;
      }

      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      await _firestore.collection('users').doc(snap.docs.first.id).update({
        'passwordLastChanged': FieldValue.serverTimestamp(),
      });
      setLoading(false);
      setOtpSent(true);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('sendPasswordResetOTP error: ${e.code}');
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('sendPasswordResetOTP error: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> resendPasswordResetOTP({required String email}) async {
    setLoading(true);
    HapticFeedback.lightImpact();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('resendPasswordResetOTP error: ${e.code}');
      setLoading(false);
      return false;
    } catch (e) {
      debugPrint('resendPasswordResetOTP error: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> verifyPasswordResetOTP({
    required String email,
    required String otp,
  }) async => true;

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async => true;

  // ═══════════════════════════════════════════════════════════
  // LOGOUT / RESET
  // ═══════════════════════════════════════════════════════════
  Future<void> logout() async {
    stopSessionWatcher();
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _storage.clearUserData();

    // ── Only wipe remembered credentials if NOT remembering ──
    // If rememberMe is still true, keep credentials so the
    // login screen auto-fills on next open.
    if (!_rememberMe) {
      await _storage.clearRememberedCredentials();
      _rememberedCredentials = null;
    }

    _userData = {};
    _wasDeactivated = false;
    resetAll();
  }

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
    // NOTE: _rememberMe intentionally NOT reset here —
    // it should persist to reflect the stored state.
    _otpSent = false;
    _agreedToTerms = false;
    _resetEmail = '';
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }
}

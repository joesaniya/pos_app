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
  subscriptionExpired,
  error,
}

enum OtpResult { success, subscriptionExpired, error }

class RememberedCredentials {
  final String method;
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

  StreamSubscription<DocumentSnapshot>? _sessionWatcher;
  StreamSubscription<DocumentSnapshot>? _subscriptionWatcher;
  Timer? _subscriptionExpiryTimer;

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

  bool _rememberedCredentialsLoaded = false;
  RememberedCredentials? _rememberedCredentials;

  bool _wasDeactivated = false;
  bool get wasDeactivated => _wasDeactivated;

  bool _subscriptionExpired = false;
  bool get subscriptionExpired => _subscriptionExpired;

  bool _subscriptionExpiredOnReopen = false;
  bool get subscriptionExpiredOnReopen => _subscriptionExpiredOnReopen;

  bool _isNavigatingAway = false;
  void clearNavigatingFlag() => _isNavigatingAway = false;

  String? _verificationId;
  int? _resendToken;
  Map<String, dynamic> _userData = {};

  // Phone OTP session cache — populated in sendOTP, consumed in verifyOTP
  String? _pendingOtpBusinessId;
  bool _pendingOtpSubExpired = false;
  Map<String, dynamic>? _pendingOtpUserData;

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

  RememberedCredentials? get rememberedCredentials => _rememberedCredentials;
  bool get hasRememberedCredentials => _rememberedCredentials != null;

  void _clearPendingOtpCache() {
    _pendingOtpBusinessId = null;
    _pendingOtpSubExpired = false;
    _pendingOtpUserData = null;
  }

  Future<bool> _isSubscriptionExpired(String bizId) async {
    try {
      final doc = await _firestore.collection('subscriptions').doc(bizId).get();
      if (!doc.exists) return true;

      final data = doc.data()!;

      final bool isActive = data['isActive'] as bool? ?? false;
      log('CHECK_SUBSCRIPTION: bizId=$bizId isActive=$isActive');
      if (!isActive) return true; // treat inactive as expired

      // Existing expiry date check
      final expiryRaw = data['expiryDate'];
      if (expiryRaw == null) return true;

      DateTime expiry;
      if (expiryRaw is Timestamp) {
        expiry = expiryRaw.toDate();
      } else if (expiryRaw is String) {
        expiry = DateTime.tryParse(expiryRaw) ?? DateTime(2000);
      } else {
        return true;
      }

      return DateTime.now().isAfter(expiry);
    } catch (e) {
      debugPrint('_isSubscriptionExpired error: $e');
      return false; // fail open to avoid blocking legitimate users on network error
    }
  }

  Future<bool> _isSubscriptionExpired1(String businessId) async {
    if (businessId.isEmpty) {
      log('SUB_CHECK: businessId empty → ALLOW');
      return false;
    }
    try {
      log('SUB_CHECK: reading subscriptions/$businessId ...');
      final subDoc = await _firestore
          .collection('subscriptions')
          .doc(businessId)
          .get();

      if (!subDoc.exists) {
        log('SUB_CHECK: doc does not exist → ALLOW');
        return false;
      }

      final rawIsActive = subDoc.data()!['isActive'];
      log('SUB_CHECK: subscriptions/$businessId → isActive=$rawIsActive');

      // Block ONLY when isActive is explicitly the boolean false
      if (rawIsActive == false) {
        log('SUB_CHECK: isActive=false → BLOCK');
        return true;
      }

      log('SUB_CHECK: isActive=$rawIsActive (not false) → ALLOW');
      return false;
    } catch (e) {
      // Fail-open — never block due to a read error
      log('SUB_CHECK: read error for $businessId → ALLOW (error: $e)');
      return false;
    }
  }

  Future<QueryDocumentSnapshot?> _findUserByPhone(String phone) async {
    final normalised = phone.startsWith('+') ? phone : '+91$phone';
    final raw = phone.startsWith('+') ? phone.replaceFirst('+91', '') : phone;
    final results = await Future.wait([
      _firestore
          .collection('users')
          .where('phone', isEqualTo: raw)
          .limit(1)
          .get(),
      _firestore
          .collection('users')
          .where('phone', isEqualTo: normalised)
          .limit(1)
          .get(),
    ]);
    for (final snap in results) {
      if (snap.docs.isNotEmpty) return snap.docs.first;
    }
    return null;
  }

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

  Future<void> clearRememberedCredentials() async {
    _rememberedCredentials = null;
    await _storage.clearRememberedCredentials();
    notifyListeners();
  }

  Future<bool> validateSession() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await _storage.clearUserData();
      return false;
    }
    try {
      final storedData = await _storage.getUserData();
      final canonicalUidFromStorage = storedData['uid'] as String? ?? '';
      final docIdToFetch = canonicalUidFromStorage.isNotEmpty
          ? canonicalUidFromStorage
          : firebaseUser.uid;

      var uidDoc = await _firestore.collection('users').doc(docIdToFetch).get();
      Map<String, dynamic>? data;

      if (uidDoc.exists) {
        data = uidDoc.data()!;
      } else if (docIdToFetch != firebaseUser.uid) {
        final uidDoc2 = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (uidDoc2.exists) data = uidDoc2.data()!;
      }

      if (data == null) {
        if (firebaseUser.phoneNumber != null &&
            firebaseUser.phoneNumber!.isNotEmpty) {
          final phoneDoc = await _findUserByPhone(firebaseUser.phoneNumber!);
          if (phoneDoc != null) data = phoneDoc.data() as Map<String, dynamic>;
        }
        if (data == null &&
            firebaseUser.email != null &&
            firebaseUser.email!.isNotEmpty) {
          final emailSnap = await _firestore
              .collection('users')
              .where('email', isEqualTo: firebaseUser.email!.toLowerCase())
              .limit(1)
              .get();
          if (emailSnap.docs.isNotEmpty)
            data = emailSnap.docs.first.data() as Map<String, dynamic>;
        }
      }

      if (data == null) {
        await _forceLogout();
        return false;
      }

      if (data['isActive'] == false) {
        final bizId = data['businessId'] as String? ?? '';
        if (bizId.isNotEmpty) {
          try {
            final subDoc = await _firestore
                .collection('subscriptions')
                .doc(bizId)
                .get();
            if (subDoc.exists && subDoc.data()!['isActive'] == false) {
              _subscriptionExpiredOnReopen = true;
              _subscriptionExpired = true;
              await _forceLogout();
              return false;
            }
          } catch (_) {}
        }
        _wasDeactivated = true;
        await _forceLogout();
        return false;
      }

      if (data['isDeleted'] == true) {
        await _forceLogout();
        return false;
      }

      final businessId = data['businessId'] as String? ?? '';
      if (await _isSubscriptionExpired(businessId)) {
        _subscriptionExpiredOnReopen = true;
        _subscriptionExpired = true;
        await _forceLogout();
        return false;
      }

      final String canonicalUid = (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : docIdToFetch;

      final token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: canonicalUid,
        token: token,
        fallbackEmail: firebaseUser.email ?? '',
        fallbackPhone: firebaseUser.phoneNumber ?? '',
      );
      _startSessionWatcher(canonicalUid);
      _startSubscriptionWatcher(businessId);
      return true;
    } catch (e) {
      debugPrint('validateSession error: $e');
      if (_auth.currentUser != null) {
        final storedCache = await _storage.getUserData();
        if (storedCache.isNotEmpty && storedCache['uid'] != '')
          _userData = storedCache;
        return true;
      }
      return false;
    }
  }

  void _startSessionWatcher(String uid) {
    _sessionWatcher?.cancel();
    _sessionWatcher = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
          if (_isNavigatingAway) return;
          if (!snap.exists) return;
          final data = snap.data()!;
          if (data['isActive'] != true || data['isDeleted'] == true) {
            final bizId = data['businessId'] as String? ?? '';
            if (bizId.isNotEmpty) {
              try {
                final subDoc = await _firestore
                    .collection('subscriptions')
                    .doc(bizId)
                    .get();
                if (subDoc.exists && subDoc.data()!['isActive'] == false) {
                  _subscriptionExpired = true;
                  notifyListeners();
                  await _forceLogout();
                  return;
                }
              } catch (_) {}
            }
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

  void _startSubscriptionWatcher(String businessId) {
    if (businessId.isEmpty) return;
    _subscriptionWatcher?.cancel();
    _subscriptionExpiryTimer?.cancel();
    _subscriptionWatcher = _firestore
        .collection('subscriptions')
        .doc(businessId)
        .snapshots()
        .listen((snap) async {
          if (!snap.exists) return;
          final data = snap.data()!;
          if (data['isActive'] == false) {
            await _handleSubscriptionExpired(businessId, data);
            return;
          }
          final expiryRaw = data['expiryDate'];
          if (expiryRaw is Timestamp) {
            _scheduleExpiryTimer(businessId, expiryRaw.toDate(), data);
          }
        }, onError: (e) => debugPrint('SubWatcher error: $e'));
  }

  void _scheduleExpiryTimer(
    String businessId,
    DateTime expiryDate,
    Map<String, dynamic> subData,
  ) {
    _subscriptionExpiryTimer?.cancel();
    final diff = expiryDate.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds == 0) {
      _handleSubscriptionExpired(businessId, subData);
      return;
    }
    const maxDuration = Duration(days: 24);
    final fireDuration = diff > maxDuration ? maxDuration : diff;
    _subscriptionExpiryTimer = Timer(fireDuration, () async {
      if (diff > maxDuration) {
        _scheduleExpiryTimer(businessId, expiryDate, subData);
      } else {
        await _handleSubscriptionExpired(businessId, subData);
      }
    });
  }

  Future<void> _handleSubscriptionExpired(
    String businessId,
    Map<String, dynamic> subData,
  ) async {
    try {
      final currentSnap = await _firestore
          .collection('subscriptions')
          .doc(businessId)
          .get();
      if (!currentSnap.exists) return;
      if (currentSnap.data()!['isActive'] == false) {
        _subscriptionExpired = true;
        notifyListeners();
        await _forceLogout();
        return;
      }
      await _firestore.collection('subscriptions').doc(businessId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivatedReason': 'subscription_expired',
      });
      final usersSnap = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .get();
      if (usersSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in usersSnap.docs) {
          batch.update(doc.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('_handleSubscriptionExpired error: $e');
    }
  }

  void _cancelSubscriptionWatcher() {
    _subscriptionWatcher?.cancel();
    _subscriptionWatcher = null;
    _subscriptionExpiryTimer?.cancel();
    _subscriptionExpiryTimer = null;
  }

  Future<bool> renewSubscription({
    required String businessId,
    required DateTime newExpiryDate,
    String planType = 'monthly',
    int maxUsers = 5,
  }) async {
    if (businessId.isEmpty) return false;
    try {
      await _firestore.collection('subscriptions').doc(businessId).update({
        'isActive': true,
        'expiryDate': Timestamp.fromDate(newExpiryDate),
        'planType': planType,
        'maxUsers': maxUsers,
        'renewedAt': FieldValue.serverTimestamp(),
        'deactivatedReason': FieldValue.delete(),
        'deactivatedAt': FieldValue.delete(),
      });
      final usersSnap = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .get();
      final batch = _firestore.batch();
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        if (d['isDeleted'] == true || d['isActive'] == true) continue;
        batch.update(doc.reference, {
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _subscriptionExpired = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('renewSubscription error: $e');
      return false;
    }
  }

  Future<void> logout() async => _forceLogout();

  Future<void> _forceLogout() async {
    stopSessionWatcher();
    _cancelSubscriptionWatcher();
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.clearUserData();
    _userData = {};
    _resetFormState();
    _clearPendingOtpCache();
    _isNavigatingAway = false;
  }

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
    _clearPendingOtpCache();
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

  void toggleAgreedToTerms() {
    _agreedToTerms = !_agreedToTerms;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void toggleRememberMe() {
    _rememberMe = !_rememberMe;
    if (!_rememberMe) {
      _rememberedCredentials = null;
      _storage.clearRememberedCredentials();
    }
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

  void setForgotPasswordStep(ForgotPasswordStep s) {
    _forgotPasswordStep = s;
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

  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    setLoading(true);
    HapticFeedback.mediumImpact();
    try {
      final emailTrimmed = email.trim().toLowerCase();
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
      if (firestoreData['isActive'] != true) {
        setLoading(false);
        return LoginResult.inactive;
      }

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

        final docSnap = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        final data = docSnap.exists ? docSnap.data()! : firestoreData;

        if (data['isActive'] != true || data['isDeleted'] == true) {
          await _auth.signOut();
          setLoading(false);
          return LoginResult.inactive;
        }

        final bizId = data['businessId'] as String? ?? '';
        log('EMAIL LOGIN: checking subscription for bizId=$bizId');
        if (await _isSubscriptionExpired(bizId)) {
          _subscriptionExpired = true;
          await _auth.signOut();
          setLoading(false);
          return LoginResult.subscriptionExpired;
        }

        final token = await firebaseUser.getIdToken() ?? '';
        await _persistUser(
          data: data,
          uid: firebaseUser.uid,
          token: token,
          fallbackEmail: email.trim(),
        );

        if (_rememberMe) {
          await _storage.saveRememberedCredentials(
            email: email.trim(),
            password: password,
          );
          _rememberedCredentials = RememberedCredentials.email(
            email.trim(),
            password,
          );
          await _storage.refreshRememberExpiry();
        } else {
          await _storage.clearRememberedCredentials();
          _rememberedCredentials = null;
        }

        _startSessionWatcher(firebaseUser.uid);
        _startSubscriptionWatcher(bizId);
        _isNavigatingAway = true;
        setLoading(false);
        return LoginResult.success;
      } on FirebaseAuthException catch (e) {
        setLoading(false);
        return (e.code == 'wrong-password' || e.code == 'invalid-credential')
            ? LoginResult.wrongPassword
            : LoginResult.error;
      }
    } catch (e) {
      debugPrint('loginWithEmail error: $e');
      setLoading(false);
      return LoginResult.error;
    }
  }

  Future<String> signInWithGoogle() async {
    setLoading(true);
    HapticFeedback.mediumImpact();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setLoading(false);
        return 'cancelled';
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential uc = await _auth.signInWithCredential(credential);
      final User? firebaseUser = uc.user;
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

      final bizId = data['businessId'] as String? ?? '';
      if (await _isSubscriptionExpired(bizId)) {
        _subscriptionExpired = true;
        await _auth.signOut();
        await _googleSignIn.signOut();
        setLoading(false);
        return 'subscriptionExpired';
      }

      final token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: firebaseUser.uid,
        token: token,
        fallbackEmail: firebaseUser.email ?? '',
      );
      if (!_rememberMe) await _storage.clearRememberedCredentials();
      _startSessionWatcher(firebaseUser.uid);
      _startSubscriptionWatcher(bizId);
      _isNavigatingAway = true;
      setLoading(false);
      return 'success';
    } on FirebaseAuthException catch (e) {
      debugPrint('Google signIn error: ${e.code}');
      setLoading(false);
      return 'error';
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      setLoading(false);
      return 'error';
    }
  }

  Future<bool> socialLogin({required String provider}) async {
    if (provider == 'Google') return await signInWithGoogle() == 'success';
    setLoading(true);
    await Future.delayed(const Duration(seconds: 2));
    setLoading(false);
    return false;
  }

  Future<String> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();
    _clearPendingOtpCache();

    try {
      log('SEND_OTP: looking up phone=$phone');
      final doc = await _findUserByPhone(phone);
      if (doc == null) {
        log('SEND_OTP: user not found');
        setLoading(false);
        return 'not_found';
      }

      final data = doc.data() as Map<String, dynamic>;
      log(
        'SEND_OTP: found user uid=${data['uid']} isActive=${data['isActive']} businessId=${data['businessId']}',
      );

      if (data['isActive'] != true || data['isDeleted'] == true) {
        log('SEND_OTP: user inactive/deleted → blocking');
        setLoading(false);
        return 'inactive';
      }

      final bizId = data['businessId'] as String? ?? '';
      log('SEND_OTP: checking subscription for bizId=$bizId');
      final subExpired = await _isSubscriptionExpired(bizId);
      log('SEND_OTP: subExpired=$subExpired');

      // Cache for verifyOTP
      _pendingOtpBusinessId = bizId;
      _pendingOtpSubExpired = subExpired;
      _pendingOtpUserData = data;

      if (subExpired) {
        log('SEND_OTP: subscription expired → blocking OTP send');
        _subscriptionExpired = true;
        setLoading(false);
        return 'subscription_expired';
      }

      log('SEND_OTP: subscription valid → sending OTP');
      final normalised = phone.startsWith('+') ? phone : '+91$phone';
      final completer = Completer<String>();

      await _auth.verifyPhoneNumber(
        phoneNumber: normalised,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (c) {
          if (!completer.isCompleted) completer.complete('auto_verified');
        },
        verificationFailed: (e) {
          log('SEND_OTP: verificationFailed code=${e.code}');
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
      log('SEND_OTP: verifyPhoneNumber result=$result');
      setLoading(false);
      if (result == 'success' || result == 'auto_verified') {
        setOtpSent(true);
        return 'success';
      }
      return result;
    } catch (e) {
      debugPrint('sendOTP error: $e');
      setLoading(false);
      return 'error';
    }
  }

  Future<OtpResult> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    if (_verificationId == null) {
      debugPrint('verifyOTP: no verificationId');
      return OtpResult.error;
    }

    log(
      'VERIFY_OTP: pendingSubExpired=$_pendingOtpSubExpired  pendingBizId=$_pendingOtpBusinessId',
    );

    // Use cached subscription result from sendOTP
    if (_pendingOtpSubExpired) {
      log('VERIFY_OTP: cached sub expired → blocking:${_pendingOtpSubExpired}');
      _subscriptionExpired = true;
      notifyListeners();
      return OtpResult.subscriptionExpired;
    }

    if (_pendingOtpUserData == null) {
      debugPrint('VERIFY_OTP: no cached user data → error');
      return OtpResult.error;
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      log('VERIFY_OTP: calling signInWithCredential...');
      final UserCredential uc = await _auth.signInWithCredential(credential);
      final User? firebaseUser = uc.user;
      if (firebaseUser == null) {
        log('VERIFY_OTP: Firebase returned null user');
        setLoading(false);
        return OtpResult.error;
      }
      log('VERIFY_OTP: Firebase auth OK uid=${firebaseUser.uid}');

      final data = _pendingOtpUserData!;
      final bizId =
          _pendingOtpBusinessId ?? (data['businessId'] as String? ?? '');

      log('VERIFY_OTP: using cached data uid=${data['uid']} bizId=$bizId');

      // Re-check isActive from subscriptions at verify time (catches changes
      // that happened between sendOTP and verifyOTP)
      if (bizId.isNotEmpty) {
        final subExpired = await _isSubscriptionExpired(bizId);
        if (subExpired) {
          log(
            'VERIFY_OTP: subscription inactive/expired at verify time:$subExpired',
          );
          _pendingOtpSubExpired = true;
          _subscriptionExpired = true;
          notifyListeners();
          await _auth.signOut();
          setLoading(false);
          return OtpResult.subscriptionExpired;
        }
      }

      if (data['isActive'] != true || data['isDeleted'] == true) {
        log('VERIFY_OTP: cached data inactive → error');
        await _auth.signOut();
        setLoading(false);
        return OtpResult.error;
      }

      final String canonicalUid = (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : firebaseUser.uid;

      log(
        'VERIFY_OTP: canonicalUid=$canonicalUid firebaseUid=${firebaseUser.uid}',
      );

      // Update phone field on canonical doc if needed (best-effort)
      if (canonicalUid != firebaseUser.uid) {
        try {
          final normalised = phone.startsWith('+') ? phone : '+91$phone';
          final storedPhone = data['phone'] as String? ?? '';
          if (storedPhone != phone && storedPhone != normalised) {
            await _firestore.collection('users').doc(canonicalUid).update({
              'phone': normalised,
            });
          }
        } catch (e) {
          debugPrint('VERIFY_OTP: phone update failed (non-critical): $e');
        }
      }

      final String token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: canonicalUid,
        token: token,
        fallbackPhone: phone,
      );

      if (_rememberMe) {
        await _storage.saveRememberedPhone(phone: phone);
        _rememberedCredentials = RememberedCredentials.phone(phone);
        await _storage.refreshRememberExpiry();
      } else {
        await _storage.clearRememberedCredentials();
        _rememberedCredentials = null;
      }

      _startSessionWatcher(canonicalUid);
      _startSubscriptionWatcher(bizId);
      _clearPendingOtpCache();
      _isNavigatingAway = true;
      log('VERIFY_OTP: success → navigating home');
      setLoading(false);
      return OtpResult.success;
    } on FirebaseAuthException catch (e) {
      debugPrint('verifyOTP FirebaseAuthException: ${e.code}');
      setLoading(false);
      return OtpResult.error;
    } catch (e) {
      debugPrint('verifyOTP error: $e');
      setLoading(false);
      return OtpResult.error;
    }
  }

  Future<String> resendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.lightImpact();
    try {
      final bizId = _pendingOtpBusinessId ?? '';
      if (bizId.isNotEmpty && await _isSubscriptionExpired(bizId)) {
        _pendingOtpSubExpired = true;
        _subscriptionExpired = true;
        log(
          'RESEND_OTP: subscription expired → $_pendingOtpSubExpired-->$_subscriptionExpired',
        );
        notifyListeners();
        setLoading(false);
        return 'subscription_expired';
      }
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

  Future<OtpResult> verifyOTP9march({
    required String phone,
    required String otp,
  }) async {
    if (_verificationId == null) {
      debugPrint('verifyOTP: no verificationId');
      return OtpResult.error;
    }

    log(
      'VERIFY_OTP: pendingSubExpired=$_pendingOtpSubExpired  pendingBizId=$_pendingOtpBusinessId',
    );

    // Use cached subscription result from sendOTP
    if (_pendingOtpSubExpired) {
      log('VERIFY_OTP: cached sub expired → blocking:${_pendingOtpSubExpired}');
      _subscriptionExpired = true;
      notifyListeners();
      return OtpResult.subscriptionExpired;
    }

    if (_pendingOtpUserData == null) {
      debugPrint('VERIFY_OTP: no cached user data → error');
      return OtpResult.error;
    }

    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      log('VERIFY_OTP: calling signInWithCredential...');
      final UserCredential uc = await _auth.signInWithCredential(credential);
      final User? firebaseUser = uc.user;
      if (firebaseUser == null) {
        log('VERIFY_OTP: Firebase returned null user');
        setLoading(false);
        return OtpResult.error;
      }
      log('VERIFY_OTP: Firebase auth OK uid=${firebaseUser.uid}');

      // Use cached user data — no Firestore reads after auth context changed
      final data = _pendingOtpUserData!;
      final bizId =
          _pendingOtpBusinessId ?? (data['businessId'] as String? ?? '');

      log('VERIFY_OTP: using cached data uid=${data['uid']} bizId=$bizId');

      if (data['isActive'] != true || data['isDeleted'] == true) {
        log('VERIFY_OTP: cached data inactive → error');
        await _auth.signOut();
        setLoading(false);
        return OtpResult.error;
      }

      final String canonicalUid = (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : firebaseUser.uid;

      log(
        'VERIFY_OTP: canonicalUid=$canonicalUid firebaseUid=${firebaseUser.uid}',
      );

      // Update phone field on canonical doc if needed (best-effort)
      if (canonicalUid != firebaseUser.uid) {
        try {
          final normalised = phone.startsWith('+') ? phone : '+91$phone';
          final storedPhone = data['phone'] as String? ?? '';
          if (storedPhone != phone && storedPhone != normalised) {
            await _firestore.collection('users').doc(canonicalUid).update({
              'phone': normalised,
            });
          }
        } catch (e) {
          debugPrint('VERIFY_OTP: phone update failed (non-critical): $e');
        }
      }

      final String token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: canonicalUid,
        token: token,
        fallbackPhone: phone,
      );

      if (_rememberMe) {
        await _storage.saveRememberedPhone(phone: phone);
        _rememberedCredentials = RememberedCredentials.phone(phone);
        await _storage.refreshRememberExpiry();
      } else {
        await _storage.clearRememberedCredentials();
        _rememberedCredentials = null;
      }

      _startSessionWatcher(canonicalUid);
      _startSubscriptionWatcher(bizId);
      _clearPendingOtpCache();
      _isNavigatingAway = true;
      log('VERIFY_OTP: success → navigating home');
      setLoading(false);
      return OtpResult.success;
    } on FirebaseAuthException catch (e) {
      debugPrint('verifyOTP FirebaseAuthException: ${e.code}');
      setLoading(false);
      return OtpResult.error;
    } catch (e) {
      debugPrint('verifyOTP error: $e');
      setLoading(false);
      return OtpResult.error;
    }
  }

  Future<String> resendOTP9marc({required String phone}) async {
    setLoading(true);
    HapticFeedback.lightImpact();
    try {
      final bizId = _pendingOtpBusinessId ?? '';
      if (bizId.isNotEmpty && await _isSubscriptionExpired(bizId)) {
        _pendingOtpSubExpired = true;
        _subscriptionExpired = true;
        setLoading(false);
        return 'subscription_expired';
      }
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

  Future<bool> sendPasswordResetOTP({required String email}) async {
    setLoading(true);
    setResetEmail(email);
    HapticFeedback.mediumImpact();
    try {
      final trimmedEmail = email.trim().toLowerCase();
      QuerySnapshot snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
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

  Future<void> logout1() async {
    stopSessionWatcher();
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _storage.clearUserData();
    if (!_rememberMe) {
      await _storage.clearRememberedCredentials();
      _rememberedCredentials = null;
    }
    _userData = {};
    _wasDeactivated = false;
    _clearPendingOtpCache();
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
    _otpSent = false;
    _agreedToTerms = false;
    _resetEmail = '';
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }
}

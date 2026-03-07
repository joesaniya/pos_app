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

// ── Remember Me credentials returned to the UI ───────────────
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

  bool _isNavigatingAway = false;
  void clearNavigatingFlag() {
    _isNavigatingAway = false;
  }

  String? _verificationId;
  int? _resendToken;
  Map<String, dynamic> _userData = {};

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
        log('validateSession: found user by canonical UID ($docIdToFetch)');
      } else if (docIdToFetch != firebaseUser.uid) {
        // Also check the firebase user uid just in case
        final uidDoc2 = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (uidDoc2.exists) {
          data = uidDoc2.data()!;
          log(
            'validateSession: found user by Firebase UID (${firebaseUser.uid})',
          );
        }
      }

      if (data == null) {
        log('validateSession: UID doc not found — trying phone/email fallback');

        if (firebaseUser.phoneNumber != null &&
            firebaseUser.phoneNumber!.isNotEmpty) {
          final phoneDoc = await _findUserByPhone(firebaseUser.phoneNumber!);
          if (phoneDoc != null) {
            data = phoneDoc.data() as Map<String, dynamic>;
            log(
              'validateSession: found user by phone (${firebaseUser.phoneNumber})',
            );
          }
        }

        if (data == null &&
            firebaseUser.email != null &&
            firebaseUser.email!.isNotEmpty) {
          final emailSnap = await _firestore
              .collection('users')
              .where('email', isEqualTo: firebaseUser.email!.toLowerCase())
              .limit(1)
              .get();
          if (emailSnap.docs.isNotEmpty) {
            data = emailSnap.docs.first.data() as Map<String, dynamic>;
            log('validateSession: found user by email (${firebaseUser.email})');
          }
        }
      }

      if (data == null) {
        log('validateSession: user doc not found anywhere — forcing logout');
        await _forceLogout();
        return false;
      }

      if (data['isActive'] == false) {
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
        _subscriptionExpired = true;
        await _forceLogout();
        return false;
      }

      final String canonicalUid = (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : docIdToFetch;

      log(
        'validateSession: canonicalUid=$canonicalUid  businessId=${data['businessId']}',
      );

      final token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: canonicalUid,
        token: token,
        fallbackEmail: firebaseUser.email ?? '',
        fallbackPhone: firebaseUser.phoneNumber ?? '',
      );
      _startSessionWatcher(canonicalUid);
      _startSubscriptionWatcher(data['businessId'] as String? ?? '');
      return true;
    } catch (e) {
      debugPrint('validateSession error: $e');
      if (_auth.currentUser != null) {
        log(
          'validateSession: Encountered expected/unexpected error — falling back to cached StorageService session.',
        );
        final storedCache = await _storage.getUserData();
        if (storedCache.isNotEmpty && storedCache['uid'] != '') {
          _userData = storedCache;
        }
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

          if (!snap.exists) {
            log(
              'Session watcher: UID doc not found (phone-auth user — ignoring)',
            );
            return;
          }

          final data = snap.data()!;
          if (data['isActive'] != true || data['isDeleted'] == true) {
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

  // ── Subscription Real-Time Watcher ────────────────────────────────────────
  /// Starts a Firestore listener on the subscription document.
  /// • If `isActive` flips to false externally → triggers logout.
  /// • Schedules a precise in-process [Timer] that fires at the exact
  ///   `expiryDate` to auto-deactivate without waiting for WorkManager.
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

          // If subscription was externally deactivated (e.g. admin action)
          if (data['isActive'] == false) {
            log('SubWatcher: isActive=false detected — expiring session');
            await _handleSubscriptionExpired(businessId, data);
            return;
          }

          // Schedule precise timer for expiry date
          final expiryRaw = data['expiryDate'];
          if (expiryRaw is Timestamp) {
            final expiryDate = expiryRaw.toDate();
            _scheduleExpiryTimer(businessId, expiryDate, data);
          }
        },
        onError: (e) => debugPrint('SubWatcher error: $e'));
  }

  void _scheduleExpiryTimer(
    String businessId,
    DateTime expiryDate,
    Map<String, dynamic> subData,
  ) {
    _subscriptionExpiryTimer?.cancel();

    final now = DateTime.now();
    final diff = expiryDate.difference(now);

    if (diff.isNegative || diff.inSeconds == 0) {
      // Already expired — act immediately
      log('SubWatcher: expiryDate already past — expiring now');
      _handleSubscriptionExpired(businessId, subData);
      return;
    }

    // Cap at max Timer duration (~24.8 days); reschedule if longer
    const maxDuration = Duration(days: 24);
    final fireDuration = diff > maxDuration ? maxDuration : diff;

    log('SubWatcher: scheduling expiry timer in ${diff.inMinutes} min(s)');
    _subscriptionExpiryTimer = Timer(fireDuration, () async {
      if (diff > maxDuration) {
        // Not yet expired — reschedule for next window
        _scheduleExpiryTimer(businessId, expiryDate, subData);
      } else {
        log('SubWatcher: expiry timer fired — deactivating subscription');
        await _handleSubscriptionExpired(businessId, subData);
      }
    });
  }

  Future<void> _handleSubscriptionExpired(
    String businessId,
    Map<String, dynamic> subData,
  ) async {
    try {
      final planType =
          (subData['planType'] as String?)?.toLowerCase() ?? 'monthly';

      // 1. Deactivate subscription doc (only if still active)
      final currentSnap = await _firestore
          .collection('subscriptions')
          .doc(businessId)
          .get();
      if (!currentSnap.exists) return;
      if (currentSnap.data()!['isActive'] == false) {
        // Already deactivated — just force logout
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
      log('SubWatcher: subscription doc deactivated for $businessId');

      // 2. Batch-deactivate all active users of this business
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
        log('SubWatcher: deactivated ${usersSnap.docs.length} user(s) — '
            'session watcher will trigger logout');
      }

      // 3. Set flag & notify — the session watcher will handle the UI
      //    (it watches users/{uid}.isActive and will force logout)
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

  Future<bool> _isSubscriptionExpired(String businessId) async {
    if (businessId.isEmpty) return false;
    try {
      final subDoc = await _firestore
          .collection('subscriptions')
          .doc(businessId)
          .get();
      if (!subDoc.exists) return false;
      final subData = subDoc.data()!;
      if (subData['isActive'] == false) return true;
      final expiry = subData['expiryDate'];
      if (expiry is Timestamp) {
        return expiry.toDate().isBefore(DateTime.now());
      }
    } catch (_) {}
    return false;
  }

  // ── Subscription Renewal ──────────────────────────────────────────────────
  /// Call this after a successful payment to reactivate the subscription and
  /// restore access to all users of that business.
  Future<bool> renewSubscription({
    required String businessId,
    required DateTime newExpiryDate,
    String planType = 'monthly',
    int maxUsers = 5,
  }) async {
    if (businessId.isEmpty) return false;
    try {
      log('renewSubscription: activating businessId=$businessId until $newExpiryDate');

      // 1. Update subscription document
      await _firestore.collection('subscriptions').doc(businessId).update({
        'isActive': true,
        'expiryDate': Timestamp.fromDate(newExpiryDate),
        'planType': planType,
        'maxUsers': maxUsers,
        'renewedAt': FieldValue.serverTimestamp(),
        'deactivatedReason': FieldValue.delete(),
        'deactivatedAt': FieldValue.delete(),
      });

      // 2. Re-enable all users for this business (that were deactivated by expiry)
      //    Only re-enable those NOT explicitly soft-deleted (isDeleted != true).
      final usersSnap = await _firestore
          .collection('users')
          .where('businessId', isEqualTo: businessId)
          .get();

      final batch = _firestore.batch();
      int reactivated = 0;
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        if (d['isDeleted'] == true) continue; // skip soft-deleted users
        if (d['isActive'] == true) continue;  // already active — skip
        batch.update(doc.reference, {
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        reactivated++;
      }
      await batch.commit();
      log('renewSubscription: reactivated $reactivated user(s)');

      // 3. Clear the in-memory expiry flag so the current session is aware
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
    resetAll();
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
      if (snap.docs.isEmpty)
        snap = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
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
        log('Email login success: ${email.trim()} (${firebaseUser.uid})');
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
        if (emailSnap.docs.isEmpty)
          emailSnap = await _firestore
              .collection('users')
              .where('email', isEqualTo: firebaseUser.email!)
              .limit(1)
              .get();
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

      log('Google login success: ${firebaseUser.email} (${firebaseUser.uid})');
      _isNavigatingAway = true;
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
    if (provider == 'Google') return await signInWithGoogle() == 'success';
    setLoading(true);
    await Future.delayed(const Duration(seconds: 2));
    setLoading(false);
    return false;
  }

  Future<String> sendOTP({required String phone}) async {
    setLoading(true);
    HapticFeedback.mediumImpact();
    try {
      final doc = await _findUserByPhone(phone);
      if (doc == null) {
        setLoading(false);
        return 'not_found';
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] != true || data['isDeleted'] == true) {
        setLoading(false);
        return 'inactive';
      }

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

  Future<bool> verifyOTP({required String phone, required String otp}) async {
    if (_verificationId == null) {
      debugPrint('verifyOTP: no verificationId — OTP was never sent');
      return false;
    }
    setLoading(true);
    HapticFeedback.mediumImpact();

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final UserCredential uc = await _auth.signInWithCredential(credential);
      final User? firebaseUser = uc.user;

      if (firebaseUser == null) {
        debugPrint('verifyOTP: Firebase returned null user');
        setLoading(false);
        return false;
      }
      log('verifyOTP: Firebase auth OK — uid=${firebaseUser.uid}');

      Map<String, dynamic>? data;

      final uidDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (uidDoc.exists) {
        data = uidDoc.data() as Map<String, dynamic>;
        log('verifyOTP: found user by UID');
      } else {
        log('verifyOTP: UID doc not found — falling back to phone query');
        final phoneDoc = await _findUserByPhone(phone);
        if (phoneDoc != null) {
          data = phoneDoc.data() as Map<String, dynamic>;
          log('verifyOTP: found user by phone query');
        }
      }

      if (data == null) {
        log('verifyOTP: user not found in Firestore — signing out');
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      if (data['isActive'] != true || data['isDeleted'] == true) {
        log('verifyOTP: account inactive or deleted — signing out');
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final bizId = data['businessId'] as String? ?? '';
      if (await _isSubscriptionExpired(bizId)) {
        _subscriptionExpired = true;
        log('verifyOTP: subscription expired — signing out');
        await _auth.signOut();
        setLoading(false);
        return false;
      }

      final String canonicalUid = (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : firebaseUser.uid;

      log(
        'verifyOTP: canonicalUid=$canonicalUid  firebaseUid=${firebaseUser.uid}',
      );

      if (canonicalUid != firebaseUser.uid) {
        try {
          log(
            'verifyOTP: phone UID differs from canonical UID — '
            'using canonical UID for session, leaving Firestore doc intact',
          );

          final storedPhone = data['phone'] as String? ?? '';
          final normalised = phone.startsWith('+') ? phone : '+91$phone';
          if (storedPhone != phone && storedPhone != normalised) {
            try {
              await _firestore.collection('users').doc(canonicalUid).update({
                'phone': normalised,
              });
              log(
                'verifyOTP: updated phone field to $normalised on canonical doc',
              );
            } catch (e) {
              debugPrint(
                'verifyOTP: phone field update failed (non-critical): $e',
              );
            }
          }
        } catch (e) {
          debugPrint('verifyOTP: account link step error (non-critical): $e');
        }
      }

      final String token = await firebaseUser.getIdToken() ?? '';
      await _persistUser(
        data: data,
        uid: canonicalUid,
        token: token,
        fallbackPhone: phone,
      );

      log(
        'verifyOTP: session persisted with canonicalUid=$canonicalUid  '
        'businessId=${data['businessId']}',
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
      _startSubscriptionWatcher(data['businessId'] as String? ?? '');

      log(
        'Phone login success — canonicalUid=$canonicalUid, phone=${data['phone']}',
      );
      _isNavigatingAway = true;
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

/*import 'dart:async';
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
*/

//phoneotploginissue

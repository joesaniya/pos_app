import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import '../services/storage_service.dart';

class SplashProvider with ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  bool _isLoading = true;
  bool _isFirstLaunch = true;
  bool _isLoggedIn = false;
  bool _subscriptionExpired = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoggedIn => _isLoggedIn;

  /// True when a stored session is found but the company subscription is expired.
  /// The splash screen uses this to route to [SubscriptionExpiredScreen] instead
  /// of [PageSwitcher].
  bool get subscriptionExpired => _subscriptionExpired;

  String get errorMessage => _errorMessage;

  // ─── Initialize ───────────────────────────────────────────
  /// Pass the [AppAuthenticationProvider] so we can call [validateSession()]
  /// and detect a subscription-expired state on reopen.
  Future<void> initializeApp({
    required AppAuthenticationProvider authProvider,
  }) async {
    try {
      // 5-second splash duration
      await Future.delayed(const Duration(seconds: 5));

      await _checkFirstLaunch();
      await _checkLoginStatus(authProvider: authProvider);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize app: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Internal Checks ──────────────────────────────────────
  Future<void> _checkFirstLaunch() async {
    _isFirstLaunch = await _storage.getIsFirstLaunch();
    if (_isFirstLaunch) {
      await _storage.setFirstLaunchDone();
    }
    log('First launch: $_isFirstLaunch');
    notifyListeners();
  }

  Future<void> _checkLoginStatus({
    required AppAuthenticationProvider authProvider,
  }) async {
    _isLoggedIn = await _storage.getIsLoggedIn();

    if (!_isLoggedIn) return;

    // Firebase Auth persists tokens — verify the session is still valid.
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      await _storage.clearUserData();
      _isLoggedIn = false;
      return;
    }

    try {
      await firebaseUser.getIdToken();
    } on FirebaseAuthException catch (authError) {
      final code = authError.code;
      if (code == 'user-disabled' ||
          code == 'user-not-found' ||
          code == 'user-token-expired' ||
          code == 'invalid-user-token') {
        log('Splash: Session invalid ($code), forcing logout.');
        await FirebaseAuth.instance.signOut();
        await _storage.clearUserData();
        _isLoggedIn = false;
        return;
      }
      log('Splash: Ignored auth error: $code');
    } catch (e) {
      log('Splash: Ignored generic error on token check: $e');
    }

    if (!_isLoggedIn) return;

    // ── Subscription check ──────────────────────────────────
    // validateSession() checks isActive on the user doc AND the subscription
    // doc. If it returns false AND subscriptionExpiredOnReopen is true, the
    // company subscription is expired — do not let the user into the app.
    final sessionValid = await authProvider.validateSession();
    if (!sessionValid) {
      _isLoggedIn = false;
      if (authProvider.subscriptionExpiredOnReopen) {
        _subscriptionExpired = true;
        log('Splash: Subscription expired — routing to SubscriptionExpiredScreen');
      } else {
        log('Splash: validateSession returned false — routing to LoginScreen');
      }
    }
  }

  // ─── Public Actions ───────────────────────────────────────
  Future<void> saveLoginStatus(bool status, {String? token}) async {
    await _storage.saveLoginStatus(status, token: token);
    _isLoggedIn = status;
    notifyListeners();
  }

  Future<void> clearUserData() async {
    await _storage.clearUserData();
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> resetFirstLaunch() async {
    await _storage.resetFirstLaunch();
    _isFirstLaunch = true;
    notifyListeners();
  }
}
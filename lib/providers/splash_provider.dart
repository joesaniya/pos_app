import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SplashProvider with ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  bool _isLoading = true;
  bool _isFirstLaunch = true;
  bool _isLoggedIn = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoggedIn => _isLoggedIn;
  String get errorMessage => _errorMessage;

  // ─── Initialize ───────────────────────────────────────────
  Future<void> initializeApp() async {
    try {
      // DO NOT call notifyListeners() here — this runs during initState
      // which is still inside the build phase. _isLoading starts as true
      // so the UI already shows the loading indicator by default.

      // 5-second splash duration
      await Future.delayed(const Duration(seconds: 5));

      await _checkFirstLaunch();
      await _checkLoginStatus();

      _isLoading = false;
      notifyListeners(); // safe — called after first frame is done
    } catch (e) {
      _errorMessage = 'Failed to initialize app: $e';
      _isLoading = false;
      notifyListeners(); // safe — called after first frame is done
    }
  }

  // ─── Internal Checks ──────────────────────────────────────
  Future<void> _checkFirstLaunch() async {
    _isFirstLaunch = await _storage.getIsFirstLaunch();
    if (_isFirstLaunch) {
      await _storage.setFirstLaunchDone();
    }
    log('First launch: $_isFirstLaunch');
  }

  Future<void> _checkLoginStatus() async {
    _isLoggedIn = await _storage.getIsLoggedIn();

    if (_isLoggedIn) {
      // Firebase Auth persists tokens in secure storage even after uninstall
      // In release builds this causes false "logged in" state on fresh install
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser == null) {
          // No Firebase session — force clear everything
          await _storage.clearUserData();
          _isLoggedIn = false;
        } else {
          // Firebase has a user — verify token is still valid
          await firebaseUser.getIdToken(true); // force refresh
        }
      } catch (e) {
        // Token refresh failed — session expired or invalid
        await FirebaseAuth.instance.signOut();
        await _storage.clearUserData();
        _isLoggedIn = false;
      }
    }
  }

  Future<void> _checkLoginStatus1() async {
    _isLoggedIn = await _storage.getIsLoggedIn();
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

/*import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SplashProvider with ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  bool _isLoading = true;
  bool _isFirstLaunch = true;
  bool _isLoggedIn = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isLoggedIn => _isLoggedIn;
  String get errorMessage => _errorMessage;

  // ─── Initialize ───────────────────────────────────────────
  Future<void> initializeApp() async {
    try {
      // DO NOT call notifyListeners() here — this runs during initState
      // which is still inside the build phase. _isLoading starts as true
      // so the UI already shows the loading indicator by default.

      // 5-second splash duration
      await Future.delayed(const Duration(seconds: 5));

      await _checkFirstLaunch();
      await _checkLoginStatus();

      _isLoading = false;
      notifyListeners(); // safe — called after first frame is done
    } catch (e) {
      _errorMessage = 'Failed to initialize app: $e';
      _isLoading = false;
      notifyListeners(); // safe — called after first frame is done
    }
  }

  // ─── Internal Checks ──────────────────────────────────────
  Future<void> _checkFirstLaunch() async {
    _isFirstLaunch = await _storage.getIsFirstLaunch();
    if (_isFirstLaunch) {
      await _storage.setFirstLaunchDone();
    }
  }

  Future<void> _checkLoginStatus() async {
    _isLoggedIn = await _storage.getIsLoggedIn();
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
}*/
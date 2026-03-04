import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  // ─── Keys ────────────────────────────────────────────────
  static const String _keyIsFirstLaunch = 'isFirstLaunch';
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyAuthToken = 'authToken';
  static const String _keyUid = 'uid';
  static const String _keyName = 'name';
  static const String _keyEmail = 'email';
  static const String _keyPhone = 'phone';
  static const String _keyRole = 'role';
  static const String _keyBusinessId = 'businessId';
  static const String _keyBusinessName = 'businessName';
  static const String _keyProfilePhoto = 'profilePhoto';
  static const String _keyIsActive = 'isActive';

  // ─── Remember Me Keys ─────────────────────────────────────
  static const String _keyRememberMe = 'rememberMe';
  static const String _keyRememberedEmail = 'rememberedEmail';
  static const String _keyRememberedPhone = 'rememberedPhone';
  static const String _keyRememberedPassword =
      'rememberedPassword'; // obfuscated
  static const String _keyRememberedMethod =
      'rememberedMethod'; // 'email' | 'phone'
  static const String _keyRememberExpiry = 'rememberExpiry'; // epoch ms

  /// How long "remember me" credentials stay valid (30 days)
  static const Duration _rememberDuration = Duration(days: 30);

  /// Simple obfuscation salt — not true encryption, but prevents
  /// plain-text passwords sitting in SharedPreferences.
  static const String _obfuscationSalt = 'POS_RM_SALT_2025';

  // ─── First Launch ─────────────────────────────────────────
  Future<bool> getIsFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsFirstLaunch) ?? true;
    } catch (e) {
      debugPrint('StorageService.getIsFirstLaunch error: $e');
      return true;
    }
  }

  Future<void> setFirstLaunchDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsFirstLaunch, false);
    } catch (e) {
      debugPrint('StorageService.setFirstLaunchDone error: $e');
    }
  }

  Future<void> resetFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsFirstLaunch, true);
    } catch (e) {
      debugPrint('StorageService.resetFirstLaunch error: $e');
    }
  }

  // ─── Auth ─────────────────────────────────────────────────
  Future<bool> getIsLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final token = prefs.getString(_keyAuthToken) ?? '';
      return loggedIn && token.isNotEmpty;
    } catch (e) {
      debugPrint('StorageService.getIsLoggedIn error: $e');
      return false;
    }
  }

  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthToken);
    } catch (e) {
      debugPrint('StorageService.getAuthToken error: $e');
      return null;
    }
  }

  Future<void> saveLoginStatus(bool status, {String? token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, status);
      if (token != null) {
        await prefs.setString(_keyAuthToken, token);
      }
    } catch (e) {
      debugPrint('StorageService.saveLoginStatus error: $e');
    }
  }

  // ─── Save Full User Data from Firestore ───────────────────
  Future<void> saveUserData({
    required String uid,
    required String token,
    required String name,
    required String email,
    required String phone,
    required String role,
    required String businessId,
    required String businessName,
    String? profilePhoto,
    bool isActive = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyAuthToken, token);
      await prefs.setString(_keyUid, uid);
      await prefs.setString(_keyName, name);
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyPhone, phone);
      await prefs.setString(_keyRole, role);
      await prefs.setString(_keyBusinessId, businessId);
      await prefs.setString(_keyBusinessName, businessName);
      await prefs.setString(_keyProfilePhoto, profilePhoto ?? '');
      await prefs.setBool(_keyIsActive, isActive);
    } catch (e) {
      debugPrint('StorageService.saveUserData error: $e');
    }
  }

  // ─── Get Stored User Data ─────────────────────────────────
  Future<Map<String, dynamic>> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'uid': prefs.getString(_keyUid) ?? '',
        'name': prefs.getString(_keyName) ?? '',
        'email': prefs.getString(_keyEmail) ?? '',
        'phone': prefs.getString(_keyPhone) ?? '',
        'role': prefs.getString(_keyRole) ?? '',
        'businessId': prefs.getString(_keyBusinessId) ?? '',
        'businessName': prefs.getString(_keyBusinessName) ?? '',
        'profilePhoto': prefs.getString(_keyProfilePhoto) ?? '',
        'isActive': prefs.getBool(_keyIsActive) ?? false,
      };
    } catch (e) {
      debugPrint('StorageService.getUserData error: $e');
      return {};
    }
  }

  // ─── Clear ────────────────────────────────────────────────
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUid);
      await prefs.remove(_keyName);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyPhone);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyBusinessId);
      await prefs.remove(_keyBusinessName);
      await prefs.remove(_keyProfilePhoto);
      await prefs.remove(_keyIsActive);
    } catch (e) {
      debugPrint('StorageService.clearUserData error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // REMEMBER ME
  // ═══════════════════════════════════════════════════════════

  /// Obfuscates [password] with a SHA-256 salted XOR approach.
  /// This is NOT cryptographic security — it prevents plain-text
  /// storage. For production, use flutter_secure_storage instead.
  String _obfuscate(String input) {
    final key = md5.convert(utf8.encode(_obfuscationSalt)).toString();
    final inputBytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final result = List<int>.generate(
      inputBytes.length,
      (i) => inputBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Url.encode(result);
  }

  String _deobfuscate(String encoded) {
    try {
      final key = md5.convert(utf8.encode(_obfuscationSalt)).toString();
      final inputBytes = base64Url.decode(encoded);
      final keyBytes = utf8.encode(key);
      final result = List<int>.generate(
        inputBytes.length,
        (i) => inputBytes[i] ^ keyBytes[i % keyBytes.length],
      );
      return utf8.decode(result);
    } catch (_) {
      return '';
    }
  }

  /// Saves "Remember Me" credentials for email/password login.
  /// Call this AFTER a successful login when rememberMe == true.
  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime.now()
          .add(_rememberDuration)
          .millisecondsSinceEpoch;

      await prefs.setBool(_keyRememberMe, true);
      await prefs.setString(_keyRememberedEmail, email.trim().toLowerCase());
      await prefs.setString(_keyRememberedPassword, _obfuscate(password));
      await prefs.setString(_keyRememberedMethod, 'email');
      await prefs.setInt(_keyRememberExpiry, expiry);

      debugPrint(
        'StorageService: email credentials remembered (expires in 30d)',
      );
    } catch (e) {
      debugPrint('StorageService.saveRememberedCredentials error: $e');
    }
  }

  /// Saves "Remember Me" credentials for phone/OTP login.
  /// Only stores the phone number (no OTP — that's one-time).
  Future<void> saveRememberedPhone({required String phone}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime.now()
          .add(_rememberDuration)
          .millisecondsSinceEpoch;

      await prefs.setBool(_keyRememberMe, true);
      await prefs.setString(_keyRememberedPhone, phone.trim());
      await prefs.setString(_keyRememberedMethod, 'phone');
      await prefs.setInt(_keyRememberExpiry, expiry);

      debugPrint('StorageService: phone remembered (expires in 30d)');
    } catch (e) {
      debugPrint('StorageService.saveRememberedPhone error: $e');
    }
  }

  /// Returns saved credentials if they exist AND haven't expired.
  /// Returns null if not remembered, expired, or an error occurred.
  ///
  /// Returned map shape (email method):
  ///   { 'method': 'email', 'email': '...', 'password': '...' }
  ///
  /// Returned map shape (phone method):
  ///   { 'method': 'phone', 'phone': '...' }
  Future<Map<String, String>?> getRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRemember = prefs.getBool(_keyRememberMe) ?? false;
      if (!isRemember) return null;

      // ── Expiry check ───────────────────────────────────────
      final expiryMs = prefs.getInt(_keyRememberExpiry) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
        debugPrint(
          'StorageService: remember-me credentials expired — clearing',
        );
        await clearRememberedCredentials();
        return null;
      }

      final method = prefs.getString(_keyRememberedMethod) ?? 'email';

      if (method == 'phone') {
        final phone = prefs.getString(_keyRememberedPhone) ?? '';
        if (phone.isEmpty) return null;
        return {'method': 'phone', 'phone': phone};
      }

      // email method
      final email = prefs.getString(_keyRememberedEmail) ?? '';
      final obfPwd = prefs.getString(_keyRememberedPassword) ?? '';
      final password = _deobfuscate(obfPwd);

      if (email.isEmpty || password.isEmpty) return null;
      return {'method': 'email', 'email': email, 'password': password};
    } catch (e) {
      debugPrint('StorageService.getRememberedCredentials error: $e');
      return null;
    }
  }

  /// Returns true if valid (non-expired) remembered credentials exist.
  Future<bool> hasRememberedCredentials() async {
    final creds = await getRememberedCredentials();
    return creds != null;
  }

  /// Returns just the remembered method ('email' | 'phone' | null).
  Future<String?> getRememberedMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRemember = prefs.getBool(_keyRememberMe) ?? false;
      if (!isRemember) return null;
      return prefs.getString(_keyRememberedMethod);
    } catch (_) {
      return null;
    }
  }

  /// Wipes all remembered credentials (called on manual logout
  /// or when rememberMe is unchecked).
  Future<void> clearRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRememberMe);
      await prefs.remove(_keyRememberedEmail);
      await prefs.remove(_keyRememberedPhone);
      await prefs.remove(_keyRememberedPassword);
      await prefs.remove(_keyRememberedMethod);
      await prefs.remove(_keyRememberExpiry);
      debugPrint('StorageService: remembered credentials cleared');
    } catch (e) {
      debugPrint('StorageService.clearRememberedCredentials error: $e');
    }
  }

  /// Extends the expiry by [_rememberDuration] from now.
  /// Call this on each successful auto-fill login to keep the
  /// credentials "fresh" as long as the user keeps using the app.
  Future<void> refreshRememberExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newExp = DateTime.now()
          .add(_rememberDuration)
          .millisecondsSinceEpoch;
      await prefs.setInt(_keyRememberExpiry, newExp);
    } catch (e) {
      debugPrint('StorageService.refreshRememberExpiry error: $e');
    }
  }
}

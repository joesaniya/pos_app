import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  // ─── Keys ────────────────────────────────────────────────
  static const String _keyIsFirstLaunch  = 'isFirstLaunch';
  static const String _keyIsLoggedIn     = 'isLoggedIn';
  static const String _keyAuthToken      = 'authToken';
  static const String _keyUid            = 'uid';
  static const String _keyName           = 'name';
  static const String _keyEmail          = 'email';
  static const String _keyPhone          = 'phone';
  static const String _keyRole           = 'role';
  static const String _keyBusinessId     = 'businessId';
  static const String _keyBusinessName   = 'businessName';
  static const String _keyProfilePhoto   = 'profilePhoto';
  static const String _keyIsActive       = 'isActive';

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
      final token    = prefs.getString(_keyAuthToken) ?? '';
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
        'uid':          prefs.getString(_keyUid) ?? '',
        'name':         prefs.getString(_keyName) ?? '',
        'email':        prefs.getString(_keyEmail) ?? '',
        'phone':        prefs.getString(_keyPhone) ?? '',
        'role':         prefs.getString(_keyRole) ?? '',
        'businessId':   prefs.getString(_keyBusinessId) ?? '',
        'businessName': prefs.getString(_keyBusinessName) ?? '',
        'profilePhoto': prefs.getString(_keyProfilePhoto) ?? '',
        'isActive':     prefs.getBool(_keyIsActive) ?? false,
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
}
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  // ─── Keys ────────────────────────────────────────────────
  static const String _keyIsFirstLaunch = 'isFirstLaunch';
  static const String _keyIsLoggedIn    = 'isLoggedIn';
  static const String _keyAuthToken     = 'authToken';

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
      return loggedIn || token.isNotEmpty;
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

  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyAuthToken);
    } catch (e) {
      debugPrint('StorageService.clearUserData error: $e');
    }
  }
}
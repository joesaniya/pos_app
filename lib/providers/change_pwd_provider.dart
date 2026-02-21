import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// ─── Password strength ────────────────────────────────────────────────────────
enum PasswordStrength { empty, weak, fair, good, strong }

extension PasswordStrengthX on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return const Color(0xFFE8E8F0);
      case PasswordStrength.weak:
        return const Color(0xFFEF4444);
      case PasswordStrength.fair:
        return const Color(0xFFF97316);
      case PasswordStrength.good:
        return const Color(0xFFEAB308);
      case PasswordStrength.strong:
        return const Color(0xFF22C55E);
    }
  }

  double get fraction {
    switch (this) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.50;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }
}

// ─── Flow steps ───────────────────────────────────────────────────────────────
enum CpStep { form, loading, success, error }

// ─── Provider ─────────────────────────────────────────────────────────────────
class ChangePasswordProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ChangePasswordProvider({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Visibility ────────────────────────────────────────────────
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;

  bool get currentVisible => _currentVisible;
  bool get newVisible => _newVisible;
  bool get confirmVisible => _confirmVisible;

  void toggleCurrentVisibility() {
    _currentVisible = !_currentVisible;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void toggleNewVisibility() {
    _newVisible = !_newVisible;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void toggleConfirmVisibility() {
    _confirmVisible = !_confirmVisible;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  // ── Step ──────────────────────────────────────────────────────
  CpStep _step = CpStep.form;
  CpStep get step => _step;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // ── Password analysis ─────────────────────────────────────────
  PasswordStrength _strength = PasswordStrength.empty;
  PasswordStrength get strength => _strength;

  bool _hasMin = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  bool get hasMin => _hasMin;
  bool get hasUpper => _hasUpper;
  bool get hasLower => _hasLower;
  bool get hasNumber => _hasNumber;
  bool get hasSpecial => _hasSpecial;

  void analyzePassword(String pwd) {
    _hasMin = pwd.length >= 8;
    _hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    _hasLower = pwd.contains(RegExp(r'[a-z]'));
    _hasNumber = pwd.contains(RegExp(r'[0-9]'));
    _hasSpecial = pwd.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));

    final score = [
      _hasMin,
      _hasUpper,
      _hasLower,
      _hasNumber,
      _hasSpecial,
    ].where((b) => b).length;

    if (pwd.isEmpty) {
      _strength = PasswordStrength.empty;
    } else if (score <= 1) {
      _strength = PasswordStrength.weak;
    } else if (score == 2) {
      _strength = PasswordStrength.fair;
    } else if (score <= 4) {
      _strength = PasswordStrength.good;
    } else {
      _strength = PasswordStrength.strong;
    }

    notifyListeners();
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    _step = CpStep.loading;
    _errorMessage = '';
    HapticFeedback.mediumImpact();
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No authenticated user found.',
        );
      }

      // Re-authenticate first (Firebase requires this before password change)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update the password in Firebase Auth
      await user.updatePassword(newPassword);

      // ✅ Update passwordLastChanged field in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'passwordLastChanged': FieldValue.serverTimestamp(),
      });

      _step = CpStep.success;
      HapticFeedback.heavyImpact();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapError(e.code);
      _step = CpStep.error;
      HapticFeedback.vibrate();
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));
      _step = CpStep.form;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _step = CpStep.error;
      HapticFeedback.vibrate();
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 120));
      _step = CpStep.form;
      notifyListeners();
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect. Please try again.';
      case 'weak-password':
        return 'New password is too weak. Use at least 8 characters.';
      case 'requires-recent-login':
        return 'Session expired. Please log out and sign in again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'no-user':
        return 'No authenticated user found. Please sign in again.';
      default:
        return 'Failed to update password. Please try again.';
    }
  }

  void reset() {
    _step = CpStep.form;
    _errorMessage = '';
    _strength = PasswordStrength.empty;
    _hasMin = false;
    _hasUpper = false;
    _hasLower = false;
    _hasNumber = false;
    _hasSpecial = false;
    _currentVisible = false;
    _newVisible = false;
    _confirmVisible = false;
    notifyListeners();
  }
}

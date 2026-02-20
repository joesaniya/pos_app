import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CREATE ACCOUNT PROVIDER
//  Holds all business logic, state, and Firebase calls.
//  UI layer should only call methods and read state from here.
// ─────────────────────────────────────────────────────────────────────────────

enum CreateAccountStatus { idle, loading, success, error }

class CreateAccountProvider extends ChangeNotifier {
  // ── Firestore ──────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── State ──────────────────────────────────────────────────────
  CreateAccountStatus _status = CreateAccountStatus.idle;
  String _selectedRole = '';
  bool _pwdVisible = false;
  bool _confirmVisible = false;
  String _errorMessage = '';

  // New staff details after successful creation (used in success screen)
  String _createdName = '';
  String _createdEmail = '';
  String _createdRole = '';

  // ── Getters ────────────────────────────────────────────────────
  CreateAccountStatus get status => _status;
  String get selectedRole => _selectedRole;
  bool get pwdVisible => _pwdVisible;
  bool get confirmVisible => _confirmVisible;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CreateAccountStatus.loading;
  bool get isSuccess => _status == CreateAccountStatus.success;

  String get createdName => _createdName;
  String get createdEmail => _createdEmail;
  String get createdRole => _createdRole;

  bool get isRoleSelected => _selectedRole.isNotEmpty;

  // ── Role selection ─────────────────────────────────────────────
  void selectRole(String role) {
    if (_selectedRole == role) return;
    _selectedRole = role;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Visibility toggles ─────────────────────────────────────────
  void togglePasswordVisibility() {
    _pwdVisible = !_pwdVisible;
    notifyListeners();
  }

  void toggleConfirmVisibility() {
    _confirmVisible = !_confirmVisible;
    notifyListeners();
  }

  // ── Reset ──────────────────────────────────────────────────────
  void reset() {
    _status = CreateAccountStatus.idle;
    _selectedRole = '';
    _pwdVisible = false;
    _confirmVisible = false;
    _errorMessage = '';
    _createdName = '';
    _createdEmail = '';
    _createdRole = '';
    notifyListeners();
  }

  // ── Submit / Firebase ──────────────────────────────────────────
  Future<bool> createAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String businessId,
    required String businessName,
  }) async {
    if (!isRoleSelected) {
      _setError('Please select a role to continue.');
      return false;
    }

    // Explicit mandatory field guards (defence-in-depth beyond form validators)
    if (name.trim().isEmpty) {
      _setError('Full name is required.');
      return false;
    }
    if (email.trim().isEmpty) {
      _setError('Email address is required.');
      return false;
    }
    if (phone.trim().isEmpty || phone.trim().length < 10) {
      _setError('A valid 10-digit phone number is required.');
      return false;
    }
    if (password.isEmpty || password.length < 6) {
      _setError('Password must be at least 6 characters.');
      return false;
    }

    _status = CreateAccountStatus.loading;
    _errorMessage = '';
    notifyListeners();
    HapticFeedback.mediumImpact();

    try {
      // 1. Create Firebase Auth user
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Update display name
      await cred.user?.updateDisplayName(name.trim());

      // 3. Store user doc in Firestore
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': _selectedRole,
        'businessId': businessId,
        'businessName': businessName,
        'isActive': true,
        'profilePhoto': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? 'system',
      });

      // 4. Send verification email
      await cred.user?.sendEmailVerification();

      // 5. Cache info for success screen
      _createdName = name.trim();
      _createdEmail = email.trim();
      _createdRole = _selectedRole;

      _status = CreateAccountStatus.success;
      HapticFeedback.heavyImpact();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
      return false;
    } catch (_) {
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  void _setError(String msg) {
    _errorMessage = msg;
    _status = CreateAccountStatus.error;
    notifyListeners();
  }

  void clearError() {
    if (_status == CreateAccountStatus.error) {
      _status = CreateAccountStatus.idle;
      _errorMessage = '';
      notifyListeners();
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'An error occurred.';
    }
  }
}

/*import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CREATE ACCOUNT PROVIDER
//  Holds all business logic, state, and Firebase calls.
//  UI layer should only call methods and read state from here.
// ─────────────────────────────────────────────────────────────────────────────

enum CreateAccountStatus { idle, loading, success, error }

class CreateAccountProvider extends ChangeNotifier {
  // ── Firestore ──────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── State ──────────────────────────────────────────────────────
  CreateAccountStatus _status = CreateAccountStatus.idle;
  String _selectedRole = '';
  bool _pwdVisible = false;
  bool _confirmVisible = false;
  String _errorMessage = '';

  // New staff details after successful creation (used in success screen)
  String _createdName = '';
  String _createdEmail = '';
  String _createdRole = '';

  // ── Getters ────────────────────────────────────────────────────
  CreateAccountStatus get status => _status;
  String get selectedRole => _selectedRole;
  bool get pwdVisible => _pwdVisible;
  bool get confirmVisible => _confirmVisible;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CreateAccountStatus.loading;
  bool get isSuccess => _status == CreateAccountStatus.success;

  String get createdName => _createdName;
  String get createdEmail => _createdEmail;
  String get createdRole => _createdRole;

  bool get isRoleSelected => _selectedRole.isNotEmpty;

  // ── Role selection ─────────────────────────────────────────────
  void selectRole(String role) {
    if (_selectedRole == role) return;
    _selectedRole = role;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Visibility toggles ─────────────────────────────────────────
  void togglePasswordVisibility() {
    _pwdVisible = !_pwdVisible;
    notifyListeners();
  }

  void toggleConfirmVisibility() {
    _confirmVisible = !_confirmVisible;
    notifyListeners();
  }

  // ── Reset ──────────────────────────────────────────────────────
  void reset() {
    _status = CreateAccountStatus.idle;
    _selectedRole = '';
    _pwdVisible = false;
    _confirmVisible = false;
    _errorMessage = '';
    _createdName = '';
    _createdEmail = '';
    _createdRole = '';
    notifyListeners();
  }

  // ── Submit / Firebase ──────────────────────────────────────────
  Future<bool> createAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String businessId,
    required String businessName,
  }) async {
    if (!isRoleSelected) {
      _setError('Please select a role to continue.');
      return false;
    }

    _status = CreateAccountStatus.loading;
    _errorMessage = '';
    notifyListeners();
    HapticFeedback.mediumImpact();

    try {
      // 1. Create Firebase Auth user
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Update display name
      await cred.user?.updateDisplayName(name.trim());

      // 3. Store user doc in Firestore
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': _selectedRole,
        'businessId': businessId,
        'businessName': businessName,
        'isActive': true,
        'profilePhoto': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? 'system',
      });

      // 4. Send verification email
      await cred.user?.sendEmailVerification();

      // 5. Cache info for success screen
      _createdName = name.trim();
      _createdEmail = email.trim();
      _createdRole = _selectedRole;

      _status = CreateAccountStatus.success;
      HapticFeedback.heavyImpact();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
      return false;
    } catch (_) {
      _setError('Something went wrong. Please try again.');
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  void _setError(String msg) {
    _errorMessage = msg;
    _status = CreateAccountStatus.error;
    notifyListeners();
  }

  void clearError() {
    if (_status == CreateAccountStatus.error) {
      _status = CreateAccountStatus.idle;
      _errorMessage = '';
      notifyListeners();
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'An error occurred.';
    }
  }
}*/

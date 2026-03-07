import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum CreateAccountStatus { idle, loading, success, error }

class CreateAccountProvider extends ChangeNotifier {
  // ── Firestore / Auth ───────────────────────────────────────────
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
    log(
      'Starting account creation for email: $email, phone: $phone, businessId: $businessId',
    );
    if (!isRoleSelected) {
      _setError('Please select a role to continue.');
      return false;
    }
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
    log('Passed basic validation for email: $email, phone: $phone');
    try {
      log('Checking subscription limits for businessId: $businessId');
      final subDoc = await _db
          .collection('subscriptions')
          .doc(businessId)
          .get();
      log(
        'Fetched subscription doc for businessId $businessId: exists=${subDoc.exists}',
      );
      if (subDoc.exists) {
        log('Subscription doc data: ${subDoc.data()}');
        final subData = subDoc.data()!;
        final maxUsers = subData['maxUsers'] as int? ?? 0;
        log('Subscription maxUsers: $maxUsers');
        if (maxUsers > 0) {
          // Use a simple query + client-side filter to avoid composite-index issues
          // that arise when combining isEqualTo + isNotEqualTo in Firestore count().
          final usersSnap = await _db
              .collection('users')
              .where('businessId', isEqualTo: businessId)
              .where('isActive', isEqualTo: true)
              .get();
          // Exclude soft-deleted users on the client side
          final count = usersSnap.docs
              .where((d) => d.data()['isDeleted'] != true)
              .length;
          if (count >= maxUsers) {
            _setError(
              'Maximum user limit of $maxUsers has been reached for your current plan. '
              'Once the user completes payment and the plan is renewed, '
              'new users can be added again.',
            );
            return false;
          }
        }
      }
    } catch (_) {}

    _status = CreateAccountStatus.loading;
    _errorMessage = '';
    notifyListeners();
    HapticFeedback.mediumImpact();

    // ── Capture admin context BEFORE any Firebase auth calls ──────
    // The primary _auth.currentUser is the logged-in admin.
    // We capture everything we need now so we never lose it.
    final User? adminUser = _auth.currentUser;
    if (adminUser == null) {
      _setError('Session expired. Please log in again.');
      return false;
    }
    final String adminUid = adminUser.uid;

    // ── Fetch admin name + role from Firestore ────────────────────
    String createdByName = '';
    String createdByRole = '';
    try {
      final adminDoc = await _db.collection('users').doc(adminUid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        createdByName = adminDoc.data()!['name'] ?? '';
        createdByRole = adminDoc.data()!['role'] ?? '';
      }
    } catch (e) {
      debugPrint('Failed to fetch admin info: $e');
      // Non-fatal — continue with empty strings
    }

    // ── Use a secondary Firebase App to avoid session hijack ──────
    //
    // FirebaseAuth.createUserWithEmailAndPassword() automatically signs
    // in the newly created user on the DEFAULT app instance, which would
    // log out the currently logged-in admin/owner. To prevent this, we
    // initialise a short-lived secondary Firebase App, create the user
    // there, then immediately delete the secondary app. The primary app's
    // auth state is never touched.
    //
    FirebaseApp? secondaryApp;
    try {
      // Use a unique name to avoid collisions if called concurrently
      final String secondaryAppName =
          'secondary_create_${DateTime.now().millisecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options, // reuse the same Firebase project
      );

      final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(
        app: secondaryApp,
      );

      // 1. Create the new Firebase Auth user on the secondary instance
      //    — this does NOT affect _auth.currentUser (the admin session)
      final UserCredential cred = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final User? newUser = cred.user;
      if (newUser == null) {
        _setError('Something went wrong. Please try again.');
        return false;
      }

      final String newUid = newUser.uid;

      // 2. Update display name on the secondary instance
      await newUser.updateDisplayName(name.trim());

      // 3. Send verification email via the secondary instance
      await newUser.sendEmailVerification();

      // 4. Sign out from the secondary instance (clean up)
      await secondaryAuth.signOut();

      // 5. Store Firestore user document
      //    Uses the primary _db — no auth dependency for Firestore writes
      //    as long as Firestore rules allow it (admin is still logged in
      //    on the primary app, so request.auth is the admin's UID).
      await _db.collection('users').doc(newUid).set({
        'uid': newUid,
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
        'createdBy': adminUid, // always the admin's UID ✅
        'createdByName': createdByName,
        'createdByRole': createdByRole,
        'passwordLastChanged': FieldValue.serverTimestamp(),
      });

      // 6. Verify admin is still logged in (sanity check)
      assert(
        _auth.currentUser?.uid == adminUid,
        'Admin session must remain unchanged after account creation',
      );

      // 7. Cache info for success screen
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
    } catch (e) {
      debugPrint('createAccount error: $e');
      _setError('Something went wrong. Please try again.');
      return false;
    } finally {
      // Always delete the secondary app to free resources,
      // regardless of success or failure
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (e) {
          debugPrint('Failed to delete secondary Firebase app: $e');
        }
      }
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

    // Capture admin UID BEFORE createUserWithEmailAndPassword
    // (Firebase switches currentUser to the new user after that call)
    final String adminUid = _auth.currentUser?.uid ?? 'system';

    // ── Fetch admin name + role from Firestore BEFORE creating new user ──
    String createdByName = '';
    String createdByRole = '';
    try {
      final adminDoc = await _db.collection('users').doc(adminUid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        createdByName = adminDoc.data()!['name'] ?? '';
        createdByRole = adminDoc.data()!['role'] ?? '';
      }
    } catch (e) {
      debugPrint('Failed to fetch admin info: $e');
      // Non-fatal — continue with empty strings
    }

    try {
      // 1. Create Firebase Auth user ← currentUser switches to new user here
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final String newUid = cred.user!.uid;

      // 2. Update display name for the new user
      await cred.user?.updateDisplayName(name.trim());

      // 3. Store user doc
      await _db.collection('users').doc(newUid).set({
        'uid': newUid,
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
        'createdBy': adminUid,
        'createdByName': createdByName, // ← stored ✅
        'createdByRole': createdByRole, // ← stored ✅
        'passwordLastChanged': FieldValue.serverTimestamp(),
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

  Future<bool> createAccount1({
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

    try {
      final subDoc = await _db.collection('subscriptions').doc(businessId).get();
      if (subDoc.exists) {
        final subData = subDoc.data()!;
        final maxUsers = subData['maxUsers'] as int? ?? 0;
        if (maxUsers > 0) {
          final countQuery = await _db.collection('users')
             .where('businessId', isEqualTo: businessId)
             .where('isActive', isEqualTo: true)
             .where('isDeleted', isNotEqualTo: true)
             .count()
             .get();
          final count = countQuery.count;
          if (count != null && count >= maxUsers) {
            _setError('User limit reached. Please upgrade your plan to add more users.');
            return false;
          }
        }
      }
    } catch (_) {}

    _status = CreateAccountStatus.loading;
    _errorMessage = '';
    notifyListeners();
    HapticFeedback.mediumImpact();

    // ─────────────────────────────────────────────────────────────────
    // FIX: Capture admin UID BEFORE calling createUserWithEmailAndPassword.
    // Firebase automatically switches _auth.currentUser to the newly
    // created user after that call — so reading it AFTER would return
    // the new staff member's UID, not the admin who created the account.
    // ─────────────────────────────────────────────────────────────────
    final String adminUid = _auth.currentUser?.uid ?? 'system';

    try {
      // 1. Create Firebase Auth user  ← currentUser switches to new user here
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final String newUid = cred.user!.uid;

      // 2. Update display name for the new user
      await cred.user?.updateDisplayName(name.trim());

      // 3. Store user doc — adminUid is used for createdBy (captured above)
      await _db.collection('users').doc(newUid).set({
        'uid': newUid,
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
        'createdBy': adminUid, // ← always the admin's UID ✅
        'passwordLastChanged': FieldValue.serverTimestamp(),
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
*/
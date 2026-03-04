import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String profilePhoto;
  final bool isActive;
  final String businessId;
  final String businessName;
  final DateTime? createdAt;
  final String createdByName;
  final String createdByRole;

  const EmployeeModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.profilePhoto,
    required this.isActive,
    required this.businessId,
    required this.businessName,
    this.createdAt,
    required this.createdByName,
    required this.createdByRole,
  });

  factory EmployeeModel.fromMap(String uid, Map<String, dynamic> d) {
    DateTime? createdAt;
    final raw = d['createdAt'];
    if (raw is Timestamp) createdAt = raw.toDate();

    return EmployeeModel(
      uid: uid,
      name: d['name'] ?? 'Unknown',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      role: d['role'] ?? 'staff',
      profilePhoto: d['profilePhoto'] ?? '',
      isActive: d['isActive'] == true,
      businessId: d['businessId'] ?? '',
      businessName: d['businessName'] ?? '',
      createdAt: createdAt,
      createdByName: d['createdByName'] ?? '',
      createdByRole: d['createdByRole'] ?? '',
    );
  }

  EmployeeModel copyWith({bool? isActive}) => EmployeeModel(
    uid: uid,
    name: name,
    email: email,
    phone: phone,
    role: role,
    profilePhoto: profilePhoto,
    isActive: isActive ?? this.isActive,
    businessId: businessId,
    businessName: businessName,
    createdAt: createdAt,
    createdByName: createdByName,
    createdByRole: createdByRole,
  );

  String get initials {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get joinedLabel {
    if (createdAt == null) return 'Unknown';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${createdAt!.day} ${m[createdAt!.month - 1]} ${createdAt!.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeManagementProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = StorageService.instance;

  List<EmployeeModel> _all = [];
  bool _loading = false;
  bool _deleting = false;
  String? _error;
  String _search = '';
  String _roleFilter = 'All';
  String _currentUid = '';
  String _currentRole = '';
  String _businessId = '';

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading => _loading;
  bool get isDeleting => _deleting;
  String? get error => _error;
  String get searchQuery => _search;
  String get roleFilter => _roleFilter;
  String get currentUid => _currentUid;
  String get currentRole => _currentRole;

  static const List<String> privilegedRoles = [
    'owner',
    'system',
    'admin',
    'manager',
  ];

  bool get canManage => privilegedRoles.contains(_currentRole.toLowerCase());

  // NOTE: We show ALL employees in the same business — including the current
  // user themselves so managers/owners can see their own entry in the list.
  // We only mark the current user's row with an "(You)" indicator in the UI.
  List<EmployeeModel> get employees {
    var list = [..._all]; // show everyone, including self

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.email.toLowerCase().contains(q) ||
                e.role.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_roleFilter != 'All') {
      list = list
          .where((e) => e.role.toLowerCase() == _roleFilter.toLowerCase())
          .toList();
    }

    // Sort: active first → self first within active → then alphabetical
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      // Put "self" at top of their group
      final aSelf = a.uid == _currentUid ? 0 : 1;
      final bSelf = b.uid == _currentUid ? 0 : 1;
      if (aSelf != bSelf) return aSelf - bSelf;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  int get totalCount => _all.length;
  int get activeCount => _all.where((e) => e.isActive).length;
  int get inactiveCount => _all.where((e) => !e.isActive).length;

  /// Whether this UID is the currently logged-in user (for "(You)" badge)
  bool isSelf(String uid) => uid == _currentUid;

  List<String> get availableRoles {
    final roles = _all.map((e) => _capitalize(e.role)).toSet().toList()..sort();
    return ['All', ...roles];
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final stored = await _storage.getUserData();
    _currentUid = stored['uid'] ?? '';
    _currentRole = stored['role'] ?? '';
    _businessId = stored['businessId'] ?? '';

    if (_businessId.isEmpty || _currentUid.isEmpty) {
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        final doc = await _db.collection('users').doc(fbUser.uid).get();
        if (doc.exists) {
          _currentUid = fbUser.uid;
          _currentRole = doc.data()?['role'] ?? '';
          _businessId = doc.data()?['businessId'] ?? '';
        }
      }
    }

    log(
      'EmpProvider init: uid=$_currentUid role=$_currentRole biz=$_businessId',
    );

    if (canManage && _businessId.isNotEmpty) {
      await loadEmployees();
    }
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadEmployees() async {
    if (!canManage || _businessId.isEmpty) {
      log(
        'EmpProvider: skipping load — canManage=$canManage businessId=$_businessId',
      );
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      log('EmpProvider: querying users where businessId == "$_businessId"');

      final snap = await _db
          .collection('users')
          .where('businessId', isEqualTo: _businessId)
          .get();

      log('EmpProvider: raw Firestore result = ${snap.docs.length} docs');
      for (final d in snap.docs) {
        log(
          '  → doc ${d.id}: name=${d['name']} role=${d['role']} '
          'businessId=${d['businessId']} isDeleted=${d.data()['isDeleted']}',
        );
      }

      _all = snap.docs
          .where((d) => d.data()['isDeleted'] != true)
          .map((d) => EmployeeModel.fromMap(d.id, d.data()))
          .toList();

      log('EmpProvider: after filter = ${_all.length} employees');
    } catch (e) {
      _error = 'Failed to load employees: $e';
      debugPrint('loadEmployees error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void setSearch(String q) {
    _search = q;
    notifyListeners();
  }

  void setRoleFilter(String r) {
    _roleFilter = r;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _roleFilter = 'All';
    notifyListeners();
  }

  // ── Delete permission check ────────────────────────────────────────────────
  bool canDelete(EmployeeModel e) {
    if (!canManage) return false;
    if (e.uid == _currentUid) return false; // can't delete self

    final my = _currentRole.toLowerCase();
    final target = e.role.toLowerCase();

    if (my == 'system') return true;
    if (my == 'owner' || my == 'admin') {
      return target != 'owner' && target != 'system';
    }
    if (my == 'manager') {
      return target != 'owner' &&
          target != 'system' &&
          target != 'admin' &&
          target != 'manager';
    }
    return false;
  }

  // ── Toggle active ──────────────────────────────────────────────────────────
  bool canToggle(EmployeeModel e) {
    if (!canManage || e.uid == _currentUid) return false; // can't toggle self
    final my = _currentRole.toLowerCase();
    final target = e.role.toLowerCase();
    if (my == 'system' || my == 'owner' || my == 'admin') return true;
    if (my == 'manager') {
      return target != 'owner' && target != 'system' && target != 'admin';
    }
    return false;
  }

  Future<bool> toggleStatus(EmployeeModel emp) async {
    if (!canToggle(emp)) {
      debugPrint('toggleStatus: canToggle() returned false for ${emp.name}');
      return false;
    }
    try {
      final newVal = !emp.isActive;
      await _db.collection('users').doc(emp.uid).update({
        'isActive': newVal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final idx = _all.indexWhere((e) => e.uid == emp.uid);
      if (idx != -1) _all[idx] = _all[idx].copyWith(isActive: newVal);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('toggleStatus ERROR: $e'); // ← will show exact Firestore error
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEmployee(EmployeeModel emp) async {
    if (!canDelete(emp)) {
      debugPrint('deleteEmployee: canDelete() returned false for ${emp.name}');
      return false;
    }
    _deleting = true;
    _error = null;
    notifyListeners();

    try {
      await _db.collection('users').doc(emp.uid).update({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _all.removeWhere((e) => e.uid == emp.uid);
      return true;
    } catch (e) {
      debugPrint(
        'deleteEmployee ERROR: $e',
      ); // ← will show exact Firestore error
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  Future<bool> toggleStatus1(EmployeeModel emp) async {
    if (!canToggle(emp)) return false;
    try {
      final newVal = !emp.isActive;
      await _db.collection('users').doc(emp.uid).update({
        'isActive': newVal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final idx = _all.indexWhere((e) => e.uid == emp.uid);
      if (idx != -1) _all[idx] = _all[idx].copyWith(isActive: newVal);
      notifyListeners();
      log('Toggled ${emp.name} → isActive=$newVal');
      return true;
    } catch (e) {
      debugPrint('toggleStatus error: $e');
      return false;
    }
  }

  // ── Delete (soft) ──────────────────────────────────────────────────────────
  Future<bool> deleteEmployee1(EmployeeModel emp) async {
    if (!canDelete(emp)) return false;
    _deleting = true;
    notifyListeners();

    try {
      await _db.collection('users').doc(emp.uid).update({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _all.removeWhere((e) => e.uid == emp.uid);
      log('Deleted employee: ${emp.name}');
      return true;
    } catch (e) {
      debugPrint('deleteEmployee error: $e');
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadEmployees();

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}


/*except ur profile in employee sec import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String profilePhoto;
  final bool isActive;
  final String businessId;
  final String businessName;
  final DateTime? createdAt;
  final String createdByName;
  final String createdByRole;

  const EmployeeModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.profilePhoto,
    required this.isActive,
    required this.businessId,
    required this.businessName,
    this.createdAt,
    required this.createdByName,
    required this.createdByRole,
  });

  factory EmployeeModel.fromMap(String uid, Map<String, dynamic> d) {
    DateTime? createdAt;
    final raw = d['createdAt'];
    if (raw is Timestamp) createdAt = raw.toDate();

    return EmployeeModel(
      uid:           uid,
      name:          d['name']          ?? 'Unknown',
      email:         d['email']         ?? '',
      phone:         d['phone']         ?? '',
      role:          d['role']          ?? 'staff',
      profilePhoto:  d['profilePhoto']  ?? '',
      isActive:      d['isActive']      == true,
      businessId:    d['businessId']    ?? '',
      businessName:  d['businessName']  ?? '',
      createdAt:     createdAt,
      createdByName: d['createdByName'] ?? '',
      createdByRole: d['createdByRole'] ?? '',
    );
  }

  EmployeeModel copyWith({bool? isActive}) => EmployeeModel(
    uid: uid, name: name, email: email, phone: phone, role: role,
    profilePhoto: profilePhoto,
    isActive: isActive ?? this.isActive,
    businessId: businessId, businessName: businessName,
    createdAt: createdAt, createdByName: createdByName,
    createdByRole: createdByRole,
  );

  String get initials {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get joinedLabel {
    if (createdAt == null) return 'Unknown';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${createdAt!.day} ${m[createdAt!.month - 1]} ${createdAt!.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeManagementProvider extends ChangeNotifier {
  final _db      = FirebaseFirestore.instance;
  final _auth    = FirebaseAuth.instance;
  final _storage = StorageService.instance;

  List<EmployeeModel> _all     = [];
  bool   _loading              = false;
  bool   _deleting             = false;
  String? _error;
  String _search               = '';
  String _roleFilter           = 'All';
  String _currentUid           = '';
  String _currentRole          = '';
  String _businessId           = '';

  // ── Getters ────────────────────────────────────────────────────────────────
  bool   get isLoading  => _loading;
  bool   get isDeleting => _deleting;
  String? get error     => _error;
  String get searchQuery  => _search;
  String get roleFilter   => _roleFilter;
  String get currentUid   => _currentUid;
  String get currentRole  => _currentRole;

  static const List<String> privilegedRoles = ['owner', 'system', 'admin', 'manager'];

  bool get canManage => privilegedRoles.contains(_currentRole.toLowerCase());

  List<EmployeeModel> get employees {
    var list = _all.where((e) => e.uid != _currentUid).toList();

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
          e.name.toLowerCase().contains(q)  ||
          e.email.toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q)).toList();
    }

    if (_roleFilter != 'All') {
      list = list.where((e) => e.role.toLowerCase() == _roleFilter.toLowerCase()).toList();
    }

    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  int get totalCount    => _all.where((e) => e.uid != _currentUid).length;
  int get activeCount   => _all.where((e) => e.uid != _currentUid && e.isActive).length;
  int get inactiveCount => _all.where((e) => e.uid != _currentUid && !e.isActive).length;

  List<String> get availableRoles {
    final roles = _all.map((e) => _capitalize(e.role)).toSet().toList()..sort();
    return ['All', ...roles];
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final stored = await _storage.getUserData();
    _currentUid  = stored['uid']        ?? '';
    _currentRole = stored['role']       ?? '';
    _businessId  = stored['businessId'] ?? '';

    if (_businessId.isEmpty || _currentUid.isEmpty) {
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        final doc = await _db.collection('users').doc(fbUser.uid).get();
        if (doc.exists) {
          _currentUid  = fbUser.uid;
          _currentRole = doc.data()?['role']       ?? '';
          _businessId  = doc.data()?['businessId'] ?? '';
        }
      }
    }

    log('EmpProvider init: uid=$_currentUid role=$_currentRole biz=$_businessId');

    if (canManage && _businessId.isNotEmpty) {
      await loadEmployees();
    }
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadEmployees() async {
    if (!canManage || _businessId.isEmpty) return;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final snap = await _db
          .collection('users')
          .where('businessId', isEqualTo: _businessId)
          .get();

      _all = snap.docs
          .where((d) => d.data()['isDeleted'] != true)
          .map((d) => EmployeeModel.fromMap(d.id, d.data()))
          .toList();

      log('Loaded ${_all.length} employees');
    } catch (e) {
      _error = 'Failed to load employees: $e';
      debugPrint('loadEmployees error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void setSearch(String q)      { _search = q;      notifyListeners(); }
  void setRoleFilter(String r)  { _roleFilter = r;  notifyListeners(); }
  void clearFilters()           { _search = ''; _roleFilter = 'All'; notifyListeners(); }

  // ── Delete permission check ────────────────────────────────────────────────
  bool canDelete(EmployeeModel e) {
    if (!canManage) return false;
    if (e.uid == _currentUid) return false;

    final my     = _currentRole.toLowerCase();
    final target = e.role.toLowerCase();

    if (my == 'system') return true;
    if (my == 'owner' || my == 'admin') {
      return target != 'owner' && target != 'system';
    }
    if (my == 'manager') {
      return target != 'owner' && target != 'system' &&
             target != 'admin' && target != 'manager';
    }
    return false;
  }

  // ── Toggle active ──────────────────────────────────────────────────────────
  bool canToggle(EmployeeModel e) {
    if (!canManage || e.uid == _currentUid) return false;
    final my     = _currentRole.toLowerCase();
    final target = e.role.toLowerCase();
    if (my == 'system' || my == 'owner' || my == 'admin') return true;
    if (my == 'manager') {
      return target != 'owner' && target != 'system' && target != 'admin';
    }
    return false;
  }

  Future<bool> toggleStatus(EmployeeModel emp) async {
    if (!canToggle(emp)) return false;
    try {
      final newVal = !emp.isActive;
      await _db.collection('users').doc(emp.uid).update({
        'isActive': newVal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final idx = _all.indexWhere((e) => e.uid == emp.uid);
      if (idx != -1) _all[idx] = _all[idx].copyWith(isActive: newVal);
      notifyListeners();
      log('Toggled ${emp.name} → isActive=$newVal');
      return true;
    } catch (e) {
      debugPrint('toggleStatus error: $e');
      return false;
    }
  }

  // ── Delete (soft) ──────────────────────────────────────────────────────────
  Future<bool> deleteEmployee(EmployeeModel emp) async {
    if (!canDelete(emp)) return false;
    _deleting = true;
    notifyListeners();

    try {
      await _db.collection('users').doc(emp.uid).update({
        'isActive':  false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _all.removeWhere((e) => e.uid == emp.uid);
      log('Deleted employee: ${emp.name}');
      return true;
    } catch (e) {
      debugPrint('deleteEmployee error: $e');
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadEmployees();

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}*/
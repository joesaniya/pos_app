import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pos_app/models/tax_slab_model.dart';
import 'package:pos_app/repositories/tax_repository.dart';
import 'package:pos_app/services/storage_service.dart';

enum TaxProviderStatus { idle, loading, success, error }

class TaxProvider extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  //  DEPENDENCIES
  // ══════════════════════════════════════════════════════════════════════════

  final TaxRepository _repository = TaxRepository.instance;
  final StorageService _storage = StorageService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  //  STATE
  // ══════════════════════════════════════════════════════════════════════════

  TaxProviderStatus _status = TaxProviderStatus.idle;
  String? _error;
  List<TaxSlab> _taxSlabs = [];
  TaxSlab? _selectedTaxSlab;
  bool _isLoading = false;

  // User context
  String _businessId = '';
  String _uid = '';
  String _name = '';
  String? _email;
  String _role = '';

  // ══════════════════════════════════════════════════════════════════════════
  //  GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  TaxProviderStatus get status => _status;
  String? get error => _error;
  List<TaxSlab> get taxSlabs => _taxSlabs;
  TaxSlab? get selectedTaxSlab => _selectedTaxSlab;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;

  String get businessId => _businessId;

  // Filter getters
  List<TaxSlab> get activeTaxSlabs =>
      _taxSlabs.where((tax) => tax.isActive).toList();

  List<TaxSlab> get inactiveTaxSlabs =>
      _taxSlabs.where((tax) => !tax.isActive).toList();

  TaxSlab? getDefaultTaxSlab() {
    // Return first active tax slab as default
    if (activeTaxSlabs.isEmpty) return null;
    return activeTaxSlabs.first;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await _loadUserContext();
    if (_businessId.isNotEmpty) {
      await loadTaxSlabs();
    }
  }

  Future<void> _loadUserContext() async {
    try {
      final userData = await _storage.getUserData();
      _uid = userData['uid'] as String? ?? '';
      _businessId = userData['businessId'] as String? ?? '';
      _name = userData['name'] as String? ?? '';
      _email = userData['email'] as String?;
      _role = userData['role'] as String? ?? 'staff';

      log('[TaxProvider] User context loaded: biz=$_businessId role=$_role');
    } catch (e) {
      log('[TaxProvider] Error loading user context: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CORE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Load all active tax slabs for the business
  Future<void> loadTaxSlabs() async {
    if (_businessId.isEmpty) {
      _setError('Business ID not initialized');
      return;
    }

    _setStatus(TaxProviderStatus.loading);

    try {
      _taxSlabs = await _repository.getTaxSlabsForBusiness(_businessId);
      _setStatus(TaxProviderStatus.success);
      log('[TaxProvider] ✅ Loaded ${_taxSlabs.length} tax slabs');
    } catch (e) {
      _setError('Failed to load tax slabs: $e');
      log('[TaxProvider] ❌ Error loading tax slabs: $e');
    }
  }

  /// Load all tax slabs including inactive ones
  Future<void> loadAllTaxSlabs() async {
    if (_businessId.isEmpty) {
      _setError('Business ID not initialized');
      return;
    }

    _setStatus(TaxProviderStatus.loading);

    try {
      _taxSlabs = await _repository.getAllTaxSlabsForBusiness(_businessId);
      _setStatus(TaxProviderStatus.success);
      log(
        '[TaxProvider] ✅ Loaded ${_taxSlabs.length} tax slabs (including inactive)',
      );
    } catch (e) {
      _setError('Failed to load all tax slabs: $e');
      log('[TaxProvider] ❌ Error loading all tax slabs: $e');
    }
  }

  /// Create a new tax slab (Owner/Manager only)
  Future<TaxSlab?> createTaxSlab({
    required String name,
    required double percentage,
    required TaxType type,
    String? description,
  }) async {
    // Permission check
    if (!_canModifyTax()) {
      _setError('You do not have permission to create tax slabs');
      return null;
    }

    if (_businessId.isEmpty) {
      _setError('Business ID not initialized');
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final created = await _repository.createTaxSlab(
        businessId: _businessId,
        name: name,
        percentage: percentage,
        type: type,
        description: description,
        createdByUid: _uid,
        createdByName: _name,
        createdByEmail: _email,
        createdByRole: _role,
      );

      if (created != null) {
        _taxSlabs.add(created);
        _sortTaxSlabs();
        _isLoading = false;
        _clearError();
        notifyListeners();
        log('[TaxProvider] ✅ Tax slab created: $name');
        return created;
      }
    } catch (e) {
      _setError('Failed to create tax slab: $e');
      log('[TaxProvider] ❌ Error creating tax slab: $e');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Update existing tax slab (Owner/Manager only)
  Future<TaxSlab?> updateTaxSlab({
    required TaxSlab taxSlab,
    String? name,
    double? percentage,
    TaxType? type,
    String? description,
    bool? isActive,
  }) async {
    // Permission check
    if (!_canModifyTax()) {
      _setError('You do not have permission to update tax slabs');
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final updated = taxSlab.copyWith(
        name: name,
        percentage: percentage,
        type: type,
        description: description,
        isActive: isActive,
      );

      final result = await _repository.updateTaxSlab(
        taxSlab: updated,
        updatedByUid: _uid,
        updatedByName: _name,
        updatedByRole: _role,
      );

      if (result != null) {
        final index = _taxSlabs.indexWhere((t) => t.id == taxSlab.id);
        if (index >= 0) {
          _taxSlabs[index] = result;
        }
        _isLoading = false;
        _clearError();
        notifyListeners();
        log('[TaxProvider] ✅ Tax slab updated: ${result.name}');
        return result;
      }
    } catch (e) {
      _setError('Failed to update tax slab: $e');
      log('[TaxProvider] ❌ Error updating tax slab: $e');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Toggle tax slab status (Owner/Manager only)
  Future<void> toggleTaxSlabStatus({
    required String taxSlabId,
    required bool isActive,
  }) async {
    // Permission check
    if (!_canModifyTax()) {
      _setError('You do not have permission to modify tax slabs');
      return;
    }

    try {
      await _repository.toggleTaxSlabStatus(
        taxSlabId: taxSlabId,
        isActive: isActive,
        updatedByUid: _uid,
        updatedByName: _name,
        updatedByRole: _role,
      );

      final index = _taxSlabs.indexWhere((t) => t.id == taxSlabId);
      if (index >= 0) {
        _taxSlabs[index] = _taxSlabs[index].copyWith(isActive: isActive);
      }

      _clearError();
      notifyListeners();
      log('[TaxProvider] ✅ Tax slab status toggled');
    } catch (e) {
      _setError('Failed to toggle tax slab status: $e');
      log('[TaxProvider] ❌ Error toggling tax slab status: $e');
    }
  }

  /// Delete tax slab (Owner only)
  Future<void> deleteTaxSlab(String taxSlabId) async {
    // Permission check (only owner)
    if (_role != 'owner') {
      _setError('Only owners can delete tax slabs');
      return;
    }

    try {
      await _repository.deleteTaxSlab(taxSlabId);
      _taxSlabs.removeWhere((t) => t.id == taxSlabId);

      if (_selectedTaxSlab?.id == taxSlabId) {
        _selectedTaxSlab = null;
      }

      _clearError();
      notifyListeners();
      log('[TaxProvider] ✅ Tax slab deleted');
    } catch (e) {
      _setError('Failed to delete tax slab: $e');
      log('[TaxProvider] ❌ Error deleting tax slab: $e');
    }
  }

  /// Select a tax slab
  void selectTaxSlab(TaxSlab taxSlab) {
    _selectedTaxSlab = taxSlab;
    notifyListeners();
  }

  /// Clear selected tax slab
  void clearSelection() {
    _selectedTaxSlab = null;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAX CALCULATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Calculate tax for an item
  TaxCalculation? calculateTax({
    required String taxSlabId,
    required double itemPrice,
  }) {
    final taxSlab = _taxSlabs.firstWhere(
      (t) => t.id == taxSlabId,
      orElse: () => TaxSlab(
        id: '',
        businessId: _businessId,
        name: 'No Tax',
        percentage: 0,
        type: TaxType.none,
        createdByUid: '',
        createdByName: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (taxSlab.id.isEmpty) return null;

    return TaxCalculation(taxSlab: taxSlab, itemPrice: itemPrice);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if user can modify tax (owner, manager, or admin)
  bool _canModifyTax() {
    return _role == 'owner' || _role == 'manager' || _role == 'admin';
  }

  /// Sort tax slabs
  void _sortTaxSlabs() {
    _taxSlabs.sort((a, b) {
      // Active first
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;

      // Then by sort order
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }

      // Finally by created date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _setStatus(TaxProviderStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _status = TaxProviderStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Get tax slab by ID
  TaxSlab? getTaxSlabById(String id) {
    try {
      return _taxSlabs.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

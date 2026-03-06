// lib/providers/report_provider.dart
//
// Fetches data needed for report generation.
// Flow: select company → select period → generate → preview → download
//
// ROLE GATE: Only admin / system / owner / manager can access reports.
// The screen should not even be reachable for other roles, but the
// provider also checks and populates nothing for unauthorised users.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ReportCompany {
  final String id;
  final String name;
  const ReportCompany({required this.id, required this.name});
}

class ReportOrderRow {
  final String orderId;
  final String status;
  final double totalAmount;
  final String staffName;
  final String staffRole;
  final DateTime createdAt;
  final String orderType;
  final List<ReportOrderItem> items;

  const ReportOrderRow({
    required this.orderId,
    required this.status,
    required this.totalAmount,
    required this.staffName,
    required this.staffRole,
    required this.createdAt,
    required this.orderType,
    this.items = const [],
  });
}

class ReportOrderItem {
  final String name;
  final String category;
  final int quantity;
  final double subtotal;
  const ReportOrderItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.subtotal,
  });
}

class ReportStaffSummary {
  final String name;
  final String role;
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double revenue;
  const ReportStaffSummary({
    required this.name,
    required this.role,
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.revenue,
  });
}

class ReportTopItem {
  final String name;
  final String category;
  final int quantitySold;
  final double revenue;
  const ReportTopItem({
    required this.name,
    required this.category,
    required this.quantitySold,
    required this.revenue,
  });
}

/// The complete data bundle used to render the report preview + PDF.
class ReportData {
  final String companyName;
  final String period;           // 'Weekly' | 'Monthly' | 'All'
  final DateTime fromDate;
  final DateTime toDate;
  final DateTime generatedAt;

  // Summary metrics
  final double totalRevenue;
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double averageOrderValue;

  // Breakdowns
  final List<ReportStaffSummary> staffSummaries;
  final List<ReportTopItem> topItems;

  // Daily revenue for chart (date → revenue)
  final List<({DateTime date, double revenue})> dailyRevenue;

  const ReportData({
    required this.companyName,
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.generatedAt,
    required this.totalRevenue,
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.averageOrderValue,
    required this.staffSummaries,
    required this.topItems,
    required this.dailyRevenue,
  });

  double get cancelRate =>
      totalOrders > 0 ? (cancelledOrders / totalOrders * 100) : 0.0;
  double get completionRate =>
      totalOrders > 0 ? (completedOrders / totalOrders * 100) : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class ReportProvider extends ChangeNotifier {
  String _uid = '';
  String _role = '';
  String _ownBusinessId = '';

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loadingCompanies = false;
  bool _generating = false;
  String? _error;

  List<ReportCompany> _companies = [];
  String? _selectedCompanyId;
  String _selectedPeriod = 'Weekly'; // Weekly | Monthly | All
  ReportData? _reportData;

  // ── Public getters ─────────────────────────────────────────────────────────
  bool get loadingCompanies => _loadingCompanies;
  bool get generating => _generating;
  String? get error => _error;
  List<ReportCompany> get companies => _companies;
  String? get selectedCompanyId => _selectedCompanyId;
  String get selectedPeriod => _selectedPeriod;
  ReportData? get reportData => _reportData;
  bool get hasReport => _reportData != null;

  bool get hasAccess =>
      ['owner', 'system', 'admin', 'manager'].contains(_role.toLowerCase());

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadUser();
    if (hasAccess) await loadCompanies();
  }

  Future<void> _loadUser() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) return;
      final storedData = await StorageService.instance.getUserData();
      final String canonicalUid = storedData['uid'] as String? ?? fbUser.uid;
      _uid = canonicalUid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (!doc.exists) return;
      final d = doc.data()!;
      _role = d['role'] as String? ?? 'staff';
      _ownBusinessId = d['businessId'] as String? ?? '';
    } catch (e) {
      debugPrint('📋 ReportProvider _loadUser: $e');
    }
  }

  // ── Load company list ──────────────────────────────────────────────────────
  // For owner/admin/manager: loads their own business (and any sub-businesses
  // if the schema supports it).  For system role: loads all businesses.
  Future<void> loadCompanies() async {
    _loadingCompanies = true;
    _error = null;
    notifyListeners();

    try {
      final List<ReportCompany> result = [];

      if (_role.toLowerCase() == 'system') {
        // System role: fetch all businesses
        final snap = await FirebaseFirestore.instance
            .collection('businesses')
            .orderBy('name')
            .get();
        for (final doc in snap.docs) {
          result.add(ReportCompany(
            id: doc.id,
            name: doc.data()['name'] as String? ?? doc.id,
          ));
        }
      } else {
        // All other privileged roles: fetch their own business
        if (_ownBusinessId.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(_ownBusinessId)
              .get();
          final name = doc.exists
              ? (doc.data()?['name'] as String? ?? _ownBusinessId)
              : _ownBusinessId;
          result.add(ReportCompany(id: _ownBusinessId, name: name));
        }
      }

      _companies = result;
      // Auto-select if only one company
      if (_companies.length == 1) {
        _selectedCompanyId = _companies.first.id;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('📋 loadCompanies ERROR: $e');
    } finally {
      _loadingCompanies = false;
      notifyListeners();
    }
  }

  void selectCompany(String id) {
    _selectedCompanyId = id;
    _reportData = null; // clear old report on new selection
    _error = null;
    notifyListeners();
  }

  void selectPeriod(String period) {
    _selectedPeriod = period;
    _reportData = null;
    _error = null;
    notifyListeners();
  }

  void clearReport() {
    _reportData = null;
    _error = null;
    notifyListeners();
  }

  // ── Generate report ────────────────────────────────────────────────────────

  Future<void> generateReport() async {
    if (_selectedCompanyId == null) {
      _error = 'Please select a company first';
      notifyListeners();
      return;
    }

    _generating = true;
    _error = null;
    _reportData = null;
    notifyListeners();

    try {
      final db = Supabase.instance.client;
      final now = DateTime.now();
      final companyName = _companies
          .firstWhere((c) => c.id == _selectedCompanyId,
              orElse: () => ReportCompany(id: '', name: 'Unknown'))
          .name;

      // ── Determine date range ──────────────────────────────────────────────
      final DateTime fromDate;
      final DateTime toDate;

      switch (_selectedPeriod) {
        case 'Monthly':
          fromDate = DateTime(now.year, now.month, 1);
          toDate = DateTime(now.year, now.month + 1, 1);
          break;
        case 'All':
          // All time: from epoch start — fetch earliest order date
          fromDate = DateTime(2020, 1, 1);
          toDate = now.add(const Duration(days: 1));
          break;
        default: // Weekly
          final monday = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          fromDate = monday;
          toDate = monday.add(const Duration(days: 7));
          break;
      }

      final fromStr = fromDate.toUtc().toIso8601String();
      final toStr = toDate.toUtc().toIso8601String();

      debugPrint(
          '📋 Generating $companyName report: $fromStr → $toStr');

      // ── Fetch all orders for the period ───────────────────────────────────
      final orderRows = await db
          .from('orders')
          .select(
            'id, status, total_amount, order_type, '
            'created_at, created_by_name, created_by_role',
          )
          .eq('business_id', _selectedCompanyId!)
          .gte('created_at', fromStr)
          .lt('created_at', toStr)
          .order('created_at') as List;

      debugPrint('📋 Order rows: ${orderRows.length}');

      // ── Fetch order items for all completed orders ────────────────────────
      final completedIds = orderRows
          .where((r) => r['status'] == 'completed')
          .map((r) => r['id'] as String)
          .toList();

      final Map<String, List<ReportOrderItem>> itemsByOrder = {};
      for (int i = 0; i < completedIds.length; i += 100) {
        final chunk = completedIds.sublist(
            i, (i + 100).clamp(0, completedIds.length));
        final rows = await db
            .from('order_items')
            .select('order_id, item_name, category_name, quantity, subtotal')
            .inFilter('order_id', chunk) as List;
        for (final r in rows) {
          final oid = r['order_id'] as String;
          itemsByOrder.putIfAbsent(oid, () => []);
          itemsByOrder[oid]!.add(ReportOrderItem(
            name: r['item_name'] as String? ?? '',
            category: r['category_name'] as String? ?? '',
            quantity: (r['quantity'] as num? ?? 0).toInt(),
            subtotal: (r['subtotal'] as num? ?? 0).toDouble(),
          ));
        }
      }

      // ── Compute summary metrics ───────────────────────────────────────────
      int totalOrders = orderRows.length;
      int completedOrders = 0;
      int cancelledOrders = 0;
      double totalRevenue = 0;

      final Map<String, _StaffAgg> staffMap = {};
      final Map<String, _ItemAggR> itemMap = {};
      final Map<String, double> dailyMap = {};

      for (final r in orderRows) {
        final status = r['status'] as String? ?? '';
        final amount = (r['total_amount'] as num? ?? 0).toDouble();
        final staffName = r['created_by_name'] as String? ?? 'Unknown';
        final staffRole = r['created_by_role'] as String? ?? 'staff';
        final orderType = r['order_type'] as String? ?? '';

        DateTime createdAt;
        try {
          createdAt =
              DateTime.parse(r['created_at'] as String).toLocal();
        } catch (_) {
          createdAt = now;
        }

        // Staff aggregation
        staffMap.putIfAbsent(
          staffName,
          () => _StaffAgg(name: staffName, role: staffRole),
        );
        staffMap[staffName]!.total++;
        if (status == 'completed') {
          staffMap[staffName]!.completed++;
          staffMap[staffName]!.revenue += amount;
        }
        if (status == 'cancelled') {
          staffMap[staffName]!.cancelled++;
        }

        if (status == 'completed') {
          completedOrders++;
          totalRevenue += amount;

          // Daily breakdown
          final dayKey =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + amount;

          // Item aggregation
          final ordItems = itemsByOrder[r['id'] as String] ?? [];
          for (final item in ordItems) {
            final k = item.name;
            itemMap.putIfAbsent(
              k,
              () => _ItemAggR(name: k, category: item.category),
            );
            itemMap[k]!.qty += item.quantity;
            itemMap[k]!.revenue += item.subtotal;
          }
        }

        if (status == 'cancelled') cancelledOrders++;
      }

      // Sort daily revenue by date
      final sortedDays = dailyMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final dailyRevenue = sortedDays.map((e) {
        final parts = e.key.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return (date: date, revenue: e.value);
      }).toList();

      // Top 10 items by quantity
      final topItems = (itemMap.values.toList()
            ..sort((a, b) => b.qty.compareTo(a.qty)))
          .take(10)
          .map((a) => ReportTopItem(
                name: a.name,
                category: a.category,
                quantitySold: a.qty,
                revenue: a.revenue,
              ))
          .toList();

      // Staff summaries sorted by revenue
      final staffSummaries = (staffMap.values.toList()
            ..sort((a, b) => b.revenue.compareTo(a.revenue)))
          .map((s) => ReportStaffSummary(
                name: s.name,
                role: s.role,
                totalOrders: s.total,
                completedOrders: s.completed,
                cancelledOrders: s.cancelled,
                revenue: s.revenue,
              ))
          .toList();

      _reportData = ReportData(
        companyName: companyName,
        period: _selectedPeriod,
        fromDate: fromDate,
        toDate: toDate,
        generatedAt: now,
        totalRevenue: totalRevenue,
        totalOrders: totalOrders,
        completedOrders: completedOrders,
        cancelledOrders: cancelledOrders,
        averageOrderValue:
            completedOrders > 0 ? totalRevenue / completedOrders : 0,
        staffSummaries: staffSummaries,
        topItems: topItems,
        dailyRevenue: dailyRevenue,
      );

      debugPrint(
        '📋 Report ready: ₹${totalRevenue.toStringAsFixed(0)} '
        '$totalOrders orders $completedOrders completed',
      );
    } catch (e, st) {
      _error = e.toString();
      debugPrint('📋 generateReport ERROR: $e\n$st');
    } finally {
      _generating = false;
      notifyListeners();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INTERNAL AGGREGATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _StaffAgg {
  final String name, role;
  int total = 0, completed = 0, cancelled = 0;
  double revenue = 0;
  _StaffAgg({required this.name, required this.role});
}

class _ItemAggR {
  final String name, category;
  int qty = 0;
  double revenue = 0;
  _ItemAggR({required this.name, required this.category});
}
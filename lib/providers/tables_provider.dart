import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';


class TablesProvider extends ChangeNotifier {
  TableSection? _selectedSection; // null = all
  TableStatus?  _selectedStatus;  // null = all
  bool _isLoading = false;

  final List<RestaurantTable> _tables = [];

  TablesProvider() { _seed(); }

  // ── Getters ──────────────────────────────────────────────
  TableSection? get selectedSection => _selectedSection;
  TableStatus?  get selectedStatus  => _selectedStatus;
  bool get isLoading => _isLoading;

  List<RestaurantTable> get allTables => List.unmodifiable(_tables);

  List<TableSection> get activeSections =>
      TableSection.values.where((s) =>
        _tables.any((t) => t.section == s)).toList();

  List<RestaurantTable> get filteredTables {
    return _tables.where((t) {
      if (_selectedSection != null && t.section != _selectedSection) return false;
      if (_selectedStatus  != null && t.status  != _selectedStatus)  return false;
      return true;
    }).toList()
      ..sort((a, b) {
        // Sort: occupied first → reserved → available → cleaning
        const p = {
          TableStatus.occupied:  0,
          TableStatus.reserved:  1,
          TableStatus.available: 2,
          TableStatus.cleaning:  3,
        };
        final pa = p[a.status] ?? 4;
        final pb = p[b.status] ?? 4;
        if (pa != pb) return pa.compareTo(pb);
        return a.tableNumber.compareTo(b.tableNumber);
      });
  }

  // Stats per section
  Map<TableSection, int> get availablePerSection {
    final m = <TableSection, int>{};
    for (final s in TableSection.values) {
      m[s] = _tables
          .where((t) => t.section == s && t.status == TableStatus.available)
          .length;
    }
    return m;
  }

  int get totalAvailable => _tables.where((t) => t.status == TableStatus.available).length;
  int get totalOccupied  => _tables.where((t) => t.status == TableStatus.occupied).length;
  int get totalReserved  => _tables.where((t) => t.status == TableStatus.reserved).length;
  int get totalTables    => _tables.length;

  // ── Filters ──────────────────────────────────────────────
  void setSection(TableSection? s) { _selectedSection = s; notifyListeners(); }
  void setStatus(TableStatus? s)   { _selectedStatus  = s; notifyListeners(); }

  // ── CRUD ─────────────────────────────────────────────────
  Future<void> addTable(RestaurantTable t) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    _tables.add(t);
    _isLoading = false; notifyListeners();
  }

  Future<void> updateTable(RestaurantTable updated) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _tables.indexWhere((t) => t.id == updated.id);
    if (idx != -1) _tables[idx] = updated;
    _isLoading = false; notifyListeners();
  }

  Future<void> deleteTable(String id) async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));
    _tables.removeWhere((t) => t.id == id);
    _isLoading = false; notifyListeners();
  }

  // ── Reservation ops ───────────────────────────────────────
  Future<void> addReservation(String tableId, Reservation res) async {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.reserved,
      reservation: res,
    );
    notifyListeners();
  }

  Future<void> updateReservation(String tableId, Reservation updated) async {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(reservation: updated);
    notifyListeners();
  }

  void cancelReservation(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.available,
      clearReservation: true,
    );
    notifyListeners();
  }

  void seatGuests(String tableId, String customerName) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.occupied,
      currentCustomerName: customerName,
      occupiedSince: DateTime.now(),
      clearReservation: true,
    );
    notifyListeners();
  }

  void clearTable(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(
      status: TableStatus.cleaning,
      clearOccupied: true,
    );
    notifyListeners();
  }

  void markAvailable(String tableId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx == -1) return;
    _tables[idx] = _tables[idx].copyWith(status: TableStatus.available);
    notifyListeners();
  }

  String generateId() => 'tbl_${DateTime.now().millisecondsSinceEpoch}';

  int nextTableNumber() => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

  // ── Seed ─────────────────────────────────────────────────
  void _seed() {
    _tables.addAll([
      // AC HALL – Ground Floor
      RestaurantTable(
        id: 'tbl_001', tableNumber: 1, capacity: 4, section: TableSection.ac,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Arjun & Party', currentOrderId: '#4523',
        currentOrderTotal: 1250.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 45)),
        hasWindow: true,
      ),
      RestaurantTable(
        id: 'tbl_002', tableNumber: 2, capacity: 2, section: TableSection.ac,
        status: TableStatus.available, shape: TableShape.round, hasWindow: false,
      ),
      RestaurantTable(
        id: 'tbl_003', tableNumber: 3, capacity: 6, section: TableSection.ac,
        status: TableStatus.reserved, shape: TableShape.rectangle,
        reservation: Reservation(
          id: 'res_001', customerName: 'Priya Sharma', phone: '+91 98765 43210',
          guestCount: 5, notes: 'Birthday dinner – cake arranged',
          reservedFor: DateTime.now().add(const Duration(hours: 1, minutes: 20)),
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ),
      RestaurantTable(
        id: 'tbl_004', tableNumber: 4, capacity: 4, section: TableSection.ac,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Rajesh M', currentOrderId: '#4521',
        currentOrderTotal: 2100.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 30)),
        isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_005', tableNumber: 5, capacity: 2, section: TableSection.ac,
        status: TableStatus.cleaning, shape: TableShape.round,
      ),

      // NON-AC – Ground Floor
      RestaurantTable(
        id: 'tbl_006', tableNumber: 6, capacity: 4, section: TableSection.nonAc,
        status: TableStatus.available, shape: TableShape.square,
      ),
      RestaurantTable(
        id: 'tbl_007', tableNumber: 7, capacity: 6, section: TableSection.nonAc,
        status: TableStatus.occupied, shape: TableShape.rectangle,
        currentCustomerName: 'Meena & Family', currentOrderId: '#4520',
        currentOrderTotal: 880.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 55)),
      ),
      RestaurantTable(
        id: 'tbl_008', tableNumber: 8, capacity: 4, section: TableSection.nonAc,
        status: TableStatus.reserved, shape: TableShape.square,
        reservation: Reservation(
          id: 'res_002', customerName: 'Karthik S', phone: '+91 90001 22334',
          guestCount: 3, notes: 'Window seat preferred',
          reservedFor: DateTime.now().add(const Duration(minutes: 40)),
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ),
      RestaurantTable(
        id: 'tbl_009', tableNumber: 9, capacity: 8, section: TableSection.nonAc,
        status: TableStatus.available, shape: TableShape.rectangle,
      ),

      // ROOFTOP – 3rd Floor
      RestaurantTable(
        id: 'tbl_010', tableNumber: 10, capacity: 2, section: TableSection.rooftop,
        status: TableStatus.available, shape: TableShape.round,
        hasWindow: true, isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_011', tableNumber: 11, capacity: 4, section: TableSection.rooftop,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'Divya R', currentOrderId: '#4519',
        currentOrderTotal: 1540.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 20)),
        hasWindow: true, isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_012', tableNumber: 12, capacity: 4, section: TableSection.rooftop,
        status: TableStatus.reserved, shape: TableShape.round,
        isPremium: true,
        reservation: Reservation(
          id: 'res_003', customerName: 'Suresh & Anita', phone: '+91 95555 66778',
          guestCount: 4, notes: 'Anniversary dinner',
          reservedFor: DateTime.now().add(const Duration(hours: 2)),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ),

      // GARDEN – Ground Floor
      RestaurantTable(
        id: 'tbl_013', tableNumber: 13, capacity: 6, section: TableSection.garden,
        status: TableStatus.available, shape: TableShape.rectangle,
        hasWindow: true,
      ),
      RestaurantTable(
        id: 'tbl_014', tableNumber: 14, capacity: 4, section: TableSection.garden,
        status: TableStatus.occupied, shape: TableShape.square,
        currentCustomerName: 'IT Team Lunch', currentOrderId: '#4518',
        currentOrderTotal: 3200.0,
        occupiedSince: DateTime.now().subtract(const Duration(minutes: 38)),
      ),

      // PRIVATE – 2nd Floor
      RestaurantTable(
        id: 'tbl_015', tableNumber: 15, capacity: 12, section: TableSection.privateRoom,
        status: TableStatus.available, shape: TableShape.rectangle,
        isPremium: true,
      ),
      RestaurantTable(
        id: 'tbl_016', tableNumber: 16, capacity: 8, section: TableSection.privateRoom,
        status: TableStatus.reserved, shape: TableShape.rectangle,
        isPremium: true,
        reservation: Reservation(
          id: 'res_004', customerName: 'Corporate – TCS', phone: '+91 44000 11223',
          guestCount: 8, notes: 'Board meeting lunch, projector required',
          reservedFor: DateTime.now().add(const Duration(hours: 3)),
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ),
    ]);
  }
}

// import 'package:flutter/material.dart';
// import 'package:pos_app/models/table_modal.dart';


// class TablesProvider extends ChangeNotifier {
//   int _selectedFloor = 0;
//   TableZone? _selectedZone;   // null = all zones
//   TableStatus? _selectedStatus; // null = all statuses
//   bool _isLoading = false;

//   final List<RestaurantTable> _tables = [];

//   NewTablesProvider() { _seed(); }

//   // ── Getters ────────────────────────────────────────────────
//   int get selectedFloor     => _selectedFloor;
//   TableZone? get selectedZone   => _selectedZone;
//   TableStatus? get selectedStatus => _selectedStatus;
//   bool get isLoading        => _isLoading;

//   List<int> get floors {
//     final f = _tables.map((t) => t.floor).toSet().toList()..sort();
//     return f;
//   }

//   List<RestaurantTable> get filteredTables {
//     return _tables.where((t) {
//       if (t.floor != _selectedFloor) return false;
//       if (_selectedZone != null && t.zone != _selectedZone) return false;
//       if (_selectedStatus != null && t.status != _selectedStatus) return false;
//       return true;
//     }).toList()
//       ..sort((a, b) => a.number.compareTo(b.number));
//   }

//   // Summary for current floor
//   int countByStatus(TableStatus s) =>
//       _tables.where((t) => t.floor == _selectedFloor && t.status == s).length;

//   int get totalOnFloor =>
//       _tables.where((t) => t.floor == _selectedFloor).length;

//   int get availableCount  => countByStatus(TableStatus.available);
//   int get occupiedCount   => countByStatus(TableStatus.occupied);
//   int get reservedCount   => countByStatus(TableStatus.reserved);
//   int get cleaningCount   => countByStatus(TableStatus.cleaning);

//   List<RestaurantTable> get upcomingReservations => _tables
//       .where((t) =>
//           t.reservation != null && t.reservation!.isUpcoming)
//       .toList()
//       ..sort((a, b) =>
//           a.reservation!.scheduledAt.compareTo(b.reservation!.scheduledAt));

//   // ── Mutations ──────────────────────────────────────────────
//   void setFloor(int f) {
//     _selectedFloor = f;
//     _selectedZone = null;
//     _selectedStatus = null;
//     notifyListeners();
//   }

//   void setZone(TableZone? z) {
//     _selectedZone = _selectedZone == z ? null : z;
//     notifyListeners();
//   }

//   void setStatus(TableStatus? s) {
//     _selectedStatus = _selectedStatus == s ? null : s;
//     notifyListeners();
//   }

//   Future<void> addTable(RestaurantTable table) async {
//     _isLoading = true; notifyListeners();
//     await Future.delayed(const Duration(milliseconds: 300));
//     _tables.add(table);
//     _isLoading = false; notifyListeners();
//   }

//   Future<void> updateTable(RestaurantTable updated) async {
//     _isLoading = true; notifyListeners();
//     await Future.delayed(const Duration(milliseconds: 300));
//     final i = _tables.indexWhere((t) => t.id == updated.id);
//     if (i != -1) _tables[i] = updated;
//     _isLoading = false; notifyListeners();
//   }

//   Future<void> deleteTable(String id) async {
//     _isLoading = true; notifyListeners();
//     await Future.delayed(const Duration(milliseconds: 300));
//     _tables.removeWhere((t) => t.id == id);
//     _isLoading = false; notifyListeners();
//   }

//   Future<void> addReservation({
//     required String tableId,
//     required Reservation reservation,
//   }) async {
//     _isLoading = true; notifyListeners();
//     await Future.delayed(const Duration(milliseconds: 300));
//     final i = _tables.indexWhere((t) => t.id == tableId);
//     if (i != -1) {
//       _tables[i] = _tables[i].copyWith(
//         status: TableStatus.reserved,
//         reservation: () => reservation,
//       );
//     }
//     _isLoading = false; notifyListeners();
//   }

//   Future<void> cancelReservation(String tableId) async {
//     _isLoading = true; notifyListeners();
//     await Future.delayed(const Duration(milliseconds: 300));
//     final i = _tables.indexWhere((t) => t.id == tableId);
//     if (i != -1) {
//       _tables[i] = _tables[i].copyWith(
//         status: TableStatus.available,
//         reservation: () => null,
//       );
//     }
//     _isLoading = false; notifyListeners();
//   }

//   void markOccupied(String tableId, String customerName) {
//     final i = _tables.indexWhere((t) => t.id == tableId);
//     if (i != -1) {
//       _tables[i] = _tables[i].copyWith(
//         status: TableStatus.occupied,
//         occupiedBy: customerName,
//         occupiedSince: DateTime.now(),
//         reservation: () => null,
//       );
//       notifyListeners();
//     }
//   }

//   void markAvailable(String tableId) {
//     final i = _tables.indexWhere((t) => t.id == tableId);
//     if (i != -1) {
//       _tables[i] = _tables[i].copyWith(
//         status: TableStatus.available,
//         reservation: () => null,
//       );
//       notifyListeners();
//     }
//   }

//   void markCleaning(String tableId) {
//     final i = _tables.indexWhere((t) => t.id == tableId);
//     if (i != -1) {
//       _tables[i] = _tables[i].copyWith(status: TableStatus.cleaning);
//       notifyListeners();
//     }
//   }

//   String generateId() =>
//       'tbl_${DateTime.now().millisecondsSinceEpoch % 100000}';
//   List<RestaurantTable> get allTables => List.unmodifiable(_tables);

//   String generateResId() =>
//       'res_${DateTime.now().millisecondsSinceEpoch % 100000}';

//   // ── Seed data ──────────────────────────────────────────────
//   void _seed() {
//     _tables.addAll([
//       // ── Ground Floor AC ───────────────────────
//       RestaurantTable(id:'t01', number:1,  capacity:2, status:TableStatus.available, zone:TableZone.ac, shape:TableShape.round,     floor:0),
//       RestaurantTable(id:'t02', number:2,  capacity:4, status:TableStatus.occupied,  zone:TableZone.ac, shape:TableShape.square,
//         floor:0, occupiedBy:'Rahul M', occupiedSince:DateTime.now().subtract(const Duration(minutes:42)),
//         activeOrderId:'#4523', currentBill:1250),
//       RestaurantTable(id:'t03', number:3,  capacity:6, status:TableStatus.reserved,  zone:TableZone.ac, shape:TableShape.rectangle, floor:0,
//         reservation: Reservation(id:'r01', customerName:'Priya Sharma', phone:'+91 98765 43210',
//           guestCount:5, scheduledAt:DateTime.now().add(const Duration(hours:1, minutes:20)),
//           note:'Birthday celebration, need cake arrangement')),
//       RestaurantTable(id:'t04', number:4,  capacity:4, status:TableStatus.available, zone:TableZone.ac, shape:TableShape.square,    floor:0),
//       RestaurantTable(id:'t05', number:5,  capacity:8, status:TableStatus.occupied,  zone:TableZone.ac, shape:TableShape.rectangle, floor:0,
//         occupiedBy:'Corporate Team', occupiedSince:DateTime.now().subtract(const Duration(minutes:75)),
//         activeOrderId:'#4521', currentBill:4800),
//       RestaurantTable(id:'t06', number:6,  capacity:2, status:TableStatus.cleaning,  zone:TableZone.ac, shape:TableShape.round,     floor:0),
//       // ── Ground Floor Non-AC ───────────────────
//       RestaurantTable(id:'t07', number:7,  capacity:4, status:TableStatus.available, zone:TableZone.nonAc, shape:TableShape.square,    floor:0),
//       RestaurantTable(id:'t08', number:8,  capacity:6, status:TableStatus.occupied,  zone:TableZone.nonAc, shape:TableShape.rectangle, floor:0,
//         occupiedBy:'Family Group', occupiedSince:DateTime.now().subtract(const Duration(minutes:25)),
//         currentBill:960),
//       RestaurantTable(id:'t09', number:9,  capacity:2, status:TableStatus.available, zone:TableZone.nonAc, shape:TableShape.round,     floor:0),
//       RestaurantTable(id:'t10', number:10, capacity:4, status:TableStatus.reserved,  zone:TableZone.nonAc, shape:TableShape.square,    floor:0,
//         reservation: Reservation(id:'r02', customerName:'Karthik R', phone:'+91 87654 32109',
//           guestCount:3, scheduledAt:DateTime.now().add(const Duration(minutes:35)))),
//       // ── First Floor AC ────────────────────────
//       RestaurantTable(id:'t11', number:11, capacity:4, status:TableStatus.available, zone:TableZone.ac, shape:TableShape.square,    floor:1),
//       RestaurantTable(id:'t12', number:12, capacity:6, status:TableStatus.occupied,  zone:TableZone.ac, shape:TableShape.rectangle, floor:1,
//         occupiedBy:'Mehta Family', occupiedSince:DateTime.now().subtract(const Duration(minutes:55)),
//         activeOrderId:'#4520', currentBill:2340),
//       RestaurantTable(id:'t13', number:13, capacity:2, status:TableStatus.available, zone:TableZone.ac, shape:TableShape.round,     floor:1),
//       RestaurantTable(id:'t14', number:14, capacity:8, status:TableStatus.reserved,  zone:TableZone.ac, shape:TableShape.rectangle, floor:1,
//         reservation: Reservation(id:'r03', customerName:'Anniversary Party', phone:'+91 76543 21098',
//           guestCount:7, scheduledAt:DateTime.now().add(const Duration(hours:2)),
//           note:'Candle-lit setup requested')),
//       RestaurantTable(id:'t15', number:15, capacity:4, status:TableStatus.cleaning,  zone:TableZone.ac, shape:TableShape.square,    floor:1),
//       // ── First Floor Non-AC ────────────────────
//       RestaurantTable(id:'t16', number:16, capacity:4, status:TableStatus.available, zone:TableZone.nonAc, shape:TableShape.square,    floor:1),
//       RestaurantTable(id:'t17', number:17, capacity:6, status:TableStatus.occupied,  zone:TableZone.nonAc, shape:TableShape.rectangle, floor:1,
//         occupiedBy:'Lunch Group', occupiedSince:DateTime.now().subtract(const Duration(minutes:18)),
//         currentBill:780),
//       RestaurantTable(id:'t18', number:18, capacity:2, status:TableStatus.available, zone:TableZone.nonAc, shape:TableShape.round,     floor:1),
//     ]);
//   }
// }

// /*import 'package:flutter/material.dart';
// import 'package:pos_app/models/table_modal.dart';

// class TablesProvider extends ChangeNotifier {
//   String _selectedFilter = 'All';
//   final List<String> filters = ['All', 'Available', 'Occupied', 'Reserved'];

//   final List<TableModel> _tables = [
//     TableModel(
//       tableNumber: 1,
//       capacity: 4,
//       status: TableStatus.occupied,
//       orderId: '#4523',
//       customerName: 'John Doe',
//       orderTotal: 1250.00,
//       occupiedTime: DateTime.now().subtract(const Duration(minutes: 45)),
//       section: 'Main Hall',
//     ),
//     TableModel(
//       tableNumber: 2,
//       capacity: 2,
//       status: TableStatus.available,
//       section: 'Main Hall',
//     ),
//     TableModel(
//       tableNumber: 3,
//       capacity: 6,
//       status: TableStatus.reserved,
//       customerName: 'Mike Johnson',
//       reservationTime: DateTime.now().add(const Duration(hours: 1)),
//       section: 'Main Hall',
//     ),
//     TableModel(
//       tableNumber: 4,
//       capacity: 4,
//       status: TableStatus.occupied,
//       orderId: '#4522',
//       customerName: 'Jane Smith',
//       orderTotal: 2100.00,
//       occupiedTime: DateTime.now().subtract(const Duration(minutes: 30)),
//       section: 'Garden',
//     ),
//     TableModel(
//       tableNumber: 5,
//       capacity: 8,
//       status: TableStatus.available,
//       section: 'Garden',
//     ),
//     TableModel(
//       tableNumber: 6,
//       capacity: 2,
//       status: TableStatus.occupied,
//       orderId: '#4521',
//       customerName: 'Sarah Wilson',
//       orderTotal: 850.00,
//       occupiedTime: DateTime.now().subtract(const Duration(minutes: 20)),
//       section: 'Patio',
//     ),
//     TableModel(
//       tableNumber: 7,
//       capacity: 4,
//       status: TableStatus.available,
//       section: 'Patio',
//     ),
//     TableModel(
//       tableNumber: 8,
//       capacity: 6,
//       status: TableStatus.reserved,
//       customerName: 'David Brown',
//       reservationTime: DateTime.now().add(const Duration(hours: 2)),
//       section: 'Private',
//     ),
//   ];

//   String get selectedFilter => _selectedFilter;
//   List<TableModel> get allTables => _tables;

//   List<TableModel> get filteredTables {
//     if (_selectedFilter == 'All') return _tables;
//     return _tables.where((table) {
//       switch (_selectedFilter) {
//         case 'Available':
//           return table.status == TableStatus.available;
//         case 'Occupied':
//           return table.status == TableStatus.occupied;
//         case 'Reserved':
//           return table.status == TableStatus.reserved;
//         default:
//           return true;
//       }
//     }).toList();
//   }

//   int get availableCount =>
//       _tables.where((t) => t.status == TableStatus.available).length;
//   int get occupiedCount =>
//       _tables.where((t) => t.status == TableStatus.occupied).length;
//   int get reservedCount =>
//       _tables.where((t) => t.status == TableStatus.reserved).length;

//   double get totalRevenue =>
//       _tables.fold(0, (sum, t) => sum + (t.orderTotal ?? 0));

//   void setFilter(String filter) {
//     _selectedFilter = filter;
//     notifyListeners();
//   }

//   void clearTable(int tableNumber) {
//     final index = _tables.indexWhere((t) => t.tableNumber == tableNumber);
//     if (index != -1) {
//       _tables[index] = TableModel(
//         tableNumber: _tables[index].tableNumber,
//         capacity: _tables[index].capacity,
//         status: TableStatus.available,
//         section: _tables[index].section,
//       );
//       notifyListeners();
//     }
//   }

//   void assignTable(int tableNumber, String customerName) {
//     final index = _tables.indexWhere((t) => t.tableNumber == tableNumber);
//     if (index != -1) {
//       _tables[index] = TableModel(
//         tableNumber: _tables[index].tableNumber,
//         capacity: _tables[index].capacity,
//         status: TableStatus.occupied,
//         customerName: customerName,
//         orderId: '#${DateTime.now().millisecondsSinceEpoch % 10000}',
//         orderTotal: 0,
//         occupiedTime: DateTime.now(),
//         section: _tables[index].section,
//       );
//       notifyListeners();
//     }
//   }
// }
// */
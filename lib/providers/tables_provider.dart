import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';

class TablesProvider extends ChangeNotifier {
  String _selectedFilter = 'All';
  final List<String> filters = ['All', 'Available', 'Occupied', 'Reserved'];

  final List<TableModel> _tables = [
    TableModel(
      tableNumber: 1,
      capacity: 4,
      status: TableStatus.occupied,
      orderId: '#4523',
      customerName: 'John Doe',
      orderTotal: 1250.00,
      occupiedTime: DateTime.now().subtract(const Duration(minutes: 45)),
      section: 'Main Hall',
    ),
    TableModel(
      tableNumber: 2,
      capacity: 2,
      status: TableStatus.available,
      section: 'Main Hall',
    ),
    TableModel(
      tableNumber: 3,
      capacity: 6,
      status: TableStatus.reserved,
      customerName: 'Mike Johnson',
      reservationTime: DateTime.now().add(const Duration(hours: 1)),
      section: 'Main Hall',
    ),
    TableModel(
      tableNumber: 4,
      capacity: 4,
      status: TableStatus.occupied,
      orderId: '#4522',
      customerName: 'Jane Smith',
      orderTotal: 2100.00,
      occupiedTime: DateTime.now().subtract(const Duration(minutes: 30)),
      section: 'Garden',
    ),
    TableModel(
      tableNumber: 5,
      capacity: 8,
      status: TableStatus.available,
      section: 'Garden',
    ),
    TableModel(
      tableNumber: 6,
      capacity: 2,
      status: TableStatus.occupied,
      orderId: '#4521',
      customerName: 'Sarah Wilson',
      orderTotal: 850.00,
      occupiedTime: DateTime.now().subtract(const Duration(minutes: 20)),
      section: 'Patio',
    ),
    TableModel(
      tableNumber: 7,
      capacity: 4,
      status: TableStatus.available,
      section: 'Patio',
    ),
    TableModel(
      tableNumber: 8,
      capacity: 6,
      status: TableStatus.reserved,
      customerName: 'David Brown',
      reservationTime: DateTime.now().add(const Duration(hours: 2)),
      section: 'Private',
    ),
  ];

  String get selectedFilter => _selectedFilter;
  List<TableModel> get allTables => _tables;

  List<TableModel> get filteredTables {
    if (_selectedFilter == 'All') return _tables;
    return _tables.where((table) {
      switch (_selectedFilter) {
        case 'Available':
          return table.status == TableStatus.available;
        case 'Occupied':
          return table.status == TableStatus.occupied;
        case 'Reserved':
          return table.status == TableStatus.reserved;
        default:
          return true;
      }
    }).toList();
  }

  int get availableCount =>
      _tables.where((t) => t.status == TableStatus.available).length;
  int get occupiedCount =>
      _tables.where((t) => t.status == TableStatus.occupied).length;
  int get reservedCount =>
      _tables.where((t) => t.status == TableStatus.reserved).length;

  double get totalRevenue =>
      _tables.fold(0, (sum, t) => sum + (t.orderTotal ?? 0));

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void clearTable(int tableNumber) {
    final index = _tables.indexWhere((t) => t.tableNumber == tableNumber);
    if (index != -1) {
      _tables[index] = TableModel(
        tableNumber: _tables[index].tableNumber,
        capacity: _tables[index].capacity,
        status: TableStatus.available,
        section: _tables[index].section,
      );
      notifyListeners();
    }
  }

  void assignTable(int tableNumber, String customerName) {
    final index = _tables.indexWhere((t) => t.tableNumber == tableNumber);
    if (index != -1) {
      _tables[index] = TableModel(
        tableNumber: _tables[index].tableNumber,
        capacity: _tables[index].capacity,
        status: TableStatus.occupied,
        customerName: customerName,
        orderId: '#${DateTime.now().millisecondsSinceEpoch % 10000}',
        orderTotal: 0,
        occupiedTime: DateTime.now(),
        section: _tables[index].section,
      );
      notifyListeners();
    }
  }
}

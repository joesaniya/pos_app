import 'package:flutter/foundation.dart';
import '../models/table_model.dart';

class TableProvider with ChangeNotifier {
  final List<TableModel> _tables = [
    // Ground Floor Tables
    TableModel(
      id: '1',
      tableNumber: '1',
      persons: 4,
      status: 'occupied',
      orderId: 'order_1',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '2',
      tableNumber: '2',
      persons: 4,
      status: 'available',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '3',
      tableNumber: '3',
      persons: 2,
      status: 'reserved',
      floor: 'Ground Floor',
      bookedBy: 'John Doe',
      bookingTime: DateTime.now().add(const Duration(hours: 2)),
    ),
    TableModel(
      id: '4',
      tableNumber: '4',
      persons: 6,
      status: 'available',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '5',
      tableNumber: '5',
      persons: 2,
      status: 'available',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '6',
      tableNumber: '6',
      persons: 4,
      status: 'available',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '7',
      tableNumber: '7',
      persons: 4,
      status: 'available',
      floor: 'Ground Floor',
    ),
    TableModel(
      id: '8',
      tableNumber: '8',
      persons: 2,
      status: 'available',
      floor: 'Ground Floor',
    ),

    // First Floor Tables
    TableModel(
      id: '9',
      tableNumber: '9',
      persons: 2,
      status: 'available',
      floor: 'First Floor',
    ),
    TableModel(
      id: '10',
      tableNumber: '10',
      persons: 4,
      status: 'occupied',
      floor: 'First Floor',
    ),
    TableModel(
      id: '11',
      tableNumber: '11',
      persons: 6,
      status: 'available',
      floor: 'First Floor',
    ),
    TableModel(
      id: '12',
      tableNumber: '12',
      persons: 4,
      status: 'available',
      floor: 'First Floor',
    ),
    TableModel(
      id: '13',
      tableNumber: '13',
      persons: 2,
      status: 'reserved',
      floor: 'First Floor',
      bookedBy: 'Jane Smith',
      bookingTime: DateTime.now().add(const Duration(hours: 1)),
    ),
    TableModel(
      id: '14',
      tableNumber: '14',
      persons: 8,
      status: 'available',
      floor: 'First Floor',
    ),
    TableModel(
      id: '15',
      tableNumber: '15',
      persons: 4,
      status: 'available',
      floor: 'First Floor',
    ),
    TableModel(
      id: '16',
      tableNumber: '16',
      persons: 2,
      status: 'available',
      floor: 'First Floor',
    ),

    // Second Floor Tables
    TableModel(
      id: '17',
      tableNumber: '17',
      persons: 4,
      status: 'available',
      floor: 'Second Floor',
    ),
    TableModel(
      id: '18',
      tableNumber: '18',
      persons: 2,
      status: 'available',
      floor: 'Second Floor',
    ),
    TableModel(
      id: '19',
      tableNumber: '19',
      persons: 6,
      status: 'available',
      floor: 'Second Floor',
    ),
    TableModel(
      id: '20',
      tableNumber: '20',
      persons: 4,
      status: 'occupied',
      floor: 'Second Floor',
    ),
  ];

  TableModel? _selectedTable;
  String _selectedView = 'Tables';
  String _selectedFloor = 'All Floors';

  List<TableModel> get tables => _tables;
  TableModel? get selectedTable => _selectedTable;
  String get selectedView => _selectedView;
  String get selectedFloor => _selectedFloor;

  List<String> get floors {
    final floorSet = _tables.map((t) => t.floor).toSet().toList();
    floorSet.sort();
    return ['All Floors', ...floorSet];
  }

  List<TableModel> get filteredTables {
    if (_selectedFloor == 'All Floors') {
      return _tables;
    }
    return _tables.where((t) => t.floor == _selectedFloor).toList();
  }

  int get totalOrders => _tables.where((t) => t.status == 'occupied').length;
  int get totalAvailable =>
      _tables.where((t) => t.status == 'available').length;
  int get totalReserved => _tables.where((t) => t.status == 'reserved').length;

  int get floorOrders =>
      filteredTables.where((t) => t.status == 'occupied').length;
  int get floorAvailable =>
      filteredTables.where((t) => t.status == 'available').length;
  int get floorReserved =>
      filteredTables.where((t) => t.status == 'reserved').length;

  void selectTable(TableModel table) {
    _selectedTable = table;
    notifyListeners();
  }

  void setView(String view) {
    _selectedView = view;
    notifyListeners();
  }

  void setFloor(String floor) {
    _selectedFloor = floor;
    _selectedTable = null;
    notifyListeners();
  }

  void updateTableStatus(String tableId, String status, {String? orderId}) {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        status: status,
        orderId: orderId,
      );
      notifyListeners();
    }
  }

  void bookTable(String tableId, String customerName, DateTime bookingTime) {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        status: 'reserved',
        bookedBy: customerName,
        bookingTime: bookingTime,
      );
      notifyListeners();
    }
  }

  void releaseTable(String tableId) {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        status: 'available',
        orderId: null,
        bookedBy: null,
        bookingTime: null,
      );
      _selectedTable = null;
      notifyListeners();
    }
  }

  void cancelBooking(String tableId) {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        status: 'available',
        bookedBy: null,
        bookingTime: null,
      );
      _selectedTable = null;
      notifyListeners();
    }
  }
}

import 'package:flutter/material.dart';

class TableModel {
  final String id;
  final String status;
  final int orders;
  final double amount;
  final String time;

  TableModel({
    required this.id,
    required this.status,
    required this.orders,
    required this.amount,
    required this.time,
  });
}

class TablesProvider extends ChangeNotifier {
  final List<TableModel> _tables = [
    TableModel(
      id: 'T1',
      status: 'active',
      orders: 3,
      amount: 145.50,
      time: '25 min',
    ),
    TableModel(
      id: 'T2',
      status: 'vacant',
      orders: 0,
      amount: 0.0,
      time: '0 min',
    ),
    TableModel(
      id: 'T3',
      status: 'active',
      orders: 2,
      amount: 89.00,
      time: '15 min',
    ),
    TableModel(
      id: 'T4',
      status: 'reserved',
      orders: 0,
      amount: 0.0,
      time: '0 min',
    ),
    TableModel(
      id: 'T5',
      status: 'active',
      orders: 5,
      amount: 234.75,
      time: '42 min',
    ),
    TableModel(
      id: 'T6',
      status: 'vacant',
      orders: 0,
      amount: 0.0,
      time: '0 min',
    ),
    TableModel(
      id: 'T7',
      status: 'active',
      orders: 1,
      amount: 45.00,
      time: '8 min',
    ),
    TableModel(
      id: 'T8',
      status: 'vacant',
      orders: 0,
      amount: 0.0,
      time: '0 min',
    ),
  ];

  List<TableModel> get tables => _tables;

  int getTableCountByStatus(String status) {
    return _tables.where((table) => table.status == status).length;
  }

  int get activeTablesCount => getTableCountByStatus('active');
  int get reservedTablesCount => getTableCountByStatus('reserved');
  int get vacantTablesCount => getTableCountByStatus('vacant');

  void updateTableStatus(String tableId, String newStatus) {
    final index = _tables.indexWhere((table) => table.id == tableId);
    if (index != -1) {
      _tables[index] = TableModel(
        id: _tables[index].id,
        status: newStatus,
        orders: _tables[index].orders,
        amount: _tables[index].amount,
        time: _tables[index].time,
      );
      notifyListeners();
    }
  }
}
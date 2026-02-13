import 'package:flutter/material.dart';
import 'dart:math' as math;

class DashboardProvider extends ChangeNotifier {
  String _selectedPeriod = 'Today';
  DateTime? _selectedDate;

  final Map<String, double> _revenueData = {
    'Today': 4250.00,
    'Yesterday': 3890.00,
    'Last Month': 125400.00,
    'Last Year': 1450000.00,
  };

  String get selectedPeriod => _selectedPeriod;
  DateTime? get selectedDate => _selectedDate;

  void setSelectedPeriod(String period) {
    _selectedPeriod = period;
    _selectedDate = null;
    notifyListeners();
  }

  void setSelectedDate(DateTime? date) {
    _selectedDate = date;
    if (date != null) {
      _selectedPeriod = 'Custom';
    }
    notifyListeners();
  }

  double getRevenueForPeriod() {
    if (_selectedDate != null) {
      final random = math.Random(_selectedDate!.millisecondsSinceEpoch);
      return 2000 + random.nextDouble() * 3000;
    }
    return _revenueData[_selectedPeriod] ?? 0.0;
  }

  double getPreviousRevenue() {
    final revenue = getRevenueForPeriod();
    if (_selectedPeriod == 'Today' && _selectedDate == null) {
      return _revenueData['Yesterday']!;
    }
    return revenue * 0.85;
  }

  double getRevenueChange() {
    final revenue = getRevenueForPeriod();
    final previousRevenue = getPreviousRevenue();
    return ((revenue - previousRevenue) / previousRevenue * 100);
  }

  int getOrdersCount() {
    return _selectedPeriod == 'Today' && _selectedDate == null ? 48 : 1245;
  }

  double getAverageOrder() {
    return getRevenueForPeriod() / getOrdersCount();
  }

  int getActiveTables() {
    return 4;
  }
}
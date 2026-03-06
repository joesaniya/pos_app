import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';

import 'package:pos_app/providers/dashboard_provider.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasConnection = true;
  bool _isInit = true;

  bool _showBackOnline = false;
  Timer? _onlineBannerTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _onlineBannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    bool isConnected =
        await InternetConnectionChecker.createInstance().hasConnection;
    if (mounted) {
      setState(() {
        _hasConnection = isConnected;
        _isInit = false;
      });
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    bool isConnected = false;

    // Check if connected to any network, then verify internet connectivity
    if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
      isConnected =
          await InternetConnectionChecker.createInstance().hasConnection;
    }

    if (mounted && isConnected != _hasConnection) {
      if (!_isInit) {
        if (isConnected) {
          // Changed to connected
          setState(() {
            _hasConnection = true;
            _showBackOnline = true;
          });
          _onlineBannerTimer?.cancel();
          _onlineBannerTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showBackOnline = false;
              });
            }
          });
          _refreshData();
        } else {
          // Changed to disconnected
          setState(() {
            _hasConnection = false;
            _showBackOnline = false;
          });
        }
      } else {
        setState(() {
          _hasConnection = isConnected;
        });
      }
    }
  }

  void _refreshData() {
    // Automatically trigger reload on major data providers
    // when connection is re-established.
    Future.microtask(() {
      if (!mounted) return;
      try {
        context.read<DashboardProvider>().refresh();
        context.read<OrdersProvider>().fetchOrders();
        context.read<TablesProvider>().refresh();
        context.read<InventoryProvider>().fetchItems();
        context.read<SupabaseMenuProvider>().loadCategories();
      } catch (e) {
        debugPrint('NetworkAwareWidget: Failed to refresh providers -> $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (!_hasConnection)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0, // Appears at the bottom of the screen
              child: Material(
                color: Colors.redAccent,
                elevation: 4,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_hasConnection && _showBackOnline)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.green,
                elevation: 4,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Back Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

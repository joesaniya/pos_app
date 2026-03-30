// 🔥 KITCHEN DISPLAY SCREEN (KDS) - Real-time Order Display
// lib/screens/kitchen_display_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/kot_models.dart';
import '../services/kot_service.dart';

class KitchenDisplayScreen extends StatefulWidget {
  final String businessId;
  final String kitchenId;

  const KitchenDisplayScreen({
    super.key,
    required this.businessId,
    required this.kitchenId,
  });

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  late KOTService kotService;
  late Timer _refreshTimer;
  late Timer _delayDetectionTimer;

  List<KOTOrder> activeOrders = [];
  List<KOTDelayAlert> delayAlerts = [];
  Map<String, bool> expandedBatches = {};

  bool isOnline = true;
  int pendingSyncCount = 0;

  String sortBy =
      'oldest_first'; // oldest_first, newest_first, by_delay, by_progress
  String? filterKitchen;
  bool showDelayedOnly = false;

  @override
  void initState() {
    super.initState();
    kotService = KOTService();

    // Initial load
    _loadActiveOrders();
    _detectDelays();

    // Set up periodic refresh (2 seconds for real-time feel)
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadActiveOrders();
    });

    // Check for delays every 10 seconds
    _delayDetectionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _detectDelays();
    });

    // Listen to KOT updates
    kotService.onKOTUpdated((kot) {
      setState(() {
        final index = activeOrders.indexWhere((o) => o.id == kot.id);
        if (index >= 0) {
          activeOrders[index] = kot;
        } else {
          activeOrders.add(kot);
        }
        _sortOrders();
      });
    });

    // Listen to item status changes
    kotService.onItemStatusChanged((item) {
      setState(() {
        for (final order in activeOrders) {
          for (final batch in order.batches) {
            final itemIndex = batch.items.indexWhere((i) => i.id == item.id);
            if (itemIndex >= 0) {
              batch.items[itemIndex] = item;
            }
          }
        }
      });
    });

    // Listen to delay alerts
    kotService.onDelayDetected((alert) {
      if (mounted) {
        _showDelayNotification(alert);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _delayDetectionTimer.cancel();
    super.dispose();
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await kotService.getActiveKOTsForKitchen(
        businessId: widget.businessId,
        kitchenId: widget.kitchenId,
      );

      if (mounted) {
        setState(() {
          activeOrders = orders;
          _sortOrders();
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
    }
  }

  Future<void> _detectDelays() async {
    try {
      final alerts = await kotService.detectDelayedItems(
        businessId: widget.businessId,
        kitchenId: widget.kitchenId,
      );

      if (mounted) {
        setState(() {
          delayAlerts = alerts;
        });
      }
    } catch (e) {
      debugPrint('❌ Error detecting delays: $e');
    }
  }

  void _sortOrders() {
    switch (sortBy) {
      case 'newest_first':
        activeOrders.sort((a, b) => b.kotCreatedAt.compareTo(a.kotCreatedAt));
        break;
      case 'by_delay':
        activeOrders.sort((a, b) {
          final aDelayed = a.isDelayed ? 0 : 1;
          final bDelayed = b.isDelayed ? 0 : 1;
          return aDelayed.compareTo(bDelayed);
        });
        break;
      case 'by_progress':
        activeOrders.sort(
          (a, b) => b.completionPercentage.compareTo(a.completionPercentage),
        );
        break;
      case 'oldest_first':
      default:
        activeOrders.sort((a, b) => a.kotCreatedAt.compareTo(b.kotCreatedAt));
    }
  }

  void _applyFilters() {
    var filtered = List<KOTOrder>.from(activeOrders);

    if (showDelayedOnly) {
      filtered = filtered.where((o) => o.isDelayed).toList();
    }

    if (mounted) {
      setState(() {
        activeOrders = filtered;
      });
    }
  }

  void _showDelayNotification(KOTDelayAlert alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: alert.alertType == DelayAlertType.urgent
            ? Colors.red
            : Colors.orange,
        content: Row(
          children: [
            Text(
              alert.alertType == DelayAlertType.urgent ? '🚨' : '⚠️',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SLA Delayed!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Item delayed by ${(alert.exceededBySeconds / 60).toStringAsFixed(1)} mins',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      appBar: _buildAppBar(isDarkMode),
      body: Column(
        children: [
          // Control Panel
          _buildControlPanel(isDarkMode),

          // Stats
          _buildStatsBar(isDarkMode),

          // Orders
          Expanded(
            child: activeOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      return KDSOrderCard(
                        order: activeOrders[index],
                        onStatusChanged: (item, newStatus) {
                          _handleItemStatusChange(item, newStatus);
                        },
                        isExpanded:
                            expandedBatches[activeOrders[index].id] ?? false,
                        onToggleExpand: () {
                          setState(() {
                            final kotId = activeOrders[index].id;
                            expandedBatches[kotId] =
                                !(expandedBatches[kotId] ?? false);
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('🍳 Kitchen Display System'),
      actions: [
        // Connection status
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildControlPanel(bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Sort and filter row
          Row(
            children: [
              // Sort dropdown
              Expanded(
                child: DropdownButton<String>(
                  value: sortBy,
                  isExpanded: true,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  dropdownColor: isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  items: [
                    DropdownMenuItem(
                      value: 'oldest_first',
                      child: const Text('📅 Oldest First'),
                    ),
                    DropdownMenuItem(
                      value: 'newest_first',
                      child: const Text('🆕 Newest First'),
                    ),
                    DropdownMenuItem(
                      value: 'by_delay',
                      child: const Text('⏱️ By Delay'),
                    ),
                    DropdownMenuItem(
                      value: 'by_progress',
                      child: const Text('📊 By Progress'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        sortBy = value;
                        _sortOrders();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Delayed filter toggle
              Material(
                color: showDelayedOnly ? Colors.orange : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      showDelayedOnly = !showDelayedOnly;
                      _applyFilters();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️'),
                        const SizedBox(width: 4),
                        Text(
                          'Delayed',
                          style: TextStyle(
                            color: showDelayedOnly
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (delayAlerts.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${delayAlerts.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDarkMode) {
    final totalOrders = activeOrders.length;
    final readyOrders = activeOrders
        .where((o) => o.status == KOTOrderStatus.ready)
        .length;
    final delayedOrders = activeOrders.where((o) => o.isDelayed).length;
    final totalItems = activeOrders.fold<int>(
      0,
      (sum, o) => sum + o.totalItems,
    );

    return Container(
      color: isDarkMode ? const Color(0xFF252525) : const Color(0xFFEDEDED),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('📦 Orders', totalOrders.toString(), isDarkMode),
          _buildStatItem('✅ Ready', readyOrders.toString(), isDarkMode),
          _buildStatItem('⚠️ Delayed', delayedOrders.toString(), isDarkMode),
          _buildStatItem('🍕 Items', totalItems.toString(), isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😴', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          const Text(
            'No Active Orders',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for new orders...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _handleItemStatusChange(
    KOTItem item,
    KOTItemStatus newStatus,
  ) async {
    try {
      await kotService.updateItemStatus(
        itemId: item.id,
        kotId: item.kotId,
        businessId: widget.businessId,
        newStatus: newStatus,
        updatedByUid: '', // TODO: Get from auth
        updatedByName: '', // TODO: Get from user info
      );

      setState(() {
        _loadActiveOrders();
      });
    } catch (e) {
      debugPrint('❌ Error updating item status: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═════════════════════════════════════════════════════════════════════════════════

typedef OnItemStatusChanged =
    void Function(KOTItem item, KOTItemStatus newStatus);

class KDSOrderCard extends StatefulWidget {
  final KOTOrder order;
  final OnItemStatusChanged onStatusChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const KDSOrderCard({
    super.key,
    required this.order,
    required this.onStatusChanged,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<KDSOrderCard> createState() => _KDSOrderCardState();
}

class _KDSOrderCardState extends State<KDSOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);

    if (widget.isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(KDSOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded) {
      _animationController.forward();
    } else if (!widget.isExpanded && oldWidget.isExpanded) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final order = widget.order;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order.isDelayed
                  ? Colors.red
                  : Colors.grey[300] ?? Colors.grey,
              width: order.isDelayed ? 2 : 1,
            ),
            boxShadow: [
              if (order.isDelayed)
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(isDarkMode, order),

              // Expanded content
              if (_expandAnimation.value > 0)
                Opacity(
                  opacity: _expandAnimation.value,
                  child: _buildContent(isDarkMode, order),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDarkMode, KOTOrder order) {
    final elapsedTime = Duration(seconds: order.elapsedSeconds);
    final timeStr =
        '${elapsedTime.inMinutes}:${(elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF353535) : const Color(0xFFF9F9F9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: InkWell(
        onTap: widget.onToggleExpand,
        child: Row(
          children: [
            // KOT Number
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.kotNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Order details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (order.tableNumber != null)
                        Text(
                          '🪑 Table ${order.tableNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      if (order.customerName != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '👤 ${order.customerName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.allItems.length} items • ${order.completionPercentage.toStringAsFixed(0)}% done',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Timer
            Column(
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: order.isDelayed ? Colors.red : Colors.green,
                  ),
                ),
                Text(
                  'elapsed',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Expand icon
            Icon(
              widget.isExpanded ? Icons.expand_less : Icons.expand_more,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, KOTOrder order) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.completionPercentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                order.completionPercentage == 100 ? Colors.green : Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Batches
          ...order.batches.map(
            (batch) => _buildBatchSection(isDarkMode, batch),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSection(bool isDarkMode, KOTBatch batch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: batch.isNewItemBatch
            ? Colors.orange.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        border: Border.all(
          color: batch.isNewItemBatch
              ? Colors.orange
              : Colors.grey[300] ?? Colors.grey,
          width: batch.isNewItemBatch ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch header
          Row(
            children: [
              if (batch.isNewItemBatch)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '🆕 NEW ITEMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Batch #${batch.batchNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${batch.readyItems}/${batch.items.length} ready',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items
          ...batch.items.map((item) => _buildItemRow(isDarkMode, item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(bool isDarkMode, KOTItem item) {
    final statusColor = _getStatusColor(item.status);
    final statusEmoji = _getStatusEmoji(item.status);

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF353535) : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Status
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(statusEmoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 8),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}x ${item.itemName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.specialInstructions != null)
                  Text(
                    item.specialInstructions!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Status buttons (only if preparing)
          if (item.status == KOTItemStatus.pending ||
              item.status == KOTItemStatus.preparing)
            _buildStatusButtons(item),
        ],
      ),
    );
  }

  Widget _buildStatusButtons(KOTItem item) {
    final nextStatus = item.status == KOTItemStatus.pending
        ? KOTItemStatus.preparing
        : KOTItemStatus.ready;

    final nextEmoji = nextStatus == KOTItemStatus.preparing ? '👨‍🍳' : '✅';

    return ElevatedButton(
      onPressed: () {
        widget.onStatusChanged(item, nextStatus);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        backgroundColor: _getStatusColor(nextStatus),
      ),
      child: Text(nextEmoji, style: const TextStyle(fontSize: 12)),
    );
  }

  Color _getStatusColor(KOTItemStatus status) {
    switch (status) {
      case KOTItemStatus.pending:
        return Colors.grey;
      case KOTItemStatus.preparing:
        return Colors.orange;
      case KOTItemStatus.ready:
        return Colors.green;
      case KOTItemStatus.served:
        return Colors.blue;
      case KOTItemStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusEmoji(KOTItemStatus status) {
    switch (status) {
      case KOTItemStatus.pending:
        return '⏰';
      case KOTItemStatus.preparing:
        return '👨‍🍳';
      case KOTItemStatus.ready:
        return '✅';
      case KOTItemStatus.served:
        return '🍽️';
      case KOTItemStatus.cancelled:
        return '❌';
    }
  }
}

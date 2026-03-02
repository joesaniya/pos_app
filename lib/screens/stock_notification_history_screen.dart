// lib/screens/notification_history_screen.dart
// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION HISTORY SCREEN
//  Role-gated: Admin & Manager only
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_modal.dart';
import 'package:pos_app/services/stock_notification_service.dart';
import 'package:pos_app/services/storage_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({Key? key}) : super(key: key);
  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  List<StockNotificationRecord> _notifications = [];
  bool _loading = true;
  String _role = '';
  String _businessId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userData  = await StorageService.instance.getUserData();
    _role       = userData['role'] as String? ?? '';
    _businessId = userData['businessId'] as String? ?? '';

    if (_canView) {
      _notifications = await StockNotificationService.instance.fetchHistory(
        businessId: _businessId,
      );
    }
    setState(() => _loading = false);
  }

  bool get _canView => ['admin','manager'].contains(_role.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      body: Column(children: [
        // Header
        Container(
          color: const Color(0xFF1B4D3E),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 18,
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Stock Alerts', style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
            ),
            if (_canView && _notifications.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  await StockNotificationService.instance.markAllRead(_businessId);
                  setState(() {
                    _notifications = _notifications.map((n) =>
                        StockNotificationRecord(
                          id: n.id, businessId: n.businessId, itemId: n.itemId,
                          itemName: n.itemName, type: n.type, title: n.title,
                          body: n.body, currentStock: n.currentStock,
                          minThreshold: n.minThreshold, unit: n.unit,
                          severity: n.severity, isRead: true, sentAt: n.sentAt,
                        )).toList();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Mark all read', style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B4D3E)))
              : !_canView
                  ? _NoAccessView()
                  : _notifications.isEmpty
                      ? _EmptyView()
                      : RefreshIndicator(
                          color: const Color(0xFF1B4D3E),
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _NotifCard(notif: _notifications[i],
                                onTap: () async {
                                  if (!_notifications[i].isRead) {
                                    await StockNotificationService.instance
                                        .markRead(_notifications[i].id);
                                    setState(() {
                                      final n = _notifications[i];
                                      _notifications[i] = StockNotificationRecord(
                                        id: n.id, businessId: n.businessId, itemId: n.itemId,
                                        itemName: n.itemName, type: n.type, title: n.title,
                                        body: n.body, currentStock: n.currentStock,
                                        minThreshold: n.minThreshold, unit: n.unit,
                                        severity: n.severity, isRead: true, sentAt: n.sentAt,
                                      );
                                    });
                                  }
                                }),
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final StockNotificationRecord notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (notif.severity) {
      NotificationSeverity.critical => (const Color(0xFFCC3300), const Color(0xFFFFEDE8)),
      NotificationSeverity.warning  => (const Color(0xFFB8800A), const Color(0xFFFFF3DC)),
      _                             => (const Color(0xFF1E8A5E), const Color(0xFFE6F5EE)),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : bg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: notif.isRead ? const Color(0xFFEEEDF0) : color.withOpacity(0.3),
              width: notif.isRead ? 1 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: notif.isRead ? const Color(0xFFEEEDF0) : color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(notif.type.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(notif.title, style: TextStyle(fontSize: 13,
                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                        color: const Color(0xFF1A1A28)),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (!notif.isRead)
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 4),
                  Text(notif.body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B80)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (notif.currentStock != null && notif.unit != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                        child: Text('${notif.currentStock!.toStringAsFixed(1)} ${notif.unit!}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ),
                    const Spacer(),
                    Text(_timeLabel(notif.sentAt),
                        style: const TextStyle(fontSize: 10, color: Color(0xFFAAABBB))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _NoAccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔒', style: TextStyle(fontSize: 48)),
      SizedBox(height: 16),
      Text('Access Restricted', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: Color(0xFF1A1A28))),
      SizedBox(height: 6),
      Text('Only Admins and Managers can\nview stock notifications',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6B80))),
    ]),
  );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔔', style: TextStyle(fontSize: 48)),
      SizedBox(height: 16),
      Text('No alerts yet', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: Color(0xFF1A1A28))),
      SizedBox(height: 6),
      Text('Stock alerts will appear here when items\nreach critical levels',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B6B80))),
    ]),
  );
}
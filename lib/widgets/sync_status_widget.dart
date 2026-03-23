// lib/widgets/sync_status_widget.dart
// ══════════════════════════════════════════════════════════════════════════════
//  SYNC STATUS WIDGET
//  Shows current offline/online/pending/syncing status in the app.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/services/offline_sync_service.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkStatus>(
      valueListenable: NetworkStatusNotifier(),
      builder: (context, networkStatus, _) {
        return ValueListenableBuilder<SyncState>(
          valueListenable: OfflineSyncService.instance.syncState,
          builder: (context, syncState, _) {
            return _SyncBannerContent(network: networkStatus, sync: syncState);
          },
        );
      },
    );
  }
}

class _SyncBannerContent extends StatelessWidget {
  final NetworkStatus network;
  final SyncState sync;
  const _SyncBannerContent({required this.network, required this.sync});

  @override
  Widget build(BuildContext context) {
    // Determine what to show
    final isOffline = network == NetworkStatus.offline;
    final isSyncing = sync.phase == SyncPhase.syncing;
    final hasPending = sync.pendingCount > 0;

    if (!isOffline && !isSyncing && !hasPending) {
      return const SizedBox.shrink(); // All synced — show nothing
    }

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (isOffline) {
      bgColor = Colors.red.shade700;
      textColor = Colors.white;
      icon = Icons.wifi_off_rounded;
      message = 'Offline — changes saved locally';
    } else if (isSyncing) {
      bgColor = Colors.blue.shade600;
      textColor = Colors.white;
      icon = Icons.sync_rounded;
      message = 'Syncing ${sync.pendingCount} items…';
    } else if (hasPending) {
      bgColor = Colors.orange.shade700;
      textColor = Colors.white;
      icon = Icons.cloud_upload_outlined;
      message = '${sync.pendingCount} item${sync.pendingCount == 1 ? '' : 's'} pending sync';
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isSyncing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasPending && !isOffline && !isSyncing)
            GestureDetector(
              onTap: () => OfflineSyncService.instance.processPendingQueue(),
              child: Text(
                'Sync now',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Compact chip for use in AppBar actions ────────────────────────────────
class SyncStatusChip extends StatefulWidget {
  const SyncStatusChip({super.key});

  @override
  State<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends State<SyncStatusChip> {
  late final NetworkStatusNotifier _networkNotifier;

  @override
  void initState() {
    super.initState();
    _networkNotifier = NetworkStatusNotifier();
  }

  @override
  void dispose() {
    _networkNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkStatus>(
      valueListenable: _networkNotifier,
      builder: (context, network, _) {
        return ValueListenableBuilder<SyncState>(
          valueListenable: OfflineSyncService.instance.syncState,
          builder: (context, sync, _) {
            final isOffline = network == NetworkStatus.offline;
            final isSyncing = sync.phase == SyncPhase.syncing;
            final hasPending = sync.pendingCount > 0;

            if (!isOffline && !isSyncing && !hasPending) {
              return const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20);
            }

            if (isOffline) {
              return const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 20);
            }
            if (isSyncing) {
              return const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
              );
            }
            return Badge(
              label: Text('${sync.pendingCount}', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 20),
            );
          },
        );
      },
    );
  }
}

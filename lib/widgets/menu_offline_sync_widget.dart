import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/theme/app_colors.dart';

/// Status indicator for menu offline/sync status
class MenuOfflineStatusBar extends StatelessWidget {
  const MenuOfflineStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, SupabaseMenuProvider>(
      builder: (_, connectivity, menuProvider, __) {
        final isOnline = connectivity.isOnline;
        final hasOfflineChanges = menuProvider.hasOfflineChanges;
        final pendingCount = menuProvider.pendingSyncCount;
        final syncState = menuProvider.syncState;

        // No status bar if online and synced
        if (isOnline && !hasOfflineChanges) {
          return const SizedBox.shrink();
        }

        // Offline mode
        if (!isOnline) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.orange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline mode - Changes will sync when online',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          );
        }

        // Syncing
        if (syncState == MenuSyncState.syncing) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Syncing $pendingCount changes...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          );
        }

        // Pending sync
        if (hasOfflineChanges) {
          log('connetivity:$isOnline==>check:$hasOfflineChanges');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFFFF8E1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_rounded,
                  size: 16,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '$pendingCount offline change${pendingCount == 1 ? '' : 's'} pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Compact offline status indicator for menu item/category cards
class MenuOfflineStatusBadge extends StatelessWidget {
  final bool isOfflineOnly;
  final bool isSyncPending;

  const MenuOfflineStatusBadge({
    Key? key,
    this.isOfflineOnly = false,
    this.isSyncPending = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOfflineOnly && !isSyncPending) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOfflineOnly ? Colors.orange.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOfflineOnly ? Colors.orange.shade300 : Colors.blue.shade300,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOfflineOnly
                ? Icons.cloud_off_rounded
                : Icons.cloud_upload_rounded,
            size: 12,
            color: isOfflineOnly
                ? Colors.orange.shade700
                : Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isOfflineOnly ? 'Offline' : 'Syncing...',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOfflineOnly
                  ? Colors.orange.shade700
                  : Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection status widget
class ConnectionStatusWidget extends StatelessWidget {
  final double? fontSize;

  const ConnectionStatusWidget({Key? key, this.fontSize = 12})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (_, connectivity, __) {
        final isOnline = connectivity.isOnline;
        return Tooltip(
          message: isOnline ? 'Connected online' : 'Offline mode',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: (fontSize ?? 12) + 2,
                color: isOnline ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: fontSize ?? 12,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Action button for menu operations (disabled offline in specific scenarios)
class MenuActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool disableOffline;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  const MenuActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.disableOffline = false,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (_, connectivity, __) {
        final isOnline = connectivity.isOnline;
        final isDisabled = !isOnline && disableOffline;

        return ElevatedButton.icon(
          onPressed: isDisabled || isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      foregroundColor ?? Colors.white,
                    ),
                  ),
                )
              : (icon != null ? Icon(icon) : const SizedBox.shrink()),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primaryPurple,
            foregroundColor: foregroundColor ?? Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
          ),
        );
      },
    );
  }
}

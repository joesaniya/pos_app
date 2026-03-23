// lib/widgets/sync_status_widget.dart
// ══════════════════════════════════════════════════════════════════════════════
//  NETWORK SYNC TRACKER BAR
//  A slim, status-bar-style banner fixed at the very top of the app body.
//  Sits flush below the system status bar, above all other content.
//  States: offline • syncing • pending • synced (auto-hides) • hidden
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/network_sync_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PUBLIC WIDGET — place once at the top of PageSwitcher's Column
// ─────────────────────────────────────────────────────────────────────────────

class NetworkSyncTrackerBar extends StatelessWidget {
  const NetworkSyncTrackerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkSyncProvider>(
      builder: (context, provider, _) {
        return _TrackerBar(provider: provider);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TRACKER BAR — animated height collapse when hidden
// ─────────────────────────────────────────────────────────────────────────────

class _TrackerBar extends StatelessWidget {
  final NetworkSyncProvider provider;
  const _TrackerBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.trackerState;
    final isVisible = state != TrackerState.hidden;
    final config = _BarConfig.from(state, provider.pendingCount);

    // Keep system status bar icons light when our banner is visible
    if (isVisible) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: isVisible
          ? _BarContent(state: state, config: config, provider: provider)
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BAR CONTENT — the actual visible strip
// ─────────────────────────────────────────────────────────────────────────────

class _BarContent extends StatelessWidget {
  final TrackerState state;
  final _BarConfig config;
  final NetworkSyncProvider provider;

  const _BarContent({
    required this.state,
    required this.config,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      // Compact height: status-bar area + 26px for our content strip
      height: topPadding + 26,
      decoration: BoxDecoration(
        gradient: config.gradient,
        boxShadow: [
          BoxShadow(
            color: config.shadowColor.withOpacity(0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ── Content row sits in the 26px strip below system status bar ──
          SizedBox(
            height: 26,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Leading icon / spinner
                  _LeadingIndicator(state: state, color: config.iconColor),
                  const SizedBox(width: 7),

                  // Status message
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        config.message,
                        key: ValueKey(config.message),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: config.textColor,
                          letterSpacing: 0.15,
                          height: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),

                  // Trailing: "Sync now" pill (pending) or checkmark (synced)
                  if (state == TrackerState.pending)
                    _SyncNowButton(
                      onTap: provider.syncNow,
                      textColor: config.textColor,
                    )
                  else if (state == TrackerState.synced)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: config.iconColor,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LEADING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _LeadingIndicator extends StatelessWidget {
  final TrackerState state;
  final Color color;
  const _LeadingIndicator({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    if (state == TrackerState.syncing) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    final icon = switch (state) {
      TrackerState.offline => Icons.wifi_off_rounded,
      TrackerState.pending => Icons.cloud_upload_outlined,
      TrackerState.synced  => Icons.cloud_done_rounded,
      _                    => Icons.sync_rounded,
    };

    return Icon(icon, size: 13, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SYNC NOW BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SyncNowButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color textColor;
  const _SyncNowButton({required this.onTap, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.45),
            width: 0.8,
          ),
        ),
        child: Text(
          'Sync now',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BAR CONFIG
// ─────────────────────────────────────────────────────────────────────────────

class _BarConfig {
  final LinearGradient gradient;
  final Color textColor;
  final Color iconColor;
  final Color shadowColor;
  final String message;

  const _BarConfig({
    required this.gradient,
    required this.textColor,
    required this.iconColor,
    required this.shadowColor,
    required this.message,
  });

  factory _BarConfig.from(TrackerState state, int pendingCount) {
    switch (state) {
      case TrackerState.offline:
        return const _BarConfig(
          gradient: LinearGradient(
            colors: [Color(0xFFC62828), Color(0xFFD32F2F)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          iconColor: Color(0xFFFFCDD2),
          shadowColor: Color(0xFFC62828),
          message: 'No internet — changes saved locally',
        );

      case TrackerState.syncing:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          iconColor: const Color(0xFFBBDEFB),
          shadowColor: const Color(0xFF1565C0),
          message:
              'Syncing $pendingCount item${pendingCount == 1 ? '' : 's'}…',
        );

      case TrackerState.pending:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFEF6C00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          iconColor: const Color(0xFFFFE0B2),
          shadowColor: const Color(0xFFE65100),
          message:
              '$pendingCount item${pendingCount == 1 ? '' : 's'} pending sync',
        );

      case TrackerState.synced:
        return const _BarConfig(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          iconColor: Color(0xFFC8E6C9),
          shadowColor: Color(0xFF2E7D32),
          message: 'All synced successfully!',
        );

      case TrackerState.hidden:
        return const _BarConfig(
          gradient: LinearGradient(
              colors: [Colors.transparent, Colors.transparent]),
          textColor: Colors.transparent,
          iconColor: Colors.transparent,
          shadowColor: Colors.transparent,
          message: '',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPAT EXPORT
// ─────────────────────────────────────────────────────────────────────────────

@Deprecated('Use NetworkSyncTrackerBar placed in PageSwitcher')
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/*
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/network_sync_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PUBLIC WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Main tracker bar — place once in PageSwitcher, above the IndexedStack.
class NetworkSyncTrackerBar extends StatelessWidget {
  const NetworkSyncTrackerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkSyncProvider>(
      builder: (context, provider, _) {
        return _TrackerBarContent(provider: provider);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INTERNAL CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _TrackerBarContent extends StatelessWidget {
  final NetworkSyncProvider provider;
  const _TrackerBarContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.trackerState;
    final isVisible = state != TrackerState.hidden;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isVisible
          ? _TrackerBarBody(state: state, provider: provider)
          : const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BAR BODY
// ─────────────────────────────────────────────────────────────────────────────

class _TrackerBarBody extends StatelessWidget {
  final TrackerState state;
  final NetworkSyncProvider provider;

  const _TrackerBarBody({required this.state, required this.provider});

  @override
  Widget build(BuildContext context) {
    final config = _BarConfig.from(state, provider.pendingCount);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: config.gradient,
        boxShadow: [
          BoxShadow(
            color: config.shadowColor.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              // ── Leading indicator / icon ──────────────────────────────────
              _LeadingIndicator(state: state, color: config.textColor),
              const SizedBox(width: 10),

              // ── Message ───────────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    config.message,
                    key: ValueKey(config.message),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: config.textColor,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // ── Trailing action (only for pending state) ──────────────────
              if (state == TrackerState.pending)
                _SyncNowButton(
                  onTap: provider.syncNow,
                  textColor: config.textColor,
                ),

              // ── Synced checkmark ─────────────────────────────────────────
              if (state == TrackerState.synced)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: config.textColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LEADING INDICATOR — spinning loader OR static icon
// ─────────────────────────────────────────────────────────────────────────────

class _LeadingIndicator extends StatelessWidget {
  final TrackerState state;
  final Color color;
  const _LeadingIndicator({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    if (state == TrackerState.syncing) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    final icon = switch (state) {
      TrackerState.offline  => Icons.wifi_off_rounded,
      TrackerState.pending  => Icons.cloud_upload_outlined,
      TrackerState.synced   => Icons.cloud_done_rounded,
      _                     => Icons.sync_rounded,
    };

    return Icon(icon, size: 15, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SYNC NOW BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SyncNowButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color textColor;
  const _SyncNowButton({required this.onTap, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.8),
        ),
        child: Text(
          'Sync now',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BAR CONFIG — gradient, icons, messages per state
// ─────────────────────────────────────────────────────────────────────────────

class _BarConfig {
  final LinearGradient gradient;
  final Color textColor;
  final Color shadowColor;
  final String message;

  const _BarConfig({
    required this.gradient,
    required this.textColor,
    required this.shadowColor,
    required this.message,
  });

  factory _BarConfig.from(TrackerState state, int pendingCount) {
    switch (state) {
      case TrackerState.offline:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          shadowColor: const Color(0xFFD32F2F),
          message: 'You\'re offline — actions are saved locally',
        );

      case TrackerState.syncing:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          shadowColor: const Color(0xFF1565C0),
          message: 'Syncing $pendingCount item${pendingCount == 1 ? '' : 's'} to cloud…',
        );

      case TrackerState.pending:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFF57C00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          shadowColor: const Color(0xFFE65100),
          message: '$pendingCount item${pendingCount == 1 ? '' : 's'} pending sync',
        );

      case TrackerState.synced:
        return _BarConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          textColor: Colors.white,
          shadowColor: const Color(0xFF2E7D32),
          message: 'All synced successfully!',
        );

      case TrackerState.hidden:
        return _BarConfig(
          gradient: const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
          textColor: Colors.transparent,
          shadowColor: Colors.transparent,
          message: '',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPAT EXPORTS — keep old names so existing imports don't break
// ─────────────────────────────────────────────────────────────────────────────

/// @deprecated Use [NetworkSyncTrackerBar] instead.
@Deprecated('Use NetworkSyncTrackerBar placed in PageSwitcher')
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
*/
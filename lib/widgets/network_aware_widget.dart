// lib/widgets/network_aware_widget.dart
// ══════════════════════════════════════════════════════════════════════════════
//  NETWORK AWARE WIDGET
//  A transparent pass-through wrapper kept for backward-compatibility.
//  The actual offline/sync UI is now handled by NetworkSyncTrackerBar,
//  placed inside PageSwitcher below the AppBar.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class NetworkAwareWidget extends StatelessWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // All network/sync UI is now rendered by NetworkSyncTrackerBar in
    // PageSwitcher. This widget is kept as a no-op wrapper so any existing
    // usages throughout the codebase continue to compile without change.
    return child;
  }
}

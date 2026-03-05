import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/add_edit_table_sheet.dart';
import 'package:pos_app/screens/tables_screen/sheet/table_etail_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/views/table_history_view.dart';
import 'package:pos_app/screens/tables_screen/widgets/table_card_widgets.dart';
import 'package:pos_app/screens/tables_screen/widgets/view_toggle_widgets.dart';
import 'package:provider/provider.dart';
import 'widgets/floor_widgets.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/today_reservations_widget.dart';
import 'views/table_calendar_view.dart';

// ═════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TablesProvider(),
      child: const _TablesBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  MAIN BODY
// ═════════════════════════════════════════════════════════════
class _TablesBody extends StatefulWidget {
  const _TablesBody();

  @override
  State<_TablesBody> createState() => _TablesBodyState();
}

class _TablesBodyState extends State<_TablesBody> {
  TabView _currentView = TabView.floor;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<TablesProvider>(
      builder: (ctx, prov, _) {
        if (prov.isLoading && prov.allTables.isEmpty) {
          return Scaffold(
            backgroundColor: TC.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: TC.accent),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading tables…',
                    style: TextStyle(color: TC.textSec),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: TC.bg,
          floatingActionButton:
              _currentView == TabView.floor && prov.canManageTables
              ? AddTableFAB(onTap: () => _openAddTable(ctx, prov))
              : null,
          body: SafeArea(
            child: Column(
              children: [
                // ── Static top bar — never scrolls ──────────────────
                TableHeader(prov: prov),
                ViewToggle(
                  current: _currentView,
                  onChanged: (v) {
                    setState(() => _currentView = v);
                    if (v == TabView.history) prov.loadHistory(reset: true);
                  },
                ),

                // ── Animated scrollable body ─────────────────────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: switch (_currentView) {
                      TabView.floor => _FloorView(
                        key: const ValueKey('tables'),
                        prov: prov,
                        onViewAllReservations: () =>
                            _openTodayReservations(ctx, prov),
                      ),
                      TabView.calendar => CalendarView(
                        key: const ValueKey('cal'),
                        prov: prov,
                      ),
                      TabView.history => HistoryView(
                        key: const ValueKey('history'),
                        prov: prov,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddTable(BuildContext ctx, TablesProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: AddEditTableSheet(provider: prov),
      ),
    );
  }

  void _openTodayReservations(BuildContext ctx, TablesProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: TodayReservationsSheet(prov: prov),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  FLOOR VIEW
// ═════════════════════════════════════════════════════════════
class _FloorView extends StatefulWidget {
  final TablesProvider prov;
  final VoidCallback onViewAllReservations;

  const _FloorView({
    super.key,
    required this.prov,
    required this.onViewAllReservations,
  });

  @override
  State<_FloorView> createState() => _FloorViewState();
}

class _FloorViewState extends State<_FloorView> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.prov;

    return RefreshIndicator(
      color: TC.accent,
      edgeOffset: 0,
      onRefresh: () => prov.refresh(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ① Alert banners ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UpcomingBanner(prov: prov),
                EndingSoonBanner(prov: prov),
                LongSeatedBanner(prov: prov),
              ],
            ),
          ),

          // ② Summary stats bar ──────────────────────────────────
          SliverToBoxAdapter(child: SummaryBar(prov: prov)),

          // ③ Today / Tomorrow reservation strip ─────────────────
          SliverToBoxAdapter(
            child: TodayReservationStrip(
              prov: prov,
              onViewAll: widget.onViewAllReservations,
            ),
          ),

          // ④ Section tabs + status filter (sticky) ──────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabsDelegate(prov: prov),
          ),

          // ⑤ Table grid (as proper slivers — no ListView!) ───────
          if (prov.filteredTables.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState())
          else
            ..._buildTableSlivers(prov),
        ],
      ),
    );
  }

  List<Widget> _buildTableSlivers(TablesProvider prov) {
    final sections = prov.selectedSection != null
        ? [prov.selectedSection!]
        : TableSection.values;

    final slivers = <Widget>[];

    for (final sec in sections) {
      final tables = prov.filteredTables
          .where((t) => t.section == sec)
          .toList();
      if (tables.isEmpty) continue;

      final color = sectionColor(sec);
      final bg = sectionBg(sec);
      final avail = tables
          .where((t) => t.status == TableStatus.available)
          .length;

      // ─── Section header pill ──────────────────────────────────
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sec.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        sec.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· ${sec.floor}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$avail of ${tables.length} available',
                  style: const TextStyle(fontSize: 11, color: TC.textMute),
                ),
              ],
            ),
          ),
        ),
      );

      // ─── Table cards grid ─────────────────────────────────────
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.02,
              // childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => TableCard(
                table: tables[i],
                prov: prov,
                onTap: () => _openDetail(ctx, tables[i], prov),
              ),
              childCount: tables.length,
            ),
          ),
        ),
      );

      // ─── Gap after each section ───────────────────────────────
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    }

    // Extra bottom padding so FAB doesn't cover the last card
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 104)));

    return slivers;
  }

  void _openDetail(
    BuildContext ctx,
    RestaurantTable table,
    TablesProvider prov,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: TableDetailSheet(table: table),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STICKY TABS DELEGATE
// ─────────────────────────────────────────────────────────────
class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  final TablesProvider prov;
  const _StickyTabsDelegate({required this.prov});

  // SectionTabs ≈ 44px  +  StatusFilterRow ≈ 44px  =  88px
  static const double _h = 88.0;

  @override
  double get minExtent => _h;

  @override
  double get maxExtent => _h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: TC.bg,
      elevation: overlapsContent ? 3 : 0,
      shadowColor: Colors.black12,
      child: SizedBox(
        height: _h,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTabs(prov: prov),
            StatusFilterRow(prov: prov),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabsDelegate old) => true;
}

/*//nt scroll
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/screens/tables_screen/sheet/add_edit_table_sheet.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';
import 'package:pos_app/screens/tables_screen/views/table_history_view.dart';
import 'package:pos_app/screens/tables_screen/widgets/table_card_widgets.dart';
import 'package:pos_app/screens/tables_screen/widgets/view_toggle_widgets.dart';
import 'package:provider/provider.dart';
import 'widgets/floor_widgets.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/today_reservations_widget.dart'; // ← NEW
import 'views/table_calendar_view.dart';

// ═════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TablesProvider(),
      child: const _TablesBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  MAIN BODY
// ═════════════════════════════════════════════════════════════
class _TablesBody extends StatefulWidget {
  const _TablesBody();
  @override
  State<_TablesBody> createState() => _TablesBodyState();
}

class _TablesBodyState extends State<_TablesBody> {
  TabView _currentView = TabView.floor;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return Consumer<TablesProvider>(
      builder: (ctx, prov, _) {
        if (prov.isLoading && prov.allTables.isEmpty) {
          return Scaffold(
            backgroundColor: TC.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: TC.accent),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading tables…',
                    style: TextStyle(color: TC.textSec),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: TC.bg,
          floatingActionButton:
              _currentView == TabView.floor && prov.canManageTables
              ? AddTableFAB(onTap: () => _openAddTable(ctx, prov))
              : null,
          body: SafeArea(
            child: RefreshIndicator(
              color: TC.accent,
              onRefresh: () => prov.refresh(),
              child: Column(
                children: [
                  TableHeader(prov: prov),
                  ViewToggle(
                    current: _currentView,
                    onChanged: (v) {
                      setState(() => _currentView = v);
                      if (v == TabView.history) {
                        prov.loadHistory(reset: true);
                      }
                    },
                  ),
                  UpcomingBanner(prov: prov),
                  EndingSoonBanner(prov: prov),
                  // ── NEW: long-seated alert banner ─────────────
                  LongSeatedBanner(prov: prov),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: switch (_currentView) {
                        TabView.floor => Column(
                          key: const ValueKey('tables'),
                          children: [
                            SummaryBar(prov: prov),
                            // ── NEW: Today/Tomorrow strip ─────
                            TodayReservationStrip(
                              prov: prov,
                              onViewAll: () =>
                                  _openTodayReservations(ctx, prov),
                            ),
                            SectionTabs(prov: prov),
                            StatusFilterRow(prov: prov),
                            Expanded(
                              child: prov.filteredTables.isEmpty
                                  ? const EmptyState()
                                  : TableGrid(prov: prov),
                            ),
                          ],
                        ),
                        TabView.calendar => CalendarView(
                          key: const ValueKey('cal'),
                          prov: prov,
                        ),
                        TabView.history => HistoryView(
                          key: const ValueKey('history'),
                          prov: prov,
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddTable(BuildContext ctx, TablesProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: AddEditTableSheet(provider: prov),
      ),
    );
  }

  void _openTodayReservations(BuildContext ctx, TablesProvider prov) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: prov,
        child: TodayReservationsSheet(prov: prov),
      ),
    );
  }
}
*/

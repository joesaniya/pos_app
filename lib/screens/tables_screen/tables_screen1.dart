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
                  const Text('Loading tables…', style: TextStyle(color: TC.textSec)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: TC.bg,
          floatingActionButton: _currentView == TabView.floor && prov.canManageTables
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
}
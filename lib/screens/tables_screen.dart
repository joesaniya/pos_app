/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class TC {
  static const bg = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFF7F4EE);
  static const border = Color(0xFFE8E3D8);
  static const borderLight = Color(0xFFF0ECE4);

  static const accent = Color(0xFFC25A2A);
  static const accentLight = Color(0xFFFAEDE5);
  static const accentMid = Color(0xFFD97B47);

  static const acBlue = Color(0xFF1A6BB5);
  static const acBlueBg = Color(0xFFE8F2FC);
  static const nonAcAmber = Color(0xFFB8730A);
  static const nonAcBg = Color(0xFFFFF4DC);
  static const rooftopTeal = Color(0xFF1A8070);
  static const rooftopBg = Color(0xFFE4F5F2);
  static const gardenGreen = Color(0xFF2E7D32);
  static const gardenBg = Color(0xFFE8F5E9);
  static const privatePurp = Color(0xFF6B3FA0);
  static const privateBg = Color(0xFFF3EBF9);

  static const available = Color(0xFF2E7D32);
  static const availableBg = Color(0xFFE8F5E9);
  static const occupied = Color(0xFFC25A2A);
  static const occupiedBg = Color(0xFFFAEDE5);
  static const reserved = Color(0xFF1A6BB5);
  static const reservedBg = Color(0xFFE8F2FC);
  static const cleaning = Color(0xFF888898);
  static const cleaningBg = Color(0xFFF3F3F8);

  static const textPri = Color(0xFF1E1A14);
  static const textSec = Color(0xFF7A705E);
  static const textMute = Color(0xFFB0A898);
  static const divider = Color(0xFFEEE9E0);
}

// ── Section / Status helpers ──────────────────────────────────
Color _sectionColor(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlue;
    case TableSection.nonAc:
      return TC.nonAcAmber;
    case TableSection.rooftop:
      return TC.rooftopTeal;
    case TableSection.garden:
      return TC.gardenGreen;
    case TableSection.privateRoom:
      return TC.privatePurp;
  }
}

Color _sectionBg(TableSection s) {
  switch (s) {
    case TableSection.ac:
      return TC.acBlueBg;
    case TableSection.nonAc:
      return TC.nonAcBg;
    case TableSection.rooftop:
      return TC.rooftopBg;
    case TableSection.garden:
      return TC.gardenBg;
    case TableSection.privateRoom:
      return TC.privateBg;
  }
}

Color _statusColor(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.available;
    case TableStatus.occupied:
      return TC.occupied;
    case TableStatus.reserved:
      return TC.reserved;
    case TableStatus.cleaning:
      return TC.cleaning;
  }
}

Color _statusBg(TableStatus s) {
  switch (s) {
    case TableStatus.available:
      return TC.availableBg;
    case TableStatus.occupied:
      return TC.occupiedBg;
    case TableStatus.reserved:
      return TC.reservedBg;
    case TableStatus.cleaning:
      return TC.cleaningBg;
  }
}

// ═════════════════════════════════════════════════════════════
//  VIEW ENUM
// ═════════════════════════════════════════════════════════════
enum _TabView { floor, calendar, history }

// ═════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═════════════════════════════════════════════════════════════
class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

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
  _TabView _currentView = _TabView.floor;

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
              _currentView == _TabView.floor && prov.canManageTables
              ? _AddTableFAB(onTap: () => _openAddTable(ctx, prov))
              : null,
          body: SafeArea(
            child: RefreshIndicator(
              color: TC.accent,
              onRefresh: () => prov.refresh(),
              child: Column(
                children: [
                  _Header(prov: prov),
                  _ViewToggle(
                    current: _currentView,
                    onChanged: (v) {
                      setState(() => _currentView = v);
                      if (v == _TabView.history) {
                        prov.loadHistory(reset: true);
                      }
                    },
                  ),
                  _UpcomingBanner(prov: prov),
                  _EndingSoonBanner(prov: prov),
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
                        _TabView.floor => Column(
                          key: const ValueKey('tables'),
                          children: [
                            _SummaryBar(prov: prov),
                            _SectionTabs(prov: prov),
                            _StatusFilterRow(prov: prov),
                            Expanded(
                              child: prov.filteredTables.isEmpty
                                  ? const _EmptyState()
                                  : _TableGrid(prov: prov),
                            ),
                          ],
                        ),
                        _TabView.calendar => _CalendarView(
                          key: const ValueKey('cal'),
                          prov: prov,
                        ),
                        _TabView.history => _HistoryView(
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
        child: _AddEditTableSheet(provider: prov),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  UPCOMING BANNER
// ─────────────────────────────────────────────────────────────
class _UpcomingBanner extends StatelessWidget {
  final TablesProvider prov;
  const _UpcomingBanner({required this.prov});

  @override
  Widget build(BuildContext context) {
    final upcoming = prov.upcomingReservations(30);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TC.nonAcBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.nonAcAmber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${upcoming.length} reservation${upcoming.length > 1 ? 's' : ''} arriving within 30 minutes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.nonAcAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ENDING SOON BANNER  — 15-min checkout warning
// ─────────────────────────────────────────────────────────────
class _EndingSoonBanner extends StatelessWidget {
  final TablesProvider prov;
  const _EndingSoonBanner({required this.prov});

  @override
  Widget build(BuildContext context) {
    final ending = prov.endingSoonTables;
    if (ending.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TC.occupiedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TC.occupied.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${ending.length} reservation${ending.length > 1 ? 's' : ''} ending within 15 minutes',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.occupied,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HEADER
// ═════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final TablesProvider prov;
  const _Header({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: TC.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: TC.accent.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_bar_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tables',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: TC.textPri,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  '${prov.totalTables} tables · ${prov.totalAvailable} available'
                  '${prov.currentBusinessName.isNotEmpty ? ' · ${prov.currentBusinessName}' : ''}',
                  style: const TextStyle(fontSize: 12, color: TC.textSec),
                ),
              ],
            ),
          ),
          if (prov.totalReserved > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: TC.reservedBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TC.reserved.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    '${prov.totalReserved} reserved',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TC.reserved,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  VIEW TOGGLE  (3 tabs)
// ═════════════════════════════════════════════════════════════
class _ViewToggle extends StatelessWidget {
  final _TabView current;
  final ValueChanged<_TabView> onChanged;
  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TC.border),
        ),
        child: Row(
          children: [
            _ToggleTab(
              label: 'Floor',
              icon: Icons.grid_view_rounded,
              selected: current == _TabView.floor,
              onTap: () => onChanged(_TabView.floor),
            ),
            _ToggleTab(
              label: 'Calendar',
              icon: Icons.calendar_month_rounded,
              selected: current == _TabView.calendar,
              onTap: () => onChanged(_TabView.calendar),
            ),
            _ToggleTab(
              label: 'History',
              icon: Icons.history_rounded,
              selected: current == _TabView.history,
              onTap: () => onChanged(_TabView.history),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? TC.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? TC.accent : TC.textMute),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? TC.accent : TC.textMute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SUMMARY BAR
// ═════════════════════════════════════════════════════════════
class _SummaryBar extends StatelessWidget {
  final TablesProvider prov;
  const _SummaryBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        children: [
          _MetricPill(
            emoji: '✅',
            label: 'Available',
            value: '${prov.totalAvailable}',
            color: TC.available,
          ),
          _MetricPill(
            emoji: '🍽️',
            label: 'Occupied',
            value: '${prov.totalOccupied}',
            color: TC.occupied,
          ),
          _MetricPill(
            emoji: '📅',
            label: 'Reserved',
            value: '${prov.totalReserved}',
            color: TC.reserved,
          ),
          _MetricPill(
            emoji: '🧹',
            label: 'Cleaning',
            value:
                '${prov.allTables.where((t) => t.status == TableStatus.cleaning).length}',
            color: TC.cleaning,
          ),
          _MetricPill(
            emoji: '📊',
            label: 'Occupancy',
            value: '${(prov.occupancyRate * 100).toStringAsFixed(0)}%',
            color: TC.accent,
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _MetricPill({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: TC.textSec,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SECTION TABS
// ═════════════════════════════════════════════════════════════
class _SectionTabs extends StatelessWidget {
  final TablesProvider prov;
  const _SectionTabs({required this.prov});

  @override
  Widget build(BuildContext context) {
    final sections = [null, ...TableSection.values];
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final s = sections[i];
          final isSel = prov.selectedSection == s;
          final label = s == null ? 'All Floors' : s.label;
          final floor = s == null ? '' : ' · ${s.floor}';
          final color = s == null ? TC.accent : _sectionColor(s);
          final count = s != null
              ? prov.allTables.where((t) => t.section == s).length
              : null;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setSection(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSel ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? color : TC.border,
                    width: isSel ? 0 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s != null) ...[
                      Text(s.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '$label$floor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : TC.textSec,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.25)
                              : TC.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : TC.textMute,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  STATUS FILTER ROW
// ═════════════════════════════════════════════════════════════
class _StatusFilterRow extends StatelessWidget {
  final TablesProvider prov;
  const _StatusFilterRow({required this.prov});

  @override
  Widget build(BuildContext context) {
    const statuses = <TableStatus?>[
      null,
      TableStatus.available,
      TableStatus.occupied,
      TableStatus.reserved,
      TableStatus.cleaning,
    ];
    const labels = ['All', 'Available', 'Occupied', 'Reserved', 'Cleaning'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: List.generate(statuses.length, (i) {
          final s = statuses[i];
          final isSel = prov.selectedStatus == s;
          final color = s == null ? TC.textSec : _statusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => prov.setStatus(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? (s == null ? TC.textPri : _statusBg(s))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? (s == null ? TC.textPri : color) : TC.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSel
                        ? (s == null ? Colors.white : color)
                        : TC.textMute,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  TABLE GRID
// ═════════════════════════════════════════════════════════════
class _TableGrid extends StatelessWidget {
  final TablesProvider prov;
  const _TableGrid({required this.prov});

  @override
  Widget build(BuildContext context) {
    final sections = prov.selectedSection != null
        ? [prov.selectedSection!]
        : TableSection.values;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: sections.map((sec) {
        final tables = prov.filteredTables
            .where((t) => t.section == sec)
            .toList();
        if (tables.isEmpty) return const SizedBox.shrink();
        return _SectionGroup(section: sec, tables: tables, prov: prov);
      }).toList(),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final TableSection section;
  final List<RestaurantTable> tables;
  final TablesProvider prov;
  const _SectionGroup({
    required this.section,
    required this.tables,
    required this.prov,
  });

  @override
  Widget build(BuildContext context) {
    final color = _sectionColor(section);
    final bg = _sectionBg(section);
    final avail = tables.where((t) => t.status == TableStatus.available).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
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
                    Text(section.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      section.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${section.floor}',
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemCount: tables.length,
          itemBuilder: (ctx, i) => _TableCard(
            table: tables[i],
            prov: prov,
            onTap: () => _openDetail(ctx, tables[i], prov),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
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
        child: _TableDetailSheet(table: table),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  TABLE CARD
// ═════════════════════════════════════════════════════════════
class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;

  const _TableCard({
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(table.status);
    final sb = _statusBg(table.status);
    final secCol = _sectionColor(table.section);
    final isActive = table.status == TableStatus.occupied;

    final isSoon =
        table.status == TableStatus.reserved &&
        table.reservation != null &&
        table.reservation!.reservedFor.difference(DateTime.now()).inMinutes <=
            30;

    final isEndingSoon = table.reservation?.isEndingSoon ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEndingSoon
                ? TC.occupied.withOpacity(0.5)
                : isSoon
                ? TC.nonAcAmber.withOpacity(0.5)
                : (isActive ? sc.withOpacity(0.3) : TC.border),
            width: (isSoon || isActive || isEndingSoon) ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? sc.withOpacity(0.10)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (table.isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8DC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('⭐', style: TextStyle(fontSize: 10)),
                ),
              ),
            if (table.hasWindow && !table.isPremium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TC.acBlueBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🪟', style: TextStyle(fontSize: 10)),
                ),
              ),
            if (isSoon)
              Positioned(
                top: 10,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TC.nonAcBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TC.nonAcAmber.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Soon',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TC.nonAcAmber,
                    ),
                  ),
                ),
              ),
            if (isEndingSoon)
              Positioned(
                top: 10,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TC.occupiedBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TC.occupied.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Ending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: TC.occupied,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TableIcon(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              table.tableName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 11,
                                  color: TC.textMute,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${table.capacity} seats',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sb,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          table.status.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: sc,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (table.status == TableStatus.occupied) ...[
                    _CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.currentCustomerName ?? '—',
                    ),
                    const SizedBox(height: 3),
                    _CardInfoRow(
                      icon: Icons.schedule_outlined,
                      text: table.occupiedDuration,
                      color: TC.occupied,
                    ),
                    if (table.currentOrderTotal != null) ...[
                      const SizedBox(height: 3),
                      _CardInfoRow(
                        icon: Icons.receipt_outlined,
                        text: '₹${table.currentOrderTotal!.toInt()}',
                        color: TC.accent,
                      ),
                    ],
                  ] else if (table.status == TableStatus.reserved) ...[
                    _CardInfoRow(
                      icon: Icons.person_outline,
                      text: table.reservation?.customerName ?? '—',
                    ),
                    const SizedBox(height: 3),
                    _CardInfoRow(
                      icon: Icons.access_time_outlined,
                      text: table.reservation?.countdownLabel ?? '',
                      color: TC.reserved,
                    ),
                    if (table.reservation?.checkOut != null) ...[
                      const SizedBox(height: 3),
                      _CardInfoRow(
                        icon: Icons.logout_outlined,
                        text: 'Out: ${table.reservation!.checkOutTimeLabel}',
                        color: TC.textSec,
                      ),
                    ],
                  ] else if (table.status == TableStatus.available) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TC.availableBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TC.available,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Ready to seat',
                            style: TextStyle(
                              fontSize: 10,
                              color: TC.available,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _CardInfoRow(
                      icon: Icons.cleaning_services_outlined,
                      text: 'Being cleaned',
                      color: TC.cleaning,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: secCol,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _CardInfoRow({
    required this.icon,
    required this.text,
    this.color = TC.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TableIcon extends StatelessWidget {
  final TableShape shape;
  final int capacity;
  final Color color, bg;
  final String tableName;
  const _TableIcon({
    required this.shape,
    required this.capacity,
    required this.color,
    required this.bg,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final w = shape == TableShape.rectangle ? 52.0 : 44.0;
    return Container(
      width: w,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape == TableShape.round
            ? BorderRadius.circular(22)
            : shape == TableShape.rectangle
            ? BorderRadius.circular(8)
            : BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        tableName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  CALENDAR VIEW
// ═════════════════════════════════════════════════════════════
class _CalendarView extends StatefulWidget {
  final TablesProvider prov;
  const _CalendarView({Key? key, required this.prov}) : super(key: key);

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _displayMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Set<DateTime> get _reservedDates {
    final dates = <DateTime>{};
    for (final t in widget.prov.allTables) {
      if (t.reservation != null) {
        final d = t.reservation!.reservedFor;
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }
    return dates;
  }

  List<RestaurantTable> get _reservationsOnSelected {
    return widget.prov.allTables.where((t) {
      if (t.reservation == null) return false;
      final d = t.reservation!.reservedFor;
      return d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
    }).toList()..sort(
      (a, b) =>
          a.reservation!.reservedFor.compareTo(b.reservation!.reservedFor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservedDates = _reservedDates;
    final todayRes = _reservationsOnSelected;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: TC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TC.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _monthName(_displayMonth.month),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '${_displayMonth.year}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TC.textMute,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (reservedDates.any(
                        (d) =>
                            d.month == _displayMonth.month &&
                            d.year == _displayMonth.year,
                      ))
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: TC.reservedBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: TC.reserved.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('📅', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                '${reservedDates.where((d) => d.month == _displayMonth.month && d.year == _displayMonth.year).length} this month',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: TC.reserved,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _NavArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month - 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _NavArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => setState(
                          () => _displayMonth = DateTime(
                            _displayMonth.year,
                            _displayMonth.month + 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: TC.textMute,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 4),
                _buildMonthGrid(reservedDates, todayDate),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate == todayDate
                        ? 'Today'
                        : _selectedDate ==
                              todayDate.add(const Duration(days: 1))
                        ? 'Tomorrow'
                        : '${_monthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.day}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: TC.textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    todayRes.isEmpty
                        ? 'No reservations'
                        : '${todayRes.length} reservation${todayRes.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: todayRes.isEmpty ? TC.textMute : TC.reserved,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.prov.canAddReservation)
                GestureDetector(
                  onTap: () => _openAddReservation(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TC.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: TC.accent.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'Reserve',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: todayRes.isEmpty
              ? _CalendarEmptyDay(date: _selectedDate, todayDate: todayDate)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: todayRes.length,
                  itemBuilder: (ctx, i) => _ReservationTimelineCard(
                    table: todayRes[i],
                    prov: widget.prov,
                    onTap: () => _openTableDetail(ctx, todayRes[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(Set<DateTime> reservedDates, DateTime todayDate) {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
        ),
        itemCount: startWeekday + daysInMonth,
        itemBuilder: (_, idx) {
          if (idx < startWeekday) return const SizedBox.shrink();
          final day = idx - startWeekday + 1;
          final date = DateTime(_displayMonth.year, _displayMonth.month, day);
          final isToday = date == todayDate;
          final isSel = date == _selectedDate;
          final hasRes = reservedDates.contains(date);
          final isPast = date.isBefore(todayDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel
                    ? TC.accent
                    : isToday
                    ? TC.accentLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: isToday && !isSel
                    ? Border.all(color: TC.accent, width: 1.5)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: (isSel || isToday)
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSel
                          ? Colors.white
                          : isPast
                          ? TC.textMute
                          : TC.textPri,
                    ),
                  ),
                  if (hasRes && !isSel)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isPast ? TC.textMute : TC.reserved,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (hasRes && isSel)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddReservation(BuildContext context) {
    final allTables = widget.prov.allTables
        .where((t) => t.status != TableStatus.cleaning)
        .toList();
    if (allTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tables available'),
          backgroundColor: TC.occupied,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: widget.prov,
        child: _CalendarReserveSheet(
          provider: widget.prov,
          availableTables: allTables,
          initialDate: _selectedDate,
        ),
      ),
    );
  }

  void _openTableDetail(BuildContext ctx, RestaurantTable table) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: widget.prov,
        child: _TableDetailSheet(table: table),
      ),
    );
  }

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TC.border),
        ),
        child: Icon(icon, color: TC.textSec, size: 20),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HISTORY VIEW
// ═════════════════════════════════════════════════════════════
class _HistoryView extends StatefulWidget {
  final TablesProvider prov;
  const _HistoryView({Key? key, required this.prov}) : super(key: key);

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  final _scrollCtrl = ScrollController();
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!widget.prov.historyLoading && widget.prov.historyHasMore) {
        widget.prov.loadHistory();
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: TC.accent,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end.add(const Duration(days: 1));
      });
      widget.prov.loadHistory(from: _fromDate, to: _toDate, reset: true);
    }
  }

  Map<String, List<ReservationHistoryItem>> _groupByDate(
    List<ReservationHistoryItem> items,
  ) {
    final map = <String, List<ReservationHistoryItem>>{};
    for (final item in items) {
      final key = _dayKey(item.reservedFor);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dayKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.prov.history;
    final filtered = _filterStatus == null
        ? history
        : history.where((h) => h.status == _filterStatus).toList();

    final total = filtered.length;
    final seated = filtered.where((h) => h.status == 'seated').length;
    final cancelled = filtered.where((h) => h.status == 'cancelled').length;
    final noshow = filtered.where((h) => h.status == 'noshow').length;
    final active = filtered.where((h) => h.status == 'active').length;

    final grouped = _groupByDate(filtered);
    final dateKeys = grouped.keys.toList();

    final flatItems = <dynamic>[];
    for (final key in dateKeys) {
      flatItems.add(key);
      flatItems.addAll(grouped[key]!);
    }
    if (widget.prov.historyHasMore) flatItems.add('__loader__');

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: TC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TC.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 15,
                              color: TC.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_fmtDate(_fromDate)} – ${_fmtDate(_toDate.subtract(const Duration(days: 1)))}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: TC.textPri,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 14,
                              color: TC.textMute,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.prov.loadHistory(
                        from: _fromDate,
                        to: _toDate,
                        reset: true,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TC.accentLight,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: TC.accent,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  children: [
                    _HChip(
                      label: 'All',
                      count: total,
                      selected: _filterStatus == null,
                      color: TC.textSec,
                      onTap: () => setState(() => _filterStatus = null),
                    ),
                    _HChip(
                      label: 'Active',
                      count: active,
                      selected: _filterStatus == 'active',
                      color: TC.reserved,
                      onTap: () => setState(() => _filterStatus = 'active'),
                    ),
                    _HChip(
                      label: 'Seated',
                      count: seated,
                      selected: _filterStatus == 'seated',
                      color: TC.available,
                      onTap: () => setState(() => _filterStatus = 'seated'),
                    ),
                    _HChip(
                      label: 'Cancelled',
                      count: cancelled,
                      selected: _filterStatus == 'cancelled',
                      color: TC.occupied,
                      onTap: () => setState(() => _filterStatus = 'cancelled'),
                    ),
                    _HChip(
                      label: 'No-show',
                      count: noshow,
                      selected: _filterStatus == 'noshow',
                      color: TC.cleaning,
                      onTap: () => setState(() => _filterStatus = 'noshow'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _StatPill(label: 'Total', value: '$total', color: TC.textSec),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Seated',
                  value: '$seated',
                  color: TC.available,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Cancelled',
                  value: '$cancelled',
                  color: TC.occupied,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'No-show',
                  value: '$noshow',
                  color: TC.cleaning,
                ),
              ],
            ),
          ),
        Expanded(
          child: flatItems.isEmpty && !widget.prov.historyLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          color: TC.surfaceWarm,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('📋', style: TextStyle(fontSize: 38)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No records found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TC.textPri,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Try a different date range or filter',
                        style: TextStyle(fontSize: 12, color: TC.textSec),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: flatItems.length,
                  itemBuilder: (ctx, i) {
                    final item = flatItems[i];
                    if (item == '__loader__') {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: TC.accent,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: TC.border),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: TC.textSec,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(height: 1, color: TC.divider),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${grouped[item]!.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: TC.textMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _HistoryCard(item: item as ReservationHistoryItem);
                  },
                ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TC.textMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _HChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : TC.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : TC.textMute,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.18) : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : TC.textMute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ReservationHistoryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'seated' => TC.available,
      'cancelled' => TC.occupied,
      'noshow' => TC.cleaning,
      _ => TC.reserved,
    };
    final statusLabel = switch (item.status) {
      'seated' => 'Seated',
      'cancelled' => 'Cancelled',
      'noshow' => 'No-show',
      _ => 'Upcoming',
    };
    final statusIcon = switch (item.status) {
      'seated' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      'noshow' => Icons.person_off_outlined,
      _ => Icons.event_available_outlined,
    };

    final sectionEnum = TableSection.values.firstWhere(
      (e) => e.name == item.section,
      orElse: () => TableSection.ac,
    );
    final secColor = _sectionColor(sectionEnum);
    final secBg = _sectionBg(sectionEnum);

    final inTime = _fmtTime(item.reservedFor);
    final outTime = item.checkOut != null ? _fmtTime(item.checkOut!) : null;
    final dur = item.checkOut != null
        ? item.checkOut!.difference(item.reservedFor).inMinutes
        : null;
    final durLabel = dur != null
        ? (dur >= 60
              ? '${(dur / 60).toStringAsFixed(dur % 60 == 0 ? 0 : 1)}h'
              : '${dur}m')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.07),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                border: Border(
                  right: BorderSide(color: statusColor.withOpacity(0.15)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: statusColor.withOpacity(0.8),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      height: 1.2,
                    ),
                  ),
                  if (outTime != null) ...[
                    const SizedBox(height: 1),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 9,
                      color: statusColor.withOpacity(0.5),
                    ),
                    Text(
                      outTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                  if (durLabel != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: secBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: secColor.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            '${sectionEnum.emoji} T${item.tableNumber.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: secColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 11,
                              color: TC.textMute,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.guestCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: TC.textSec,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: TC.textPri,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.phone != null) ...[
                          const Icon(
                            Icons.phone_outlined,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.phone!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TC.textSec,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Icon(
                          Icons.person_outline,
                          size: 11,
                          color: TC.textMute,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.createdByName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TC.textMute,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            size: 11,
                            color: TC.textMute,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: TC.textSec,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ─────────────────────────────────────────────────────────────
//  RESERVATION TIMELINE CARD
// ─────────────────────────────────────────────────────────────
class _ReservationTimelineCard extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  final VoidCallback onTap;
  const _ReservationTimelineCard({
    required this.table,
    required this.prov,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final res = table.reservation!;
    final secColor = _sectionColor(table.section);
    final secBg = _sectionBg(table.section);
    final diff = res.reservedFor.difference(DateTime.now());
    final isOverdue = diff.isNegative;
    final isSoon = !isOverdue && diff.inMinutes <= 30;
    final isEnding = res.isEndingSoon;
    final timeColor = isEnding
        ? TC.occupied
        : isOverdue
        ? TC.occupied
        : isSoon
        ? const Color(0xFFB8730A)
        : TC.reserved;
    final timeBg = isEnding
        ? TC.occupiedBg
        : isOverdue
        ? TC.occupiedBg
        : isSoon
        ? const Color(0xFFFFF4DC)
        : TC.reservedBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isSoon || isEnding)
                ? timeColor.withOpacity(0.4)
                : TC.border,
            width: (isSoon || isEnding) ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: timeBg,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      res.timeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: timeColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      res.countdownLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: timeColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (res.checkOut != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '→${res.checkOutTimeLabel}',
                        style: TextStyle(
                          fontSize: 9,
                          color: timeColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              res.customerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: TC.textPri,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: secBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: secColor.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              '${table.section.emoji} ${table.tableName}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: secColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _ResBadge(
                            icon: Icons.people_outline,
                            text: '${res.guestCount} guests',
                          ),
                          const SizedBox(width: 8),
                          if (res.phone != null)
                            _ResBadge(
                              icon: Icons.phone_outlined,
                              text: res.phone!,
                            ),
                        ],
                      ),
                      if (res.notes != null && res.notes!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Text('📝', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                res.notes!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: TC.textSec,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => prov.seatGuests(table.id, res.customerName),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TC.availableBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: TC.available,
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => prov.cancelReservation(table.id),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: TC.occupiedBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: TC.occupied,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ResBadge({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: TC.textMute),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: TC.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR EMPTY DAY  — FIX: wrapped in SingleChildScrollView
//  to prevent RenderFlex overflow when space is constrained
// ─────────────────────────────────────────────────────────────
class _CalendarEmptyDay extends StatelessWidget {
  final DateTime date, todayDate;
  const _CalendarEmptyDay({required this.date, required this.todayDate});

  @override
  Widget build(BuildContext context) {
    final isPast = date.isBefore(todayDate);
    // FIX: Wrap with SingleChildScrollView so the Column is not
    // constrained by the parent's tight height, preventing the
    // "RenderFlex overflowed by 108/112 pixels on the bottom" error.
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isPast ? TC.surfaceWarm : TC.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isPast ? '📋' : '✨',
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isPast ? 'No records for this day' : 'No reservations yet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: TC.textPri,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isPast
                    ? 'This date has passed'
                    : 'Tap + Reserve to add a booking',
                style: const TextStyle(fontSize: 12, color: TC.textSec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CALENDAR QUICK-RESERVE SHEET
// ─────────────────────────────────────────────────────────────
class _CalendarReserveSheet extends StatefulWidget {
  final TablesProvider provider;
  final List<RestaurantTable> availableTables;
  final DateTime initialDate;
  const _CalendarReserveSheet({
    required this.provider,
    required this.availableTables,
    required this.initialDate,
  });
  @override
  State<_CalendarReserveSheet> createState() => _CalendarReserveSheetState();
}

class _CalendarReserveSheetState extends State<_CalendarReserveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _tableId;
  int _guestCount = 2;
  late DateTime _checkIn;
  DateTime? _checkOut;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _availError;

  @override
  void initState() {
    super.initState();
    _tableId = widget.availableTables.first.id;
    final d = widget.initialDate;
    _checkIn = DateTime(d.year, d.month, d.day, DateTime.now().hour + 1, 0);
    _checkOut = _checkIn.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isCheckIn ? _checkIn : (_checkOut ?? _checkIn),
      ),
    );
    if (t != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = DateTime(
            _checkIn.year,
            _checkIn.month,
            _checkIn.day,
            t.hour,
            t.minute,
          );
        } else {
          final base = _checkOut ?? _checkIn;
          _checkOut = DateTime(
            base.year,
            base.month,
            base.day,
            t.hour,
            t.minute,
          );
        }
        _availError = null;
      });
    }
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isChecking = true;
      _availError = null;
    });

    final available = await widget.provider.checkAvailability(
      tableId: _tableId,
      checkIn: _checkIn,
      checkOut: _checkOut ?? _checkIn.add(const Duration(hours: 2)),
    );

    setState(() => _isChecking = false);

    if (!available) {
      setState(
        () => _availError =
            'Table already booked for this time slot. Please choose another time.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = Reservation(
      id: 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _checkIn,
      checkOut: _checkOut,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.provider.addReservation(_tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: '📅',
              title: 'Quick Reserve',
              subtitle: 'Add a reservation for this date',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Table',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.availableTables.length,
                        itemBuilder: (_, i) {
                          final t = widget.availableTables[i];
                          final isSel = _tableId == t.id;
                          final secCol = _sectionColor(t.section);
                          final secBg = _sectionBg(t.section);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tableId = t.id;
                                  _availError = null;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel ? secBg : TC.surfaceWarm,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? secCol : TC.border,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          t.section.emoji,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          t.tableName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isSel ? secCol : TC.textSec,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '· ${t.capacity}p',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSel
                                                ? secCol.withOpacity(0.7)
                                                : TC.textMute,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (t.status == TableStatus.reserved &&
                                        t.reservation != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lock_clock_rounded,
                                            size: 10,
                                            color: TC.reserved.withOpacity(0.7),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${t.reservation!.timeLabel}${t.reservation!.checkOut != null ? " – ${t.reservation!.checkOutTimeLabel}" : ""}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: TC.reserved,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (t.status ==
                                        TableStatus.occupied) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant_rounded,
                                            size: 10,
                                            color: TC.occupied.withOpacity(0.7),
                                          ),
                                          const SizedBox(width: 3),
                                          const Text(
                                            'Occupied now',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: TC.occupied,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormField(
                      label: 'Guest Name *',
                      hint: 'Full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: 'Phone',
                      hint: '+91 98765...',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check-in *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TC.textSec,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _pickTime(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TC.surfaceWarm,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: TC.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '🟢',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _fmtTime(_checkIn),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: TC.textPri,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check-out',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TC.textSec,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _pickTime(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TC.surfaceWarm,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: TC.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '🔴',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _checkOut != null
                                            ? _fmtTime(_checkOut!)
                                            : 'Optional',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _checkOut != null
                                              ? TC.textPri
                                              : TC.textMute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quick Duration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DurationChips(
                      checkIn: _checkIn,
                      checkOut: _checkOut,
                      onCheckOutChanged: (t) => setState(() {
                        _checkOut = t;
                        _availError = null;
                      }),
                    ),
                    if (_availError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TC.occupiedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: TC.occupied.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _availError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TC.occupied,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Party Size',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(8, (i) {
                        final n = i + 1;
                        final isSel = _guestCount == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _guestCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: 'Notes',
                      hint: 'Special requests...',
                      controller: _noteCtrl,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isChecking)
                            ? null
                            : _checkAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isChecking)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isChecking
                                    ? 'Checking Availability...'
                                    : 'Confirm Reservation',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }
}

// ═════════════════════════════════════════════════════════════
//  TABLE DETAIL SHEET
// ═════════════════════════════════════════════════════════════
class _TableDetailSheet extends StatelessWidget {
  final RestaurantTable table;
  const _TableDetailSheet({required this.table});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<TablesProvider>();
    final sc = _statusColor(table.status);
    final sb = _statusBg(table.status);
    final secCol = _sectionColor(table.section);
    final secBg = _sectionBg(table.section);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: TC.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: TC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  _TableIcon(
                    shape: table.shape,
                    capacity: table.capacity,
                    color: sc,
                    bg: sb,
                    tableName: table.tableName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Table ${table.tableNumber}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: TC.textPri,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (table.isPremium)
                              const Text('⭐', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: secBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${table.section.emoji} ${table.section.label}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: secCol,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: sb,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                table.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sc,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (prov.canManageTables)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ChangeNotifierProvider.value(
                            value: prov,
                            child: _AddEditTableSheet(
                              provider: prov,
                              editTable: table,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: TC.border),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: TC.textSec,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: TC.divider),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(
                    children: [
                      _InfoTile(
                        label: 'Capacity',
                        value: '${table.capacity} seats',
                        emoji: '👥',
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        label: 'Floor',
                        value: table.section.floor,
                        emoji: '🏢',
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        label: 'Shape',
                        value: table.shape.name.capitalize(),
                        emoji: '⬜',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (table.status == TableStatus.occupied)
                    _OccupiedSection(table: table, prov: prov)
                  else if (table.status == TableStatus.reserved)
                    _ReservationSection(table: table, prov: prov)
                  else if (table.status == TableStatus.available)
                    _AvailableSection(table: table, prov: prov)
                  else
                    _CleaningSection(table: table, prov: prov),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS SECTIONS
// ─────────────────────────────────────────────────────────────
class _OccupiedSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _OccupiedSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetSection('Current Occupancy'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.occupiedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.occupied.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: '👤',
                label: 'Customer',
                value: table.currentCustomerName ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '🧾',
                label: 'Order',
                value: table.currentOrderId ?? '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '💰',
                label: 'Bill so far',
                value: table.currentOrderTotal != null
                    ? '₹${table.currentOrderTotal!.toInt()}'
                    : '—',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '⏱️',
                label: 'Occupied for',
                value: table.occupiedDuration,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionBtn(
          label: 'Clear Table',
          emoji: '🧹',
          color: TC.cleaning,
          onTap: () {
            prov.clearTable(table.id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _ReservationSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _ReservationSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    final res = table.reservation!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetSection('Reservation Details'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.reservedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.reserved.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _DetailRow(icon: '👤', label: 'Guest', value: res.customerName),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(icon: '📱', label: 'Phone', value: res.phone ?? '—'),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '👥',
                label: 'Party size',
                value: '${res.guestCount} guests',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '🗓️',
                label: 'Reserved at',
                value: '${res.dateLabel} at ${res.reservationTimeLabel}',
              ),
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '🟢',
                label: 'Scheduled check-in',
                value: res.timeLabel,
              ),
              if (res.checkIn != null) ...[
                const Divider(height: 20, color: TC.divider),
                _DetailRow(
                  icon: '✅',
                  label: 'Actual check-in',
                  value: res.checkInTimeLabel,
                ),
              ],
              if (res.checkOut != null) ...[
                const Divider(height: 20, color: TC.divider),
                _DetailRow(
                  icon: '🔴',
                  label: 'Check-out',
                  value: res.checkOutTimeLabel,
                ),
              ],
              const Divider(height: 20, color: TC.divider),
              _DetailRow(
                icon: '⏰',
                label: 'Arrives',
                value: res.countdownLabel,
              ),
              if (res.notes != null && res.notes!.isNotEmpty) ...[
                const Divider(height: 20, color: TC.divider),
                _DetailRow(icon: '📝', label: 'Notes', value: res.notes!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Cancel',
                emoji: '✖️',
                color: const Color(0xFFDC2626),
                outlined: true,
                onTap: () => _confirmCancel(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Seat Guests',
                emoji: '🍽️',
                color: TC.available,
                onTap: () {
                  prov.seatGuests(table.id, res.customerName);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _ActionBtn(
            label: 'Edit Reservation',
            emoji: '✏️',
            color: TC.accent,
            outlined: true,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(
                  value: prov,
                  child: _ReservationSheet(
                    tableId: table.id,
                    provider: prov,
                    existing: res,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Reservation?',
          style: TextStyle(fontWeight: FontWeight.w800, color: TC.textPri),
        ),
        content: Text(
          'The reservation for ${table.reservation?.customerName} will be removed.',
          style: const TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              prov.cancelReservation(table.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _AvailableSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _AvailableSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.availableBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.available.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table is Ready',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.available,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Walk-in guests can be seated now',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Reserve Table',
                emoji: '📅',
                color: TC.reserved,
                outlined: true,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: prov,
                      child: _ReservationSheet(
                        tableId: table.id,
                        provider: prov,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Seat Walk-in',
                emoji: '🚶',
                color: TC.accent,
                onTap: () {
                  prov.seatGuests(table.id, 'Walk-in Guest');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CleaningSection extends StatelessWidget {
  final RestaurantTable table;
  final TablesProvider prov;
  const _CleaningSection({required this.table, required this.prov});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.cleaningBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.cleaning.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Text('🧹', style: TextStyle(fontSize: 28)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Being Cleaned',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TC.cleaning,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Table will be available shortly',
                      style: TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _ActionBtn(
            label: 'Mark as Available',
            emoji: '✅',
            color: TC.available,
            onTap: () {
              prov.markAvailable(table.id);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RESERVATION SHEET  (add / edit)
// ─────────────────────────────────────────────────────────────
class _ReservationSheet extends StatefulWidget {
  final String tableId;
  final TablesProvider provider;
  final Reservation? existing;
  const _ReservationSheet({
    required this.tableId,
    required this.provider,
    this.existing,
  });
  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _phoneCtrl, _notesCtrl;
  late int _guestCount;
  late DateTime _checkIn;
  DateTime? _checkOut;
  bool _isLoading = false;
  bool _isChecking = false;
  String? _availError;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _guestCount = e?.guestCount ?? 2;
    _checkIn =
        e?.reservedFor ??
        DateTime.now()
            .add(const Duration(hours: 1))
            .copyWith(second: 0, microsecond: 0, millisecond: 0);
    _checkOut = e?.checkOut ?? _checkIn.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isCheckIn ? _checkIn : (_checkOut ?? _checkIn),
      ),
    );
    if (t != null)
      setState(() {
        if (isCheckIn) {
          _checkIn = DateTime(
            _checkIn.year,
            _checkIn.month,
            _checkIn.day,
            t.hour,
            t.minute,
          );
        } else {
          final base = _checkOut ?? _checkIn;
          _checkOut = DateTime(
            base.year,
            base.month,
            base.day,
            t.hour,
            t.minute,
          );
        }
        _availError = null;
      });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null)
      setState(() {
        _checkIn = DateTime(
          d.year,
          d.month,
          d.day,
          _checkIn.hour,
          _checkIn.minute,
        );
        if (_checkOut != null)
          _checkOut = DateTime(
            d.year,
            d.month,
            d.day,
            _checkOut!.hour,
            _checkOut!.minute,
          );
      });
  }

  Future<void> _checkAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isChecking = true;
      _availError = null;
    });
    final available = await widget.provider.checkAvailability(
      tableId: widget.tableId,
      checkIn: _checkIn,
      checkOut: _checkOut ?? _checkIn.add(const Duration(hours: 2)),
      excludeReservationId: widget.existing?.id,
    );
    setState(() => _isChecking = false);
    if (!available) {
      setState(
        () => _availError =
            'This table already has a booking during that time. Choose a different slot.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = Reservation(
      id: widget.existing?.id ?? 'res_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      guestCount: _guestCount,
      reservedFor: _checkIn,
      checkOut: _checkOut,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    isEdit
        ? await widget.provider.updateReservation(widget.tableId, res)
        : await widget.provider.addReservation(widget.tableId, res);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: '📅',
              title: isEdit ? 'Edit Reservation' : 'New Reservation',
              subtitle: isEdit
                  ? 'Update details below'
                  : 'Reserve this table for a guest',
              color: TC.reserved,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormField(
                      label: 'Guest Name *',
                      hint: 'Enter full name',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _FormField(
                      label: 'Phone Number',
                      hint: '+91 98765 43210',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Party Size',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(8, (i) {
                        final n = i + 1;
                        final isSel = _guestCount == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _guestCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.reserved : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.reserved : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Date *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: TC.surfaceWarm,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TC.border),
                        ),
                        child: Row(
                          children: [
                            const Text('📅', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_checkIn),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TC.textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Check-in & Check-out *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TC.border),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🟢',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check-in',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: TC.textMute,
                                        ),
                                      ),
                                      Text(
                                        _fmtTime(_checkIn),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: TC.textPri,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TC.border),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🔴',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check-out',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: TC.textMute,
                                        ),
                                      ),
                                      Text(
                                        _checkOut != null
                                            ? _fmtTime(_checkOut!)
                                            : 'Optional',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _checkOut != null
                                              ? TC.textPri
                                              : TC.textMute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quick Duration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DurationChips(
                      checkIn: _checkIn,
                      checkOut: _checkOut,
                      onCheckOutChanged: (t) => setState(() {
                        _checkOut = t;
                        _availError = null;
                      }),
                    ),
                    if (_availError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TC.occupiedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: TC.occupied.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _availError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TC.occupied,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _FormField(
                      label: 'Special Notes',
                      hint: 'Birthday, anniversary, dietary needs...',
                      controller: _notesCtrl,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isChecking)
                            ? null
                            : _checkAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TC.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: (_isLoading || _isChecking)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEdit
                                    ? 'Update Reservation'
                                    : 'Confirm Reservation',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $s';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rDate = DateTime(dt.year, dt.month, dt.day);
    if (rDate == today) return 'Today';
    if (rDate == today.add(const Duration(days: 1))) return 'Tomorrow';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[dt.month - 1]} ${dt.day}';
  }
}

// ─────────────────────────────────────────────────────────────
//  ADD / EDIT TABLE SHEET
// ─────────────────────────────────────────────────────────────
class _AddEditTableSheet extends StatefulWidget {
  final TablesProvider provider;
  final RestaurantTable? editTable;
  const _AddEditTableSheet({required this.provider, this.editTable});
  @override
  State<_AddEditTableSheet> createState() => _AddEditTableSheetState();
}

class _AddEditTableSheetState extends State<_AddEditTableSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _capacity;
  late TableSection _section;
  late TableShape _shape;
  late bool _hasWindow, _isPremium;
  bool _isLoading = false;
  bool get isEdit => widget.editTable != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editTable;
    _capacity = e?.capacity ?? 4;
    _section = e?.section ?? TableSection.ac;
    _shape = e?.shape ?? TableShape.square;
    _hasWindow = e?.hasWindow ?? false;
    _isPremium = e?.isPremium ?? false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final table = RestaurantTable(
      id: widget.editTable?.id ?? widget.provider.generateId(),
      tableNumber:
          widget.editTable?.tableNumber ?? widget.provider.nextTableNumber(),
      capacity: _capacity,
      status: widget.editTable?.status ?? TableStatus.available,
      section: _section,
      shape: _shape,
      hasWindow: _hasWindow,
      isPremium: _isPremium,
      currentCustomerName: widget.editTable?.currentCustomerName,
      currentOrderId: widget.editTable?.currentOrderId,
      currentOrderTotal: widget.editTable?.currentOrderTotal,
      occupiedSince: widget.editTable?.occupiedSince,
      reservation: widget.editTable?.reservation,
    );
    isEdit
        ? await widget.provider.updateTable(table)
        : await widget.provider.addTable(table);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: TC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTopBar(
              emoji: isEdit ? '✏️' : '➕',
              title: isEdit ? 'Edit Table' : 'Add New Table',
              subtitle: isEdit
                  ? 'Update table configuration'
                  : 'Configure the new table',
              color: TC.accent,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Section',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TableSection.values.map((s) {
                        final isSel = _section == s;
                        final col = _sectionColor(s);
                        final bg = _sectionBg(s);
                        return GestureDetector(
                          onTap: () => setState(() => _section = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? bg : TC.surfaceWarm,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? col : TC.border,
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? col : TC.textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Seating Capacity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [2, 4, 6, 8, 10, 12].map((n) {
                        final isSel = _capacity == n;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _capacity = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? TC.accent : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
                                  width: isSel ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? Colors.white : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Table Shape',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TC.textSec,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: TableShape.values.map((s) {
                        final isSel = _shape == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _shape = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSel ? TC.accentLight : TC.surfaceWarm,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? TC.accent : TC.border,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                s.name.capitalize(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? TC.accent : TC.textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _ToggleRow(
                      label: 'Window View',
                      subtitle: 'Table has a window or scenic view',
                      emoji: '🪟',
                      value: _hasWindow,
                      onChanged: (v) => setState(() => _hasWindow = v),
                    ),
                    const Divider(height: 1, color: TC.divider),
                    _ToggleRow(
                      label: 'Premium Table',
                      subtitle: 'Marks this as a premium / special table',
                      emoji: '⭐',
                      value: _isPremium,
                      onChanged: (v) => setState(() => _isPremium = v),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (isEdit) ...[
                          _OutlineBtn(
                            label: 'Delete',
                            color: const Color(0xFFDC2626),
                            onTap: () => _confirmDelete(context),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TC.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isEdit ? 'Save Changes' : 'Add Table',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${widget.editTable!.tableName}?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: TC.textPri,
          ),
        ),
        content: const Text(
          'This will permanently remove the table.',
          style: TextStyle(color: TC.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: TC.textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteTable(widget.editTable!.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DURATION QUICK-SELECT CHIPS
// ─────────────────────────────────────────────────────────────
class _DurationChips extends StatelessWidget {
  final DateTime checkIn;
  final DateTime? checkOut;
  final ValueChanged<DateTime?> onCheckOutChanged;

  const _DurationChips({
    required this.checkIn,
    required this.checkOut,
    required this.onCheckOutChanged,
  });

  static const _presets = [
    ('10 min', 10),
    ('20 min', 20),
    ('30 min', 30),
    ('1 hr', 60),
    ('2 hr', 120),
    ('3 hr', 180),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _presets.map((p) {
          final label = p.$1;
          final mins = p.$2;
          final target = checkIn.add(Duration(minutes: mins));
          final isSel =
              checkOut != null &&
              checkOut!.difference(checkIn).inMinutes == mins;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onCheckOutChanged(target),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSel ? TC.reserved.withOpacity(0.12) : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? TC.reserved : TC.border,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSel ? TC.reserved : TC.textSec,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  final String label, value, emoji;
  const _InfoTile({
    required this.label,
    required this.value,
    required this.emoji,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: TC.textPri,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: TC.textMute),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String icon, label, value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: TC.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TC.textPri,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: outlined ? color : color.withOpacity(0.3),
            width: outlined ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String text;
  const _SheetSection(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: TC.textMute,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: TC.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  const _SheetTopBar({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: TC.textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: TC.divider),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TC.textPri,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: TC.textMute, fontSize: 13),
            filled: true,
            fillColor: TC.surfaceWarm,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, subtitle, emoji;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TC.textPri,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: TC.textMute),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: TC.accent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDDDDE8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: TC.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Text('🪑', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No tables found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TC.textPri,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different filter or add a new table',
            style: TextStyle(fontSize: 13, color: TC.textSec),
          ),
        ],
      ),
    );
  }
}

class _AddTableFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTableFAB({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: TC.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: TC.accent.withOpacity(0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Table',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
*/
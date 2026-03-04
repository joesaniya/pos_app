import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/employee_management_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TEAM MEMBERS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _searchController = TextEditingController();
  final _activeScrollController = ScrollController();
  final _pastScrollController = ScrollController();
  bool _isSearchFocused = false;

  // ── Light Design Tokens ────────────────────────────────────────────────────
  static const _bg = Color(0xFFF5F7FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _card = Color(0xFFFFFFFF);
  static const _cardBorder = Color(0xFFE8ECF8);
  static const _accent = Color(0xFF4F6EF7);
  static const _accentSoft = Color(0xFFEEF1FE);
  static const _accentMed = Color(0xFFD0D9FC);
  static const _success = Color(0xFF00A86B);
  static const _successSoft = Color(0xFFE6F7F2);
  static const _warning = Color(0xFFE07B00);
  static const _warningSoft = Color(0xFFFFF3E0);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFDECEA);
  static const _purple = Color(0xFF8B5CF6);
  static const _purpleSoft = Color(0xFFF3EEFF);
  static const _gold = Color(0xFFB8860B);
  static const _goldSoft = Color(0xFFFFF8E1);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textMuted = Color(0xFFADB5CC);
  static const _divider = Color(0xFFF0F2FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeScrollController.addListener(_onActiveScroll);
    _pastScrollController.addListener(_onPastScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeManagementProvider>().init();
    });
  }

  void _onActiveScroll() {
    if (_activeScrollController.position.pixels >=
        _activeScrollController.position.maxScrollExtent - 200) {
      context.read<EmployeeManagementProvider>().loadMoreEmployees();
    }
  }

  void _onPastScroll() {
    if (_pastScrollController.position.pixels >=
        _pastScrollController.position.maxScrollExtent - 200) {
      // reserved for future server-side past pagination
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _activeScrollController.dispose();
    _pastScrollController.dispose();
    super.dispose();
  }

  // ── Role helpers ───────────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return _gold;
      case 'system':
        return _purple;
      case 'admin':
        return _accent;
      case 'manager':
        return _warning;
      default:
        return _success;
    }
  }

  Color _roleSoft(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return _goldSoft;
      case 'system':
        return _purpleSoft;
      case 'admin':
        return _accentSoft;
      case 'manager':
        return _warningSoft;
      default:
        return _successSoft;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.workspace_premium_rounded;
      case 'system':
        return Icons.admin_panel_settings_rounded;
      case 'admin':
        return Icons.manage_accounts_rounded;
      case 'manager':
        return Icons.supervised_user_circle_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  // ── Delete confirmation ────────────────────────────────────────────────────
  Future<void> _confirmDelete(
    BuildContext ctx,
    EmployeeManagementProvider prov,
    EmployeeModel emp,
  ) async {
    final confirmed = await showGeneralDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (_, __, ___) => _DeleteDialog(emp: emp),
    );
    if (confirmed == true && ctx.mounted) {
      final ok = await prov.deleteEmployee(emp);
      if (ctx.mounted) {
        _showSnack(
          ctx,
          ok ? '${emp.name} removed from team' : 'Failed to remove member',
          ok ? _success : _danger,
        );
      }
    }
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Consumer<EmployeeManagementProvider>(
          builder: (ctx, prov, _) {
            return NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                _buildSliverHeader(ctx, prov),
                SliverToBoxAdapter(child: _buildStatsRow(prov)),
                SliverToBoxAdapter(child: _buildSearchAndFilter(ctx, prov)),
                SliverToBoxAdapter(child: _buildTabBar()),
              ],
              body: TabBarView(
                controller: _tabController!,
                children: [
                  _buildActiveTab(ctx, prov),
                  _buildPastTab(ctx, prov),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Sliver Header ──────────────────────────────────────────────────────────
  Widget _buildSliverHeader(BuildContext ctx, EmployeeManagementProvider prov) {
    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: 64,
      pinned: true,
      stretch: true,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      forceElevated: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textSecondary,
              size: 15,
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentMed),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _accent,
                size: 17,
              ),
            ),
            onPressed: prov.refresh,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 68, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Members',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              prov.isLoading
                  ? 'Loading…'
                  : '${prov.totalCount} member${prov.totalCount != 1 ? 's' : ''}',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0F4FF), _surface],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow(EmployeeManagementProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: prov.totalCount,
            color: _accent,
            soft: _accentSoft,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Active',
            value: prov.activeCount,
            color: _success,
            soft: _successSoft,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Inactive',
            value: prov.inactiveCount,
            color: _textMuted,
            soft: _divider,
            icon: Icons.pause_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Former',
            value: prov.pastCount,
            color: _purple,
            soft: _purpleSoft,
            icon: Icons.history_rounded,
          ),
        ],
      ),
    );
  }

  // ── Search + Filter ────────────────────────────────────────────────────────
  Widget _buildSearchAndFilter(
    BuildContext ctx,
    EmployeeManagementProvider prov,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isSearchFocused
                    ? _accent.withOpacity(0.5)
                    : _cardBorder,
                width: _isSearchFocused ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isSearchFocused
                      ? _accent.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              onChanged: prov.setSearch,
              onTap: () => setState(() => _isSearchFocused = true),
              onEditingComplete: () => setState(() => _isSearchFocused = false),
              decoration: InputDecoration(
                hintText: 'Search by name, email or role…',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _textSecondary,
                  size: 19,
                ),
                suffixIcon: prov.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                          size: 17,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          prov.setSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prov.availableRoles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final role = prov.availableRoles[i];
                final selected = prov.roleFilter == role;
                final color = role == 'All' ? _accent : _roleColor(role);
                return GestureDetector(
                  onTap: () => prov.setRoleFilter(role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.12) : _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color.withOpacity(0.5) : _cardBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: selected ? color : _textSecondary,
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: _divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController!,
        indicator: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: _textPrimary,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Current Members'),
          Tab(text: 'Past Members'),
        ],
      ),
    );
  }

  // ── Active Tab ─────────────────────────────────────────────────────────────
  Widget _buildActiveTab(BuildContext ctx, EmployeeManagementProvider prov) {
    if (prov.isLoading) return const _LoadingState();
    if (prov.error != null) {
      return _ErrorState(error: prov.error!, onRetry: prov.refresh);
    }
    if (prov.employees.isEmpty) {
      return _EmptyState(
        hasFilters: prov.searchQuery.isNotEmpty || prov.roleFilter != 'All',
        onClear: prov.clearFilters,
      );
    }

    return ListView.builder(
      controller: _activeScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: prov.employees.length + (prov.hasMoreActive ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == prov.employees.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          );
        }
        final emp = prov.employees[i];
        return _EmployeeCard(
          key: ValueKey(emp.uid),
          emp: emp,
          isSelf: prov.isSelf(emp.uid),
          canDelete: prov.canDelete(emp),
          canToggle: prov.canToggle(emp),
          isDeleting: prov.isDeleting,
          index: i,
          roleColor: _roleColor(emp.role),
          roleSoft: _roleSoft(emp.role),
          roleIcon: _roleIcon(emp.role),
          onDelete: () => _confirmDelete(ctx, prov, emp),
          onToggle: () async {
            final ok = await prov.toggleStatus(emp);
            if (ctx.mounted && !ok) {
              _showSnack(ctx, 'Could not update status', _danger);
            }
          },
        );
      },
    );
  }

  // ── Past Tab ───────────────────────────────────────────────────────────────
  Widget _buildPastTab(BuildContext ctx, EmployeeManagementProvider prov) {
    if (prov.isLoadingPast && prov.pastEmployees.isEmpty) {
      return const _LoadingState(isPast: true);
    }
    if (prov.pastEmployees.isEmpty) {
      return const _NoPastState();
    }

    return ListView.builder(
      controller: _pastScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: prov.pastEmployees.length,
      itemBuilder: (ctx, i) {
        final emp = prov.pastEmployees[i];
        return _PastEmployeeCard(
          key: ValueKey('past_${emp.uid}'),
          emp: emp,
          index: i,
          roleColor: _roleColor(emp.role),
          roleSoft: _roleSoft(emp.role),
          roleIcon: _roleIcon(emp.role),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CURRENT EMPLOYEE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeCard extends StatefulWidget {
  final EmployeeModel emp;
  final bool isSelf, canDelete, canToggle, isDeleting;
  final int index;
  final Color roleColor, roleSoft;
  final IconData roleIcon;
  final VoidCallback onDelete, onToggle;

  const _EmployeeCard({
    super.key,
    required this.emp,
    required this.isSelf,
    required this.canDelete,
    required this.canToggle,
    required this.isDeleting,
    required this.index,
    required this.roleColor,
    required this.roleSoft,
    required this.roleIcon,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<Offset> _slide;

  static const _card = Color(0xFFFFFFFF);
  static const _cardBorder = Color(0xFFE8ECF8);
  static const _accent = Color(0xFF4F6EF7);
  static const _accentSoft = Color(0xFFEEF1FE);
  static const _accentMed = Color(0xFFD0D9FC);
  static const _success = Color(0xFF00A86B);
  static const _successSoft = Color(0xFFE6F7F2);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFDECEA);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textMuted = Color(0xFFADB5CC);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380 + widget.index * 50),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final isActive = emp.isActive;

    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.isSelf ? _accent.withOpacity(0.35) : _cardBorder,
                width: widget.isSelf ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelf
                      ? _accent.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Main row ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _Avatar(
                        emp: emp,
                        roleColor: widget.roleColor,
                        isActive: isActive,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    emp.name,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isSelf) ...[
                                  const SizedBox(width: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accentSoft,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _accentMed),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              emp.email,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _RoleBadge(
                                  label: _cap(emp.role),
                                  color: widget.roleColor,
                                  soft: widget.roleSoft,
                                  icon: widget.roleIcon,
                                ),
                                const SizedBox(width: 7),
                                _StatusBadge(isActive: isActive),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ────────────────────────────────────────
                Container(height: 1, color: const Color(0xFFF0F2FA)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _textMuted,
                        size: 12,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Joined ${emp.joinedLabel}  ·  ${emp.tenureLabel}',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.canToggle) ...[
                        const SizedBox(width: 8),
                        _ActionButton(
                          label: isActive ? 'Deactivate' : 'Activate',
                          icon: isActive
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: isActive ? _dangerSoft : _successSoft,
                          textColor: isActive ? _danger : _success,
                          borderColor: isActive
                              ? _danger.withOpacity(0.25)
                              : _success.withOpacity(0.25),
                          onTap: widget.onToggle,
                        ),
                      ],
                      if (widget.canToggle && widget.canDelete)
                        const SizedBox(width: 7),
                      if (widget.canDelete)
                        _ActionButton(
                          label: 'Remove',
                          icon: Icons.person_remove_rounded,
                          color: _dangerSoft,
                          textColor: _danger,
                          borderColor: _danger.withOpacity(0.25),
                          onTap: widget.isDeleting ? () {} : widget.onDelete,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAST EMPLOYEE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PastEmployeeCard extends StatefulWidget {
  final EmployeeModel emp;
  final int index;
  final Color roleColor, roleSoft;
  final IconData roleIcon;

  const _PastEmployeeCard({
    super.key,
    required this.emp,
    required this.index,
    required this.roleColor,
    required this.roleSoft,
    required this.roleIcon,
  });

  @override
  State<_PastEmployeeCard> createState() => _PastEmployeeCardState();
}

class _PastEmployeeCardState extends State<_PastEmployeeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  static const _card = Color(0xFFFFFFFF);
  static const _cardBorder = Color(0xFFE8ECF8);
  static const _purple = Color(0xFF8B5CF6);
  static const _purpleSoft = Color(0xFFF3EEFF);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _textMuted = Color(0xFFADB5CC);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 40),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    return SlideTransition(
      position: _slide,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Greyscale avatar
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _cardBorder, width: 2),
                            color: const Color(0xFFF0F2FA),
                          ),
                          child: ClipOval(
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                              child: emp.profilePhoto.isNotEmpty
                                  ? Image.network(
                                      emp.profilePhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _InitialsAvatar(
                                            emp: emp,
                                            roleColor: _textMuted,
                                          ),
                                    )
                                  : _InitialsAvatar(
                                      emp: emp,
                                      roleColor: _textMuted,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _purpleSoft,
                              shape: BoxShape.circle,
                              border: Border.all(color: _card, width: 2),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: _purple,
                              size: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            emp.email,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _RoleBadge(
                            label: _cap(emp.role),
                            color: _textMuted,
                            soft: const Color(0xFFF0F2FA),
                            icon: widget.roleIcon,
                          ),
                        ],
                      ),
                    ),

                    // Tenure badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _purpleSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _purple.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emp.tenureLabel,
                            style: const TextStyle(
                              color: _purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'tenure',
                            style: TextStyle(
                              color: _purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 1, color: const Color(0xFFF0F2FA)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    _InfoPill(
                      icon: Icons.login_rounded,
                      label: 'Joined ${emp.joinedLabel}',
                      color: _textMuted,
                    ),
                    if (emp.deletedAt != null) ...[
                      const SizedBox(width: 12),
                      _InfoPill(
                        icon: Icons.logout_rounded,
                        label: 'Left ${emp.leftLabel}',
                        color: _purple.withOpacity(0.7),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

class _Avatar extends StatelessWidget {
  final EmployeeModel emp;
  final Color roleColor;
  final bool isActive;
  const _Avatar({
    required this.emp,
    required this.roleColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: roleColor.withOpacity(0.35), width: 2),
          ),
          child: ClipOval(
            child: emp.profilePhoto.isNotEmpty
                ? Image.network(
                    emp.profilePhoto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialsAvatar(emp: emp, roleColor: roleColor),
                  )
                : _InitialsAvatar(emp: emp, roleColor: roleColor),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00A86B)
                  : const Color(0xFFADB5CC),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final EmployeeModel emp;
  final Color roleColor;
  const _InitialsAvatar({required this.emp, required this.roleColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: roleColor.withOpacity(0.1),
      child: Center(
        child: Text(
          emp.initials,
          style: TextStyle(
            color: roleColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color, soft;
  final IconData icon;
  const _RoleBadge({
    required this.label,
    required this.color,
    required this.soft,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  static const _success = Color(0xFF00A86B);
  static const _successSoft = Color(0xFFE6F7F2);
  static const _textMuted = Color(0xFFADB5CC);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? _successSoft : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? _success.withOpacity(0.3)
              : _textMuted.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? _success : _textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: isActive ? _success : _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11.5)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, textColor, borderColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color, soft;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.soft,
    required this.icon,
  });

  static const _card = Color(0xFFFFFFFF);
  static const _cardBorder = Color(0xFFE8ECF8);
  static const _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: _textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DELETE DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final EmployeeModel emp;
  const _DeleteDialog({required this.emp});

  static const _card = Color(0xFFFFFFFF);
  static const _cardBorder = Color(0xFFE8ECF8);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFDECEA);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _bg = Color(0xFFF5F7FF);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _danger.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _dangerSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: _danger.withOpacity(0.2)),
                  ),
                  child: const Icon(
                    Icons.person_remove_rounded,
                    color: _danger,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Remove Member',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to remove ${emp.name} from the team? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _danger,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Center(
                            child: Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATE SCREENS
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  final bool isPast;
  const _LoadingState({this.isPast = false});

  static const _accent = Color(0xFF4F6EF7);
  static const _purple = Color(0xFF8B5CF6);
  static const _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final color = isPast ? _purple : _accent;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: color.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isPast ? 'Loading past members…' : 'Loading team members…',
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFDECEA);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _bg = Color(0xFFF5F7FF);
  static const _cardBorder = Color(0xFFE8ECF8);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _dangerSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _danger.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: _textSecondary,
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyState({required this.hasFilters, required this.onClear});

  static const _accent = Color(0xFF4F6EF7);
  static const _accentSoft = Color(0xFFEEF1FE);
  static const _accentMed = Color(0xFFD0D9FC);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _accentMed),
              ),
              child: const Icon(
                Icons.group_off_rounded,
                color: _accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasFilters ? 'No results found' : 'No team members',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Team members will appear here once added',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _accentMed),
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoPastState extends StatelessWidget {
  const _NoPastState();

  static const _purple = Color(0xFF8B5CF6);
  static const _purpleSoft = Color(0xFFF3EEFF);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _purpleSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _purple.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: _purple,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No past members',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Former team members who have been removed\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

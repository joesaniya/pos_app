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
  late AnimationController _fadeController;
  late AnimationController _headerController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _headerSlide;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSearchFocused = false;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0A0D14);
  static const _surface = Color(0xFF111520);
  static const _card = Color(0xFF161B2E);
  static const _cardBorder = Color(0xFF1E2640);
  static const _accent = Color(0xFF4F6EF7);
  static const _accentGlow = Color(0x334F6EF7);
  static const _accentSoft = Color(0xFF2A3A8A);
  static const _success = Color(0xFF00D68F);
  static const _successSoft = Color(0x1A00D68F);
  static const _warning = Color(0xFFFFB547);
  static const _warningSoft = Color(0x1AFFB547);
  static const _danger = Color(0xFFFF4D6A);
  static const _dangerSoft = Color(0x1AFF4D6A);
  static const _textPrimary = Color(0xFFEEF0F8);
  static const _textSecondary = Color(0xFF7B85A3);
  static const _textMuted = Color(0xFF3D4560);
  static const _divider = Color(0xFF1A2038);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _headerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeManagementProvider>().init();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Role badge color ───────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFFFFD700);
      case 'system':
        return const Color(0xFFAD49E1);
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
        return const Color(0x1AFFD700);
      case 'system':
        return const Color(0x1AAD49E1);
      case 'admin':
        return _accentGlow;
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
      BuildContext ctx, EmployeeManagementProvider prov, EmployeeModel emp) async {
    final confirmed = await showGeneralDialog<bool>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (_, __, ___) => _DeleteDialog(emp: emp),
    );
    if (confirmed == true && ctx.mounted) {
      final ok = await prov.deleteEmployee(emp);
      if (ctx.mounted) {
        _showSnack(ctx, ok ? '${emp.name} removed from team' : 'Failed to remove member',
            ok ? _success : _danger);
      }
    }
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.5)),
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
            Text(msg,
                style: TextStyle(
                    color: _textPrimary, fontFamily: 'SF Pro Display', fontSize: 14)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Consumer<EmployeeManagementProvider>(
          builder: (ctx, prov, _) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── App Bar ─────────────────────────────────────────────
                  _buildSliverHeader(ctx, prov),

                  // ── Stats Row ───────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildStatsRow(prov)),

                  // ── Search + Filter ─────────────────────────────────────
                  SliverToBoxAdapter(child: _buildSearchAndFilter(ctx, prov)),

                  // ── Content ─────────────────────────────────────────────
                  if (prov.isLoading)
                    const SliverFillRemaining(child: _LoadingState())
                  else if (prov.error != null)
                    SliverFillRemaining(child: _ErrorState(error: prov.error!,
                        onRetry: prov.refresh))
                  else if (prov.employees.isEmpty)
                    SliverFillRemaining(child: _EmptyState(hasFilters:
                        prov.searchQuery.isNotEmpty || prov.roleFilter != 'All',
                        onClear: prov.clearFilters))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
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
                          childCount: prov.employees.length,
                        ),
                      ),
                    ),
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
      expandedHeight: 130,
      collapsedHeight: 70,
      pinned: true,
      stretch: true,
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _textSecondary, size: 16),
          ),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _accentGlow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentSoft),
              ),
              child: const Icon(Icons.refresh_rounded, color: _accent, size: 18),
            ),
            onPressed: prov.refresh,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 68, bottom: 18),
        title: SlideTransition(
          position: _headerSlide,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                prov.isLoading
                    ? 'Loading...'
                    : '${prov.totalCount} member${prov.totalCount != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1228), _bg],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Opacity(
              opacity: 0.15,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_accent, _bg.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow(EmployeeManagementProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          _StatChip(
            label: 'Total',
            value: prov.totalCount,
            color: _accent,
            soft: _accentGlow,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Active',
            value: prov.activeCount,
            color: _success,
            soft: _successSoft,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Inactive',
            value: prov.inactiveCount,
            color: _textMuted,
            soft: const Color(0x1A3D4560),
            icon: Icons.pause_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  // ── Search + Filter ────────────────────────────────────────────────────────
  Widget _buildSearchAndFilter(BuildContext ctx, EmployeeManagementProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          // Search field
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSearchFocused ? _accent.withOpacity(0.6) : _cardBorder,
                width: _isSearchFocused ? 1.5 : 1,
              ),
              boxShadow: _isSearchFocused
                  ? [BoxShadow(color: _accentGlow, blurRadius: 12)]
                  : [],
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
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _textSecondary, size: 20),
                suffixIcon: prov.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          prov.setSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Role filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: prov.availableRoles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final role = prov.availableRoles[i];
                final selected = prov.roleFilter == role;
                final color = role == 'All'
                    ? _accent
                    : _roleColor(role);
                return GestureDetector(
                  onTap: () => prov.setRoleFilter(role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color.withOpacity(0.6) : _cardBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        color: selected ? color : _textSecondary,
                        fontSize: 13,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeCard extends StatefulWidget {
  final EmployeeModel emp;
  final bool isSelf;
  final bool canDelete;
  final bool canToggle;
  final bool isDeleting;
  final int index;
  final Color roleColor;
  final Color roleSoft;
  final IconData roleIcon;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

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

  static const _bg = Color(0xFF0A0D14);
  static const _card = Color(0xFF161B2E);
  static const _cardBorder = Color(0xFF1E2640);
  static const _accent = Color(0xFF4F6EF7);
  static const _success = Color(0xFF00D68F);
  static const _successSoft = Color(0x1A00D68F);
  static const _danger = Color(0xFFFF4D6A);
  static const _dangerSoft = Color(0x1AFF4D6A);
  static const _textPrimary = Color(0xFFEEF0F8);
  static const _textSecondary = Color(0xFF7B85A3);
  static const _textMuted = Color(0xFF3D4560);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 60),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isSelf
                    ? _accent.withOpacity(0.4)
                    : _cardBorder,
                width: widget.isSelf ? 1.5 : 1,
              ),
              boxShadow: widget.isSelf
                  ? [
                      BoxShadow(
                        color: _accent.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                // ── Main row ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar
                      _Avatar(
                        emp: emp,
                        roleColor: widget.roleColor,
                        isActive: isActive,
                      ),
                      const SizedBox(width: 14),

                      // Info
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
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _accent.withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
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
                                // Role badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.roleSoft,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: widget.roleColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.roleIcon,
                                          color: widget.roleColor, size: 11),
                                      const SizedBox(width: 5),
                                      Text(
                                        _capitalize(emp.role),
                                        style: TextStyle(
                                          color: widget.roleColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _successSoft
                                        : const Color(0x1A3D4560),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isActive
                                          ? _success.withOpacity(0.3)
                                          : _textMuted.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? _success
                                              : _textMuted,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: isActive
                                              ? _success
                                              : _textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ─────────────────────────────────────────────
                if (widget.canToggle || widget.canDelete) ...[
                  Container(
                    height: 1,
                    color: _cardBorder.withOpacity(0.6),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Joined date
                        Icon(Icons.calendar_today_outlined,
                            color: _textMuted, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'Joined ${emp.joinedLabel}',
                          style: const TextStyle(
                              color: _textMuted, fontSize: 12),
                        ),
                        const Spacer(),

                        // Toggle button
                        if (widget.canToggle)
                          _ActionButton(
                            label: isActive ? 'Deactivate' : 'Activate',
                            icon: isActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isActive ? _dangerSoft : _successSoft,
                            textColor: isActive ? _danger : _success,
                            borderColor: isActive
                                ? _danger.withOpacity(0.3)
                                : _success.withOpacity(0.3),
                            onTap: widget.onToggle,
                          ),

                        if (widget.canToggle && widget.canDelete)
                          const SizedBox(width: 8),

                        // Delete button
                        if (widget.canDelete)
                          _ActionButton(
                            label: 'Remove',
                            icon: Icons.person_remove_rounded,
                            color: _dangerSoft,
                            textColor: _danger,
                            borderColor: _danger.withOpacity(0.3),
                            onTap: widget.isDeleting ? () {} : widget.onDelete,
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Just show joined date
                  Container(
                    height: 1,
                    color: _cardBorder.withOpacity(0.6),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            color: _textMuted, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'Joined ${emp.joinedLabel}',
                          style:
                              const TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────
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
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: roleColor.withOpacity(0.4), width: 2),
          ),
          child: ClipOval(
            child: emp.profilePhoto.isNotEmpty
                ? Image.network(
                    emp.profilePhoto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _InitialsAvatar(emp: emp, roleColor: roleColor),
                  )
                : _InitialsAvatar(emp: emp, roleColor: roleColor),
          ),
        ),
        // Active indicator dot
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF00D68F) : const Color(0xFF3D4560),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF161B2E), width: 2),
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
      color: roleColor.withOpacity(0.12),
      child: Center(
        child: Text(
          emp.initials,
          style: TextStyle(
            color: roleColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color borderColor;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 13),
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

// ─────────────────────────────────────────────────────────────────────────────
//  STAT CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color soft;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.soft,
    required this.icon,
  });

  static const _card = Color(0xFF161B2E);
  static const _cardBorder = Color(0xFF1E2640);
  static const _textSecondary = Color(0xFF7B85A3);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
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

  static const _card = Color(0xFF161B2E);
  static const _cardBorder = Color(0xFF1E2640);
  static const _danger = Color(0xFFFF4D6A);
  static const _dangerSoft = Color(0x1AFF4D6A);
  static const _textPrimary = Color(0xFFEEF0F8);
  static const _textSecondary = Color(0xFF7B85A3);
  static const _surface = Color(0xFF111520);

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
              border: Border.all(color: _danger.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _danger.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _dangerSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: _danger.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.person_remove_rounded,
                    color: _danger,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Remove Member',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
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
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _danger,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
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
//  LOADING STATE
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  static const _accent = Color(0xFF4F6EF7);
  static const _textSecondary = Color(0xFF7B85A3);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
              backgroundColor: _accent.withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading team members…',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  static const _danger = Color(0xFFFF4D6A);
  static const _dangerSoft = Color(0x1AFF4D6A);
  static const _cardBorder = Color(0xFF1E2640);
  static const _textPrimary = Color(0xFFEEF0F8);
  static const _textSecondary = Color(0xFF7B85A3);
  static const _surface = Color(0xFF111520);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _dangerSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _danger.withOpacity(0.3)),
              ),
              child: const Icon(Icons.cloud_off_rounded, color: _danger, size: 30),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _textSecondary, size: 16),
                    SizedBox(width: 8),
                    Text('Try Again',
                        style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
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

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyState({required this.hasFilters, required this.onClear});

  static const _accent = Color(0xFF4F6EF7);
  static const _accentGlow = Color(0x334F6EF7);
  static const _accentSoft = Color(0x1A4F6EF7);
  static const _textPrimary = Color(0xFFEEF0F8);
  static const _textSecondary = Color(0xFF7B85A3);
  static const _surface = Color(0xFF111520);
  static const _cardBorder = Color(0xFF1E2640);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.group_off_rounded, color: _accent, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'No results found' : 'No team members',
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: _accentGlow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _accent.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
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
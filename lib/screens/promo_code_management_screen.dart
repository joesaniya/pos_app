import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/models/promo_code_model.dart';
import 'package:pos_app/providers/promo_code_provider.dart';
import 'package:pos_app/utils/promo_code_access_control.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS (from profile_screen)
// ─────────────────────────────────────────────

abstract class _T {
  // Palette
  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const royal = Color(0xFF1847C4);
  static const royalLt = Color(0xFF3B6FE8);
  static const royalBg = Color(0xFFEBF0FF);
  static const royalBd = Color(0xFFCDD8FB);
  static const ink = Color(0xFF0D1B3E);
  static const bodyColor = Color(0xFF3A4A6B);
  static const muted = Color(0xFF8C9AB8);
  static const line = Color(0xFFE4EAF8);
  static const green = Color(0xFF0EA472);
  static const amber = Color(0xFFD97706);
  static const teal = Color(0xFF0891B2);
  static const violet = Color(0xFF7C3AED);
  static const rose = Color(0xFFE11D48);
  static const indigo = Color(0xFF6366F1);

  // Aliases for backward compatibility
  static const ink2 = bodyColor;
  static const ink3 = muted;
  static const surface = white;
  static const surface2 = bg;
  static const surface3 = royalBg;
  static const navy = indigo;
  static const tangerine = amber;
  static const forest = green;
  static const forestLight = royalBg;
  static const forestText = green;
  static const border = line;
  static const border2 = royalBd;
  static const errorBg = Color(0xFFFFF5F7);
  static const errorBorder = rose;
  static const errorText = rose;
  static const deleteBg = Color(0xFFFFF5F7);
  static const deleteBorder = rose;
  static const deleteText = rose;
  static const infoChipBg = royalBg;
  static const infoChipText = royal;

  // Radii
  static const r8 = Radius.circular(8);
  static const r10 = Radius.circular(10);
  static const r12 = Radius.circular(12);
  static const r14 = Radius.circular(14);
  static const r20 = Radius.circular(20);
  static final rCard = BorderRadius.circular(14);
  static final rBtn = BorderRadius.circular(10);
  static final rTag = BorderRadius.circular(6);
  static final rPill = BorderRadius.circular(20);

  // Typography helpers
  static TextStyle head(
    double size, {
    Color color = ink,
    FontWeight w = FontWeight.w800,
  }) => GoogleFonts.syne(fontSize: size, fontWeight: w, color: color);
  static TextStyle mono(
    double size, {
    Color color = ink,
    FontWeight w = FontWeight.w500,
  }) => GoogleFonts.dmMono(fontSize: size, fontWeight: w, color: color);
  static TextStyle body(
    double size, {
    Color color = ink2,
    FontWeight w = FontWeight.w400,
  }) => GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color);

  // Divider
  static const divider = Divider(height: 1, thickness: 0.5, color: border);
}

// ─────────────────────────────────────────────
//  PROMO CODE MANAGEMENT SCREEN
// ─────────────────────────────────────────────

class PromoCodeManagementScreen extends StatefulWidget {
  final String businessId;
  final String? userId;
  final String? userRole;

  const PromoCodeManagementScreen({
    Key? key,
    required this.businessId,
    this.userId,
    this.userRole,
  }) : super(key: key);

  @override
  State<PromoCodeManagementScreen> createState() =>
      _PromoCodeManagementScreenState();
}

class _PromoCodeManagementScreenState extends State<PromoCodeManagementScreen>
    with SingleTickerProviderStateMixin {
  late PromoCodeProvider _provider;
  bool _showActive = true;
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller first, before any early returns
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (!PromoCodeAccessControl.canManagePromoCodes(widget.userRole)) {
      log('[PromoMgmt] ❌ UNAUTHORIZED ACCESS');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTopSnack(
            PromoCodeAccessControl.getAccessDeniedReason(widget.userRole),
            isError: true,
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    // Forward animation after auth check passes
    _fabAnim.forward();
    _provider = PromoCodeProvider();
    _loadCodes();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _loadCodes() => _provider.loadPromoCodesByBusiness(widget.businessId);

  void _showTopSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _T.body(13, color: Colors.white)),
        backgroundColor: isError ? _T.errorText : _T.forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _goCreate() async {
    final result = await Navigator.push<bool>(
      context,
      _slideRoute(
        PromoCodeFormScreen(
          businessId: widget.businessId,
          userId: widget.userId ?? '',
          isEdit: false,
        ),
      ),
    );
    if (result == true) _loadCodes();
  }

  Future<void> _goEdit(PromoCode promo) async {
    final result = await Navigator.push<bool>(
      context,
      _slideRoute(
        PromoCodeFormScreen(
          businessId: widget.businessId,
          userId: widget.userId ?? '',
          isEdit: true,
          promoCode: promo,
        ),
      ),
    );
    if (result == true) _loadCodes();
  }

  void _confirmDelete(PromoCode promo) {
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        code: promo.code,
        onConfirm: () async {
          final ok = await _provider.deletePromoCode(promo.id);
          if (ok && mounted) _showTopSnack('${promo.code} deleted');
        },
      ),
    );
  }

  PageRouteBuilder<bool> _slideRoute(Widget page) => PageRouteBuilder<bool>(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 340),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface2,
      body: Column(
        children: [
          _TopNav(userRole: widget.userRole),
          Expanded(
            child: ListenableBuilder(
              listenable: _provider,
              builder: (_, __) {
                if (_provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _T.tangerine,
                      strokeWidth: 2,
                    ),
                  );
                }

                final all = _provider.promoCodes;
                final active = all.where((p) => p.isActive).toList();
                final inactive = all.where((p) => !p.isActive).toList();
                final shown = _showActive ? active : inactive;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Page heading ──
                            _PageHeader(onAdd: _goCreate),
                            const SizedBox(height: 20),
                            // ── Stat row ──
                            _StatRow(
                              total: all.length,
                              active: active.length,
                              expired: inactive.length,
                            ),
                            const SizedBox(height: 20),
                            // ── Filter tabs ──
                            _FilterTabs(
                              showActive: _showActive,
                              activeCount: active.length,
                              inactiveCount: inactive.length,
                              onChanged: (v) => setState(() => _showActive = v),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    if (shown.isEmpty)
                      SliverFillRemaining(
                        child: _EmptyState(
                          showActive: _showActive,
                          onAdd: _goCreate,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PromoCard(
                                promo: shown[i],
                                onEdit: () => _goEdit(shown[i]),
                                onDelete: () => _confirmDelete(shown[i]),
                                onToggle: (v) => _provider
                                    .togglePromoCodeStatus(shown[i].id, v),
                              ),
                            ),
                            childCount: shown.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnim.status == AnimationStatus.dismissed
            ? AlwaysStoppedAnimation(0.0)
            : CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: _goCreate,
          backgroundColor: _T.navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            'New Code',
            style: _T.head(13, color: Colors.white, w: FontWeight.w700),
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP NAV
// ─────────────────────────────────────────────

class _TopNav extends StatelessWidget {
  final String? userRole;
  const _TopNav({this.userRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _T.tangerine,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Promo Manager',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Text('Promo Manager', style: _T.head(15, color: Colors.white)),
          const Spacer(),
          if (userRole != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: _T.rPill,
              ),
              child: Text(
                userRole!.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          /*  const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: _T.tangerine,
            child: Text(
              (userRole?.isNotEmpty == true) ? userRole![0].toUpperCase() : 'A',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        */
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE HEADER
// ─────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final VoidCallback onAdd;
  const _PageHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BIZ · PROMO CODES',
                style: _T.mono(10, color: _T.ink3).copyWith(letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text('Promo Codes', style: _T.head(28)),
            ],
          ),
        ),
        /*   GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: _T.navy, borderRadius: _T.rBtn),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'New Code',
                  style: _T.head(13, color: Colors.white, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
     */
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  STAT ROW
// ─────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final int total, active, expired;
  const _StatRow({
    required this.total,
    required this.active,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Total', value: '$total', bg: _T.surface, fg: _T.ink),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Active',
          value: '$active',
          bg: _T.forest,
          fg: Colors.white,
          labelFg: Colors.white70,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Expired',
          value: '$expired',
          bg: _T.surface,
          fg: _T.ink2,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color bg, fg;
  final Color? labelFg;
  const _StatCard({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    this.labelFg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: _T.rCard,
          border: bg == _T.surface ? Border.all(color: _T.border) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: _T
                  .mono(10, color: labelFg ?? _T.ink3)
                  .copyWith(letterSpacing: 1.0),
            ),
            const SizedBox(height: 4),
            Text(value, style: _T.head(26, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FILTER TABS
// ─────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final bool showActive;
  final int activeCount, inactiveCount;
  final ValueChanged<bool> onChanged;

  const _FilterTabs({
    required this.showActive,
    required this.activeCount,
    required this.inactiveCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _T.surface3, borderRadius: _T.rCard),
      child: Row(
        children: [
          _Tab(
            label: 'Active ($activeCount)',
            selected: showActive,
            onTap: () => onChanged(true),
          ),
          _Tab(
            label: 'Inactive ($inactiveCount)',
            selected: !showActive,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _T.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _T.body(
              13,
              color: selected ? Colors.white : _T.ink2,
              w: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PROMO CARD
// ─────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final PromoCode promo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _PromoCard({
    required this.promo,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  String get _displayDiscount {
    if (promo.discountType == DiscountType.percentage) {
      return '${promo.discountValue.toStringAsFixed(0)}% off';
    }
    return '₹${promo.discountValue.toStringAsFixed(0)} off';
  }

  String get _minText => promo.minOrderValue > 0
      ? 'Min ₹${promo.minOrderValue.toStringAsFixed(0)}'
      : 'No minimum';

  String _fmtDate(DateTime d) => DateFormat('dd MMM yy').format(d);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: _T.rCard,
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top section ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code + customer chip
                      Row(
                        children: [
                          Text(promo.code, style: _T.mono(17)),
                          if (promo.customerId != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _T.infoChipBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CUSTOMER',
                                style: _T
                                    .mono(9, color: _T.infoChipText)
                                    .copyWith(letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayDiscount,
                        style: _T.head(
                          22,
                          color: promo.isActive ? _T.tangerine : _T.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: promo.isActive ? _T.forestLight : _T.surface3,
                    borderRadius: _T.rPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: promo.isActive ? _T.forestText : _T.ink3,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        promo.isActive ? 'Active' : 'Inactive',
                        style: _T.mono(
                          11,
                          color: promo.isActive ? _T.forestText : _T.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tags row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(icon: Icons.money_off_rounded, label: _minText),
                _Tag(
                  icon: Icons.date_range_rounded,
                  label:
                      '${_fmtDate(promo.startDate)} → ${_fmtDate(promo.expiryDate)}',
                ),
              ],
            ),
          ),

          // ── Divider ──
          const Divider(height: 1, thickness: 0.5, color: _T.border),

          // ── Actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                _ActionBtn(label: 'Edit', onTap: onEdit),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: promo.isActive ? 'Deactivate' : 'Activate',
                  bg: promo.isActive ? _T.deleteBg : _T.forestLight,
                  border: promo.isActive
                      ? _T.deleteBorder
                      : const Color(0xFFB5D5C5),
                  fg: promo.isActive ? _T.deleteText : _T.forestText,
                  onTap: () => onToggle(!promo.isActive),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: _T.deleteText,
                  bg: _T.deleteBg,
                  border: _T.deleteBorder,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _T.surface2,
        borderRadius: _T.rTag,
        border: Border.all(color: _T.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _T.ink3),
          const SizedBox(width: 5),
          Text(
            label,
            style: _T.mono(11, color: _T.ink2, w: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color border;
  final Color fg;

  const _ActionBtn({
    required this.label,
    required this.onTap,
    this.bg = _T.surface,
    this.border = _T.border2,
    this.fg = _T.ink2,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: _T.body(13, color: fg, w: FontWeight.w500),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg, border;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool showActive;
  final VoidCallback onAdd;
  const _EmptyState({required this.showActive, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _T.surface3,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              size: 32,
              color: _T.ink3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            showActive ? 'No active promo codes' : 'No inactive promo codes',
            style: _T.head(16, color: _T.ink2, w: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Create one to get started', style: _T.body(13, color: _T.ink3)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: _T.navy, borderRadius: _T.rBtn),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Create Promo Code',
                    style: _T.head(13, color: Colors.white, w: FontWeight.w700),
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

// ─────────────────────────────────────────────
//  DELETE DIALOG
// ─────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String code;
  final VoidCallback onConfirm;
  const _DeleteDialog({required this.code, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _T.surface,
      shape: RoundedRectangleBorder(borderRadius: _T.rCard),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _T.deleteBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: _T.deleteText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Delete Promo Code', style: _T.head(17))),
              ],
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: _T.body(14, color: _T.ink2),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: '"$code"',
                    style: _T.mono(14, color: _T.ink),
                  ),
                  const TextSpan(text: '? This action cannot be undone.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: Border.all(color: _T.border2),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: _T.body(14, color: _T.ink2, w: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _T.deleteText,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Delete',
                        style: _T.body(
                          14,
                          color: Colors.white,
                          w: FontWeight.w600,
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
    );
  }
}

// ─────────────────────────────────────────────
//  PROMO CODE FORM SCREEN
// ─────────────────────────────────────────────

class PromoCodeFormScreen extends StatefulWidget {
  final String businessId;
  final String userId;
  final bool isEdit;
  final PromoCode? promoCode;

  const PromoCodeFormScreen({
    Key? key,
    required this.businessId,
    required this.userId,
    required this.isEdit,
    this.promoCode,
  }) : super(key: key);

  @override
  State<PromoCodeFormScreen> createState() => _PromoCodeFormScreenState();
}

class _PromoCodeFormScreenState extends State<PromoCodeFormScreen> {
  late TextEditingController _codeCtrl;
  late TextEditingController _valueCtrl;
  late TextEditingController _minCtrl;
  late TextEditingController _cidCtrl;

  late DiscountType _discountType;
  late DateTime _startDate;
  late DateTime _expiryDate;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.promoCode;
    if (widget.isEdit && p != null) {
      _codeCtrl = TextEditingController(text: p.code);
      _valueCtrl = TextEditingController(text: p.discountValue.toString());
      _minCtrl = TextEditingController(text: p.minOrderValue.toString());
      _cidCtrl = TextEditingController(text: p.customerId ?? '');
      _discountType = p.discountType;
      _startDate = p.startDate;
      _expiryDate = p.expiryDate;
    } else {
      _codeCtrl = TextEditingController();
      _valueCtrl = TextEditingController();
      _minCtrl = TextEditingController(text: '0');
      _cidCtrl = TextEditingController();
      _discountType = DiscountType.percentage;
      _startDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minCtrl.dispose();
    _cidCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _T.navy,
            onPrimary: Colors.white,
            surface: _T.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _expiryDate = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);

    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Promo code cannot be empty');
      return;
    }
    if (_valueCtrl.text.trim().isEmpty ||
        double.tryParse(_valueCtrl.text) == null) {
      setState(() => _error = 'Enter a valid discount value');
      return;
    }
    if (_startDate.isAfter(_expiryDate)) {
      setState(() => _error = 'Start date must be before expiry date');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = context.read<PromoCodeProvider>();
      bool? ok;

      if (widget.isEdit && widget.promoCode != null) {
        ok = await provider.updatePromoCode(widget.promoCode!.id, {
          'code': _codeCtrl.text.toUpperCase().trim(),
          'discount_type': _discountType.value,
          'discount_value': double.parse(_valueCtrl.text),
          'min_order_value': double.parse(_minCtrl.text),
          'start_date': _startDate.toIso8601String(),
          'expiry_date': _expiryDate.toIso8601String(),
          'customer_id': _cidCtrl.text.trim().isEmpty
              ? null
              : _cidCtrl.text.trim(),
        });
      } else {
        final result = await provider.createPromoCode(
          businessId: widget.businessId,
          code: _codeCtrl.text.toUpperCase().trim(),
          discountType: _discountType.value,
          discountValue: double.parse(_valueCtrl.text),
          minOrderValue: double.parse(_minCtrl.text),
          startDate: _startDate,
          expiryDate: _expiryDate,
          createdBy: widget.userId,
          customerId: _cidCtrl.text.trim().isEmpty
              ? null
              : _cidCtrl.text.trim(),
        );
        ok = result != null;
      }

      if (ok == true && mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface2,
      body: Column(
        children: [
          // ── Form top bar ──
          Container(
            color: _T.navy,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 20,
              bottom: 14,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? 'EDIT' : 'NEW',
                      style: _T
                          .mono(10, color: Colors.white54)
                          .copyWith(letterSpacing: 1.2),
                    ),
                    Text(
                      widget.isEdit ? 'Edit Promo Code' : 'Create Promo Code',
                      style: _T.head(
                        16,
                        color: Colors.white,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Form body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _T.surface,
                      borderRadius: _T.rCard,
                      border: Border.all(color: _T.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Code
                        _FormField(
                          label: 'Promo Code',
                          child: TextField(
                            controller: _codeCtrl,
                            enabled: !widget.isEdit,
                            style: _T.mono(15).copyWith(letterSpacing: 1.0),
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Z0-9]'),
                              ),
                            ],
                            onChanged: (v) {
                              final upper = v.toUpperCase().replaceAll(
                                RegExp(r'[^A-Z0-9]'),
                                '',
                              );
                              if (upper != v) {
                                _codeCtrl.value = TextEditingValue(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                    offset: upper.length,
                                  ),
                                );
                              }
                            },
                            decoration: _inputDec('e.g. SAVE20'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Discount type + value
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Type',
                                child: DropdownButtonFormField<DiscountType>(
                                  value: _discountType,
                                  style: _T.body(14),
                                  decoration: _inputDec(''),
                                  items: DiscountType.values
                                      .map(
                                        (t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null)
                                      setState(() => _discountType = v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FormField(
                                label: 'Value',
                                child: TextField(
                                  controller: _valueCtrl,
                                  style: _T.body(14),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputDec('20').copyWith(
                                    suffixText:
                                        _discountType == DiscountType.percentage
                                        ? '%'
                                        : '₹',
                                    suffixStyle: _T.mono(14, color: _T.ink3),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Min order value
                        _FormField(
                          label: 'Min. Order Value (₹)',
                          child: TextField(
                            controller: _minCtrl,
                            style: _T.body(14),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDec('0 — no minimum'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dates
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Start Date',
                                child: _DatePicker(
                                  date: _startDate,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FormField(
                                label: 'Expiry Date',
                                child: _DatePicker(
                                  date: _expiryDate,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Customer ID
                        _FormField(
                          label: 'Customer ID (optional)',
                          child: TextField(
                            controller: _cidCtrl,
                            style: _T.body(14),
                            decoration: _inputDec(
                              'Leave empty for all customers',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error banner
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _T.errorBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _T.errorBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: _T.errorText,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: _T.body(13, color: _T.errorText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Save button
                  GestureDetector(
                    onTap: _isLoading ? null : _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _isLoading ? _T.navy.withOpacity(0.5) : _T.navy,
                        borderRadius: _T.rBtn,
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.isEdit
                                  ? 'Update Promo Code'
                                  : 'Create Promo Code',
                              style: _T.head(
                                15,
                                color: Colors.white,
                                w: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: _T.body(13, color: _T.ink3),
    filled: true,
    fillColor: _T.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.navy, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _T.border),
    ),
  );
}

// ─────────────────────────────────────────────
//  FORM HELPERS
// ─────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: _T.mono(10, color: _T.ink3).copyWith(letterSpacing: 0.9),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePicker({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _T.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _T.border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: _T.ink3),
            const SizedBox(width: 8),
            Text(DateFormat('dd/MM/yyyy').format(date), style: _T.body(14)),
          ],
        ),
      ),
    );
  }
}

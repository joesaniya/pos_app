import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/screens/change_pwd_screen.dart';
import 'package:pos_app/screens/create_account_screen.dart';
import 'package:pos_app/screens/edit_profile_Screen.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  static const page = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const royal = Color(0xFF1847C4);
  static const royalMid = Color(0xFF3B6FE8);
  static const royalSoft = Color(0xFFEBF0FF);
  static const royalBorder = Color(0xFFCDD8FB);
  static const ink = Color(0xFF0D1B3E);
  static const body = Color(0xFF3A4A6B);
  static const muted = Color(0xFF8C9AB8);
  static const line = Color(0xFFE4EAF8);
  static const green = Color(0xFF0EA472);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const teal = Color(0xFF0891B2);
  static const violet = Color(0xFF7C3AED);
  static const rose = Color(0xFFE11D48);
}

// ─────────────────────────────────────────────────────────────────────────────
//  FORMAT HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmtRev(double v) {
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

String _fmtNum(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    return Consumer<ProfileProvider>(
      builder: (ctx, prov, _) {
        if (prov.isLoading || prov.profile == null) {
          return const Scaffold(backgroundColor: _K.page, body: _Shimmer());
        }
        return _Screen(prov: prov, p: prov.profile!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _Screen extends StatelessWidget {
  final ProfileProvider prov;
  final UserProfile p;
  const _Screen({required this.prov, required this.p});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _K.page,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: RefreshIndicator(
              color: _K.royal,
              backgroundColor: _K.white,
              onRefresh: () => prov.loadProfile(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // ── Top bar ────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _TopBar(
                      onEdit: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, a, __) => const EditProfileScreen(),
                          transitionsBuilder: (_, a, __, child) =>
                              FadeTransition(
                                opacity: a,
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.06),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: a,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                  child: child,
                                ),
                              ),
                        ),
                      ).then((_) => prov.loadProfile()),
                    ),
                  ),

                  // ── Identity card ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _IdentityCard(p: p, onToggleShift: prov.toggleShift),
                  ),

                  // ── Today's summary strip ──────────────────────────────────
                  SliverToBoxAdapter(child: _TodayStatsStrip(prov: prov)),

                  // ── Personal info ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'PERSONAL INFO'),
                  ),
                  SliverToBoxAdapter(child: _PersonalCard(p: p)),

                  // ── Organisation ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'ORGANISATION'),
                  ),
                  SliverToBoxAdapter(
                    child: _OrgCard(p: p, prov: prov),
                  ),

                  // ── Account timeline ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'ACCOUNT TIMELINE'),
                  ),
                  SliverToBoxAdapter(child: _TimelineCard(p: p)),

                  // ── Weekly / Monthly performance ───────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'PERFORMANCE SUMMARY'),
                  ),
                  SliverToBoxAdapter(child: _WeekMonthPerfCard(prov: prov)),

                  // ── All-time performance ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'ALL-TIME PERFORMANCE'),
                  ),
                  SliverToBoxAdapter(
                    child: _AllTimePerfCard(p: p, prov: prov),
                  ),

                  // ── Quick actions ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHead(title: 'QUICK ACTIONS'),
                  ),
                  SliverToBoxAdapter(
                    child: _ActionsGrid(p: p, prov: prov),
                  ),

                  // ── Recent activity ────────────────────────────────────────
                  if (p.recentActivity.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHead(title: 'RECENT ACTIVITY'),
                    ),
                    SliverToBoxAdapter(
                      child: _ActivityCard(p: p, prov: prov),
                    ),
                  ],

                  // ── Sign out ───────────────────────────────────────────────
                  SliverToBoxAdapter(child: _SignOutRow()),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),
            ),
          ),
          if (prov.isLoading)
            Container(
              color: Colors.white54,
              child: const Center(
                child: CircularProgressIndicator(color: _K.royal),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onEdit;
  const _TopBar({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _K.ink,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Account overview',
                style: TextStyle(
                  fontSize: 13,
                  color: _K.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _K.royalSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _K.royalBorder),
              ),
              child: const Icon(Icons.edit_outlined, color: _K.royal, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final UserProfile p;
  final VoidCallback onToggleShift;
  const _IdentityCard({required this.p, required this.onToggleShift});

  @override
  Widget build(BuildContext context) {
    return _LuxCard(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(
              initials: p.avatarInitials ?? 'U',
              roleColor: p.role.color,
              isActive: p.isActive,
              photoUrl: p.profilePhoto,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _K.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _K.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (p.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.phone,
                      style: const TextStyle(fontSize: 12, color: _K.muted),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Pill(
                        label: '${p.role.emoji} ${p.role.label}',
                        bg: p.role.color.withOpacity(0.10),
                        border: p.role.color.withOpacity(0.25),
                        textColor: p.role.color,
                      ),
                      _Pill(
                        label: p.isActive ? '● Active' : '○ Inactive',
                        bg: p.isActive
                            ? _K.green.withOpacity(0.09)
                            : _K.muted.withOpacity(0.08),
                        border: p.isActive
                            ? _K.green.withOpacity(0.25)
                            : _K.muted.withOpacity(0.15),
                        textColor: p.isActive ? _K.green : _K.muted,
                      ),
                      GestureDetector(
                        onTap: onToggleShift,
                        child: _Pill(
                          label: p.isOnShift ? '🕐 On Shift' : '⏸ Off Shift',
                          bg: p.isOnShift ? _K.royalSoft : _K.line,
                          border: p.isOnShift ? _K.royalBorder : _K.line,
                          textColor: p.isOnShift ? _K.royal : _K.muted,
                          trailingIcon: Icons.swap_horiz_rounded,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials;
  final Color roleColor;
  final bool isActive;
  final String photoUrl;

  const _Avatar({
    required this.initials,
    required this.roleColor,
    required this.isActive,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl.isEmpty
                ? LinearGradient(
                    colors: [roleColor, roleColor.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: roleColor.withOpacity(0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: photoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [roleColor, roleColor.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _initialsWidget(),
                  ),
                )
              : _initialsWidget(),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _K.green : _K.muted,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialsWidget() => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PILL
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color bg, border, textColor;
  final IconData? trailingIcon;
  const _Pill({
    required this.label,
    required this.bg,
    required this.border,
    required this.textColor,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 3),
            Icon(trailingIcon, size: 11, color: textColor),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TODAY'S STATS STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _TodayStatsStrip extends StatelessWidget {
  final ProfileProvider prov;
  const _TodayStatsStrip({required this.prov});

  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats;
    final loading = prov.statsLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label + spinner
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text(
                  "TODAY'S SUMMARY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _K.muted,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _K.royal,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              _StatBox(
                value: loading ? '–' : '${s.ordersTodayCount}',
                label: 'Orders\nToday',
                color: _K.royal,
              ),
              const SizedBox(width: 8),
              _StatBox(
                value: loading ? '–' : '${s.tablesTodayCount}',
                label: 'Tables\nToday',
                color: _K.teal,
              ),
              const SizedBox(width: 8),
              _StatBox(
                value: loading ? '–' : _fmtRev(s.revenueTodayAmount),
                label: 'Revenue\nToday',
                color: _K.green,
              ),
              const SizedBox(width: 8),
              _StatBox(
                value: loading ? '–' : '${s.shiftsThisWeek}/6',
                label: 'Shifts\nWeek',
                color: _K.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAT BOX
// ─────────────────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: _K.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(bottom: BorderSide(color: color, width: 2.5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: _K.muted,
                height: 1.3,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADING
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHead extends StatelessWidget {
  final String title;
  const _SectionHead({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _K.muted,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LUXURY CARD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _LuxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _LuxCard({
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _K.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _K.line),
        boxShadow: [
          BoxShadow(
            color: _K.royal.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIELD ROW
// ─────────────────────────────────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final bool isLast;
  final Widget? trailing;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _K.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _K.ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: _K.line,
            margin: const EdgeInsets.only(left: 69),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.22)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PERSONAL CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalCard extends StatelessWidget {
  final UserProfile p;
  const _PersonalCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final shortUid = p.id.length > 18 ? '${p.id.substring(0, 18)}…' : p.id;
    return _LuxCard(
      child: Column(
        children: [
          _FieldRow(
            label: 'FULL NAME',
            value: p.name,
            icon: Icons.badge_outlined,
            iconColor: _K.royal,
          ),
          _FieldRow(
            label: 'EMAIL ADDRESS',
            value: p.email,
            icon: Icons.alternate_email_rounded,
            iconColor: _K.violet,
            trailing: _Badge(label: 'Verified', color: _K.green),
          ),
          _FieldRow(
            label: 'PHONE NUMBER',
            value: p.phone.isEmpty ? 'Not added' : p.phone,
            icon: Icons.phone_outlined,
            iconColor: _K.teal,
          ),
          _FieldRow(
            label: 'USER ID (UID)',
            value: shortUid,
            icon: Icons.fingerprint_rounded,
            iconColor: _K.muted,
            isLast: true,
            trailing: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: p.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('UID copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _K.royalSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.copy_outlined,
                  size: 14,
                  color: _K.royal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORGANISATION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OrgCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _OrgCard({required this.p, required this.prov});

  @override
  Widget build(BuildContext context) {
    return _LuxCard(
      child: Column(
        children: [
          _FieldRow(
            label: 'BUSINESS NAME',
            value: p.businessName.isEmpty ? 'Not assigned' : p.businessName,
            icon: Icons.storefront_outlined,
            iconColor: _K.royal,
            trailing: _Badge(
              label: p.isActive ? 'Active' : 'Inactive',
              color: p.isActive ? _K.green : _K.muted,
            ),
          ),
          _FieldRow(
            label: 'BUSINESS ID',
            value: p.businessId.isEmpty ? 'Not assigned' : p.businessId,
            icon: Icons.corporate_fare_rounded,
            iconColor: _K.teal,
          ),
          _CreatedByRow(p: p, prov: prov),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CREATED BY ROW
// ─────────────────────────────────────────────────────────────────────────────
class _CreatedByRow extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _CreatedByRow({required this.p, required this.prov});

  @override
  Widget build(BuildContext context) {
    final bool isSelf = p.createdBy == p.id;

    String displayName;
    if (prov.creatorName.isNotEmpty) {
      displayName = isSelf ? '${prov.creatorName} (You)' : prov.creatorName;
    } else if (p.createdByName.isNotEmpty) {
      displayName = isSelf ? '${p.createdByName} (You)' : p.createdByName;
    } else {
      displayName = p.createdBy.isNotEmpty ? 'Unknown' : '—';
    }

    final String displayRole = prov.creatorRole.isNotEmpty
        ? prov.creatorRole
        : p.createdByRole;

    return Column(
      children: [
        Container(
          height: 1,
          color: _K.line,
          margin: const EdgeInsets.only(left: 69),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _K.violet.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  size: 18,
                  color: _K.violet,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CREATED BY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _K.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _K.ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (displayRole.isNotEmpty) _RoleBadge(role: displayRole),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'admin':
        return const Color(0xFF6366F1);
      case 'manager':
        return const Color(0xFF1A56DB);
      case 'cashier':
        return const Color(0xFF0D9488);
      case 'waiter':
      case 'server':
        return const Color(0xFF10B981);
      case 'chef':
        return const Color(0xFFF59E0B);
      default:
        return _K.royal;
    }
  }

  String get _emoji {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'admin':
        return '👑';
      case 'manager':
        return '💼';
      case 'cashier':
        return '🧾';
      case 'waiter':
      case 'server':
        return '🍽️';
      case 'chef':
        return '👨‍🍳';
      default:
        return '👤';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMELINE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final UserProfile p;
  const _TimelineCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return _LuxCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          children: [
            _TRow(
              color: _K.royal,
              label: 'ACCOUNT CREATED',
              value: p.formattedJoinDate,
              badge: '${p.tenureLabel} member',
              badgeColor: _K.royal,
            ),
            _TDivider(),
            _TRow(
              color: _K.amber,
              label: 'PASSWORD LAST CHANGED',
              value: p.passwordLastChangedLabel ?? 'Not updated yet',
              badge: p.passwordLastChanged != null ? 'Updated' : 'Pending',
              badgeColor: p.passwordLastChanged != null ? _K.green : _K.amber,
            ),
            _TDivider(),
            _TRow(
              color: _K.green,
              label: 'PROFILE LAST UPDATED',
              value: p.updatedAtLabel ?? 'No updates yet',
              badge: 'Auto-saved',
              badgeColor: _K.teal,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TRow extends StatelessWidget {
  final Color color;
  final String label, value, badge;
  final Color badgeColor;
  final bool isLast;
  const _TRow({
    required this.color,
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 3),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _K.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _K.ink,
                ),
              ),
              if (!isLast) const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _TDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 1.5,
        height: 22,
        margin: const EdgeInsets.only(left: 5.25),
        color: _K.line,
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PERFORMANCE BLOCK  (shared small card used in perf grids)
// ─────────────────────────────────────────────────────────────────────────────
class _PBlock extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _PBlock({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _K.muted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB BUTTON  (used in WeekMonth card)
// ─────────────────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _K.royal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _K.royal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WEEKLY & MONTHLY PERFORMANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WeekMonthPerfCard extends StatefulWidget {
  final ProfileProvider prov;
  const _WeekMonthPerfCard({required this.prov});

  @override
  State<_WeekMonthPerfCard> createState() => _WeekMonthPerfCardState();
}

class _WeekMonthPerfCardState extends State<_WeekMonthPerfCard> {
  int _tab = 0; // 0 = Week, 1 = Month

  @override
  Widget build(BuildContext context) {
    final s = widget.prov.perfStats;
    final loading = widget.prov.statsLoading;
    final isWeek = _tab == 0;

    final orders = isWeek ? s.ordersWeekCount : s.ordersMonthCount;
    final revenue = isWeek ? s.revenueWeekAmount : s.revenueMonthAmount;
    final tables = isWeek ? s.tablesWeekCount : s.tablesMonthCount;
    final aov = isWeek ? s.avgOrderValueWeek : s.avgOrderValueMonth;

    return _LuxCard(
      child: Column(
        children: [
          // ── Header with tab toggle ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _K.royal.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _K.royal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Performance Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _K.ink,
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _K.royal,
                      ),
                    ),
                  ),
                // Tab toggle
                Container(
                  decoration: BoxDecoration(
                    color: _K.royalSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TabBtn(
                        label: 'Week',
                        active: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      _TabBtn(
                        label: 'Month',
                        active: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Stats grid ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _PBlock(
                      emoji: '🧾',
                      label: 'Total Orders\nHandled',
                      value: loading ? '–' : '$orders',
                      color: _K.royal,
                    ),
                    const SizedBox(width: 10),
                    _PBlock(
                      emoji: '💵',
                      label: 'Total Revenue\nGenerated',
                      value: loading ? '–' : _fmtRev(revenue),
                      color: _K.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PBlock(
                      emoji: '🪑',
                      label: 'Tables\nManaged',
                      value: loading ? '–' : '$tables',
                      color: _K.teal,
                    ),
                    const SizedBox(width: 10),
                    _PBlock(
                      emoji: '📊',
                      label: 'Avg Order\nValue',
                      value: loading ? '–' : _fmtRev(aov),
                      color: _K.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALL-TIME PERFORMANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AllTimePerfCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _AllTimePerfCard({required this.p, required this.prov});

  String get _tenureDetailed {
    final diff = DateTime.now().difference(p.joinedDate);
    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    final days = diff.inDays % 30;
    if (years > 0) return '$years yr ${months}mo';
    if (months > 0) return '${months}mo ${days}d';
    return '${diff.inDays}d';
  }

  String get _weeksWorked {
    final diff = DateTime.now().difference(p.joinedDate);
    return '${(diff.inDays / 7).floor()}';
  }

  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats;
    final loading = prov.statsLoading;

    return _LuxCard(
      child: Column(
        children: [
          // ── Gradient header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_K.royal, _K.royalMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'All-Time Performance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Since ${p.joinedDate.year}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats grid ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _PBlock(
                      emoji: '🧾',
                      label: 'Total Orders\nHandled',
                      value: loading ? '–' : _fmtNum(s.ordersAllTimeCount),
                      color: _K.royal,
                    ),
                    const SizedBox(width: 10),
                    _PBlock(
                      emoji: '💰',
                      label: 'Total Revenue\nGenerated',
                      value: loading ? '–' : _fmtRev(s.revenueAllTimeAmount),
                      color: _K.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PBlock(
                      emoji: '🪑',
                      label: 'Tables\nManaged',
                      value: loading ? '–' : _fmtNum(s.tablesAllTimeCount),
                      color: _K.teal,
                    ),
                    const SizedBox(width: 10),
                    _PBlock(
                      emoji: '📅',
                      label: 'Weeks\nWorked',
                      value: _weeksWorked,
                      color: _K.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Tenure banner ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _K.royal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _K.royal.withOpacity(0.14)),
                  ),
                  child: Row(
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Work Experience',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _K.muted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tenureDetailed,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _K.royal,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _K.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _K.green.withOpacity(0.25)),
                        ),
                        child: Text(
                          p.tenureLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _K.green,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsGrid extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _ActionsGrid({required this.p, required this.prov});

  bool get _canCreateAccount {
    final role = p.role.label.toLowerCase();
    return role == 'owner' || role == 'admin' || role == 'manager';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Create\nAccount',
              sub: _canCreateAccount ? 'Add new staff' : 'No permission',
              color: _canCreateAccount ? _K.royal : _K.muted,
              isDisabled: !_canCreateAccount,
              onTap: _canCreateAccount
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateAccountScreen(
                          businessId: p.businessId,
                          businessName: p.businessName,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.lock_reset_rounded,
              label: 'Change\nPassword',
              sub: 'Update security',
              color: _K.amber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ).then((_) => prov.loadProfile()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _K.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.18)),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: color.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _K.ink,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: _K.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    isDisabled ? 'Restricted' : 'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isDisabled
                        ? Icons.lock_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 13,
                    color: color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _ActivityCard({required this.p, required this.prov});

  @override
  Widget build(BuildContext context) {
    return _LuxCard(
      child: Column(
        children: p.recentActivity.asMap().entries.map((e) {
          final isLast = e.key == p.recentActivity.length - 1;
          final lg = e.value;
          return _ARow(
            emoji: lg.icon,
            title: lg.title,
            sub: lg.subtitle,
            time: prov.activityTimeLabel(lg),
            isLast: isLast,
          );
        }).toList(),
      ),
    );
  }
}

class _ARow extends StatelessWidget {
  final String emoji, title, sub, time;
  final bool isLast;
  const _ARow({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.time,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _K.royalSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _K.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 11, color: _K.muted),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: _K.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: _K.line,
            margin: const EdgeInsets.only(left: 68),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIGN OUT ROW
// ─────────────────────────────────────────────────────────────────────────────
class _SignOutRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: GestureDetector(
        onTap: () => _confirm(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _K.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _K.rose.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: _K.rose.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _K.rose.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _K.rose,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sign Out',
                style: TextStyle(
                  color: _K.rose,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _K.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _K.rose.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _K.rose,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign out?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _K.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will be signed out of your account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _K.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        side: const BorderSide(color: _K.line, width: 1.5),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _K.body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ctx.read<AppAuthenticationProvider>().logout();
                        if (ctx.mounted) {
                          Navigator.pushAndRemoveUntil(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (r) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _K.rose,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DOT-GRID TEXTURE PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF1847C4).withOpacity(0.03);
    for (double x = 0; x < size.width; x += 22)
      for (double y = 0; y < size.height; y += 22)
        canvas.drawCircle(Offset(x, y), 1.1, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER SKELETON
// ─────────────────────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _a = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _b({double w = double.infinity, double h = 14, double r = 8}) =>
      AnimatedBuilder(
        animation: _a,
        builder: (_, __) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            color: Color.lerp(
              const Color(0xFFDDE6F8),
              const Color(0xFFEEF3FC),
              _a.value,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _b(w: 160, h: 30, r: 8),
            const SizedBox(height: 7),
            _b(w: 110, h: 14, r: 6),
            const SizedBox(height: 24),
            _b(h: 130, r: 22),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _b(h: 78, r: 16)),
                const SizedBox(width: 8),
                Expanded(child: _b(h: 78, r: 16)),
                const SizedBox(width: 8),
                Expanded(child: _b(h: 78, r: 16)),
                const SizedBox(width: 8),
                Expanded(child: _b(h: 78, r: 16)),
              ],
            ),
            const SizedBox(height: 26),
            _b(w: 80, h: 10, r: 4),
            const SizedBox(height: 10),
            _b(h: 170, r: 20),
            const SizedBox(height: 22),
            _b(w: 90, h: 10, r: 4),
            const SizedBox(height: 10),
            _b(h: 120, r: 20),
            const SizedBox(height: 22),
            _b(w: 110, h: 10, r: 4),
            const SizedBox(height: 10),
            _b(h: 155, r: 20),
            const SizedBox(height: 22),
            _b(w: 100, h: 10, r: 4),
            const SizedBox(height: 10),
            _b(h: 180, r: 20),
            const SizedBox(height: 22),
            _b(w: 120, h: 10, r: 4),
            const SizedBox(height: 10),
            _b(h: 240, r: 20),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _b(h: 140, r: 20)),
                const SizedBox(width: 12),
                Expanded(child: _b(h: 140, r: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

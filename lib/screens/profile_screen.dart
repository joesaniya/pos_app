import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/employee_management_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/screens/change_pwd_screen.dart';
import 'package:pos_app/screens/create_account_screen.dart';
import 'package:pos_app/screens/edit_profile_Screen.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg      = Color(0xFFF4F7FF);
  static const white   = Color(0xFFFFFFFF);
  static const royal   = Color(0xFF1847C4);
  static const royalLt = Color(0xFF3B6FE8);
  static const royalBg = Color(0xFFEBF0FF);
  static const royalBd = Color(0xFFCDD8FB);
  static const ink     = Color(0xFF0D1B3E);
  static const body    = Color(0xFF3A4A6B);
  static const muted   = Color(0xFF8C9AB8);
  static const line    = Color(0xFFE4EAF8);
  static const green   = Color(0xFF0EA472);
  static const amber   = Color(0xFFD97706);
  static const teal    = Color(0xFF0891B2);
  static const violet  = Color(0xFF7C3AED);
  static const rose    = Color(0xFFE11D48);
  static const indigo  = Color(0xFF6366F1);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _rev(double v) {
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000)   return '₹${(v / 1000).toStringAsFixed(1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

String _num(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
    case 'system':
    case 'admin':   return _C.indigo;
    case 'manager': return _C.royal;
    case 'cashier': return _C.teal;
    case 'waiter':
    case 'server':  return _C.green;
    case 'chef':    return _C.amber;
    default:        return _C.muted;
  }
}

String _roleEmoji(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
    case 'system':  return '👑';
    case 'admin':   return '⚡';
    case 'manager': return '💼';
    case 'cashier': return '🧾';
    case 'waiter':
    case 'server':  return '🍽️';
    case 'chef':    return '👨‍🍳';
    default:        return '👤';
  }
}

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
      if (!mounted) return;
      context.read<ProfileProvider>().loadProfile();
      context.read<EmployeeManagementProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Consumer<ProfileProvider>(
      builder: (_, prov, __) {
        if (prov.isLoading || prov.profile == null) {
          return const Scaffold(backgroundColor: _C.bg, body: _Shimmer());
        }
        return _Body(prov: prov, p: prov.profile!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BODY
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final ProfileProvider prov;
  final UserProfile p;
  const _Body({required this.prov, required this.p});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeManagementProvider>(
      builder: (ctx, emp, __) {
        return Scaffold(
          backgroundColor: _C.bg,
          body: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _Dots())),
            SafeArea(
              child: RefreshIndicator(
                color: _C.royal,
                backgroundColor: _C.white,
                onRefresh: () async {
                  await prov.loadProfile();
                  if (emp.canManage) await emp.refresh();
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    _sliver(_TopBar(onEdit: () => _goEdit(ctx))),
                    _sliver(_IdentityCard(p: p, onShift: prov.toggleShift)),
                    _sliver(_TodayStrip(prov: prov)),
                    _sliver(const _SHead('PERSONAL INFO')),
                    _sliver(_PersonalCard(p: p)),
                    _sliver(const _SHead('ORGANISATION')),
                    _sliver(_OrgCard(p: p, prov: prov)),
                    _sliver(const _SHead('ACCOUNT TIMELINE')),
                    _sliver(_TimelineCard(p: p)),
                    _sliver(const _SHead('PERFORMANCE SUMMARY')),
                    _sliver(_WeekMonthCard(prov: prov)),
                    _sliver(const _SHead('ALL-TIME PERFORMANCE')),
                    _sliver(_AllTimeCard(p: p, prov: prov)),
                    // ── Employee section: only for privileged roles ──────────
                    if (emp.canManage) ...[
                      _sliver(const _SHead('TEAM MEMBERS')),
                      _sliver(_TeamSection(emp: emp, p: p)),
                    ],
                    _sliver(const _SHead('QUICK ACTIONS')),
                    _sliver(_ActionsGrid(p: p, prov: prov)),
                    if (p.recentActivity.isNotEmpty) ...[
                      _sliver(const _SHead('RECENT ACTIVITY')),
                      _sliver(_ActivityCard(p: p, prov: prov)),
                    ],
                    _sliver(_SignOut()),
                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                ),
              ),
            ),
            if (prov.isLoading || emp.isDeleting)
              Container(
                color: Colors.white54,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: _C.royal),
                    if (emp.isDeleting) ...[
                      const SizedBox(height: 12),
                      const Text('Removing member…',
                          style: TextStyle(color: _C.ink, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
          ]),
        );
      },
    );
  }

  SliverToBoxAdapter _sliver(Widget w) => SliverToBoxAdapter(child: w);

  void _goEdit(BuildContext ctx) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const EditProfileScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06), end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    ).then((_) => prov.loadProfile());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onEdit;
  const _TopBar({required this.onEdit});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: _C.ink, letterSpacing: -0.8, height: 1.0)),
        const SizedBox(height: 3),
        const Text('Account overview',
            style: TextStyle(fontSize: 13, color: _C.muted, fontWeight: FontWeight.w500)),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: onEdit,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: _C.royalBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.royalBd)),
          child: const Icon(Icons.edit_outlined, color: _C.royal, size: 20),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final UserProfile p;
  final VoidCallback onShift;
  const _IdentityCard({required this.p, required this.onShift});

  @override
  Widget build(BuildContext context) => _Card(
    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _Avatar(initials: p.avatarInitials ?? 'U', roleColor: p.role.color,
            isActive: p.isActive, photoUrl: p.profilePhoto),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
              color: _C.ink, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(p.email, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w500)),
          if (p.phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(p.phone, style: const TextStyle(fontSize: 12, color: _C.muted)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Pill('${p.role.emoji} ${p.role.label}', p.role.color.withOpacity(.10),
                p.role.color.withOpacity(.25), p.role.color),
            _Pill(p.isActive ? '● Active' : '○ Inactive',
                p.isActive ? _C.green.withOpacity(.09) : _C.muted.withOpacity(.08),
                p.isActive ? _C.green.withOpacity(.25) : _C.muted.withOpacity(.15),
                p.isActive ? _C.green : _C.muted),
            GestureDetector(
              onTap: onShift,
              child: _Pill(
                p.isOnShift ? '🕐 On Shift' : '⏸ Off Shift',
                p.isOnShift ? _C.royalBg : _C.line,
                p.isOnShift ? _C.royalBd : _C.line,
                p.isOnShift ? _C.royal : _C.muted,
                trail: Icons.swap_horiz_rounded,
              ),
            ),
          ]),
        ])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials, photoUrl;
  final Color roleColor;
  final bool isActive;
  const _Avatar({required this.initials, required this.roleColor,
      required this.isActive, required this.photoUrl});

  @override
  Widget build(BuildContext context) => Stack(children: [
    Container(
      width: 76, height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl.isEmpty
            ? LinearGradient(colors: [roleColor, roleColor.withOpacity(.6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        boxShadow: [BoxShadow(color: roleColor.withOpacity(.30), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: photoUrl.isNotEmpty
          ? ClipOval(child: Image.network(photoUrl, width: 76, height: 76, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _txt()))
          : _txt(),
    ),
    Positioned(right: 1, bottom: 1,
      child: Container(width: 17, height: 17,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: isActive ? _C.green : _C.muted,
              border: Border.all(color: Colors.white, width: 2.5)))),
  ]);

  Widget _txt() => Center(child: Text(initials,
      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  PILL
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color bg, border, text;
  final IconData? trail;
  const _Pill(this.label, this.bg, this.border, this.text, {this.trail});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
      if (trail != null) ...[const SizedBox(width: 3), Icon(trail, size: 11, color: text)],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TODAY STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _TodayStrip extends StatelessWidget {
  final ProfileProvider prov;
  const _TodayStrip({required this.prov});

  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats;
    final ld = prov.statsLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            const Text("TODAY'S SUMMARY",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: _C.muted, letterSpacing: 2)),
            const SizedBox(width: 8),
            if (ld) const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _C.royal)),
          ])),
        Row(children: [
          _SBox(ld ? '–' : '${s.ordersTodayCount}',   'Orders\nToday',   _C.royal),
          const SizedBox(width: 8),
          _SBox(ld ? '–' : '${s.tablesTodayCount}',   'Tables\nToday',   _C.teal),
          const SizedBox(width: 8),
          _SBox(ld ? '–' : _rev(s.revenueTodayAmount),'Revenue\nToday',  _C.green),
          const SizedBox(width: 8),
          _SBox(ld ? '–' : '${s.shiftsThisWeek}/6',   'Shifts\nWeek',    _C.violet),
        ]),
      ]),
    );
  }
}

class _SBox extends StatelessWidget {
  final String v, lbl;
  final Color c;
  const _SBox(this.v, this.lbl, this.c);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: _C.white, borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: c, width: 2.5)),
        boxShadow: [BoxShadow(color: c.withOpacity(.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c, letterSpacing: -.5)),
        const SizedBox(height: 4),
        Text(lbl, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                color: _C.muted, height: 1.3)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEAD
// ─────────────────────────────────────────────────────────────────────────────
class _SHead extends StatelessWidget {
  final String t;
  const _SHead(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
        color: _C.muted, letterSpacing: 2.0)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _Card({required this.child, this.margin = const EdgeInsets.symmetric(horizontal: 20)});
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: _C.white, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _C.line),
      boxShadow: [
        BoxShadow(color: _C.royal.withOpacity(.06), blurRadius: 24, offset: const Offset(0, 8)),
        BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIELD ROW
// ─────────────────────────────────────────────────────────────────────────────
class _FRow extends StatelessWidget {
  final String lbl, val;
  final IconData icon;
  final Color iconC;
  final bool last;
  final Widget? trail;
  const _FRow({required this.lbl, required this.val, required this.icon,
      required this.iconC, this.last = false, this.trail});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: iconC.withOpacity(.09), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: iconC)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lbl, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: _C.muted, letterSpacing: .5)),
          const SizedBox(height: 3),
          Text(val.isEmpty ? '—' : val, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700, color: _C.ink, height: 1.2)),
        ])),
        if (trail != null) trail!,
      ]),
    ),
    if (!last) Container(height: 1, color: _C.line, margin: const EdgeInsets.only(left: 69)),
  ]);
}

class _Bdg extends StatelessWidget {
  final String lbl;
  final Color c;
  const _Bdg(this.lbl, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(.09), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(.22))),
    child: Text(lbl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
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
    return _Card(child: Column(children: [
      _FRow(lbl: 'FULL NAME', val: p.name, icon: Icons.badge_outlined, iconC: _C.royal),
      _FRow(lbl: 'EMAIL ADDRESS', val: p.email, icon: Icons.alternate_email_rounded,
          iconC: _C.violet, trail: _Bdg('Verified', _C.green)),
      _FRow(lbl: 'PHONE NUMBER', val: p.phone.isEmpty ? 'Not added' : p.phone,
          icon: Icons.phone_outlined, iconC: _C.teal),
      _FRow(lbl: 'USER ID (UID)', val: shortUid, icon: Icons.fingerprint_rounded,
          iconC: _C.muted, last: true,
          trail: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: p.id));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('UID copied'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: _C.royalBg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.copy_outlined, size: 14, color: _C.royal)),
          )),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORG CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OrgCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _OrgCard({required this.p, required this.prov});
  @override
  Widget build(BuildContext context) {
    final isSelf = p.createdBy == p.id;
    final cName  = prov.creatorName.isNotEmpty
        ? (isSelf ? '${prov.creatorName} (You)' : prov.creatorName)
        : (p.createdByName.isNotEmpty ? (isSelf ? '${p.createdByName} (You)' : p.createdByName) : '—');
    final cRole  = prov.creatorRole.isNotEmpty ? prov.creatorRole : p.createdByRole;

    return _Card(child: Column(children: [
      _FRow(lbl: 'BUSINESS NAME', val: p.businessName.isEmpty ? 'Not assigned' : p.businessName,
          icon: Icons.storefront_outlined, iconC: _C.royal,
          trail: _Bdg(p.isActive ? 'Active' : 'Inactive', p.isActive ? _C.green : _C.muted)),
      _FRow(lbl: 'BUSINESS ID', val: p.businessId.isEmpty ? 'Not assigned' : p.businessId,
          icon: Icons.corporate_fare_rounded, iconC: _C.teal),
      // Created by row
      Column(children: [
        Container(height: 1, color: _C.line, margin: const EdgeInsets.only(left: 69)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(color: _C.violet.withOpacity(.09),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.person_add_outlined, size: 18, color: _C.violet)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CREATED BY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _C.muted, letterSpacing: .5)),
              const SizedBox(height: 4),
              Text(cName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
            ])),
            if (cRole.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _roleColor(cRole).withOpacity(.09),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _roleColor(cRole).withOpacity(.22))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_roleEmoji(cRole), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(cRole, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: _roleColor(cRole))),
                ]),
              ),
          ]),
        ),
      ]),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TIMELINE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final UserProfile p;
  const _TimelineCard({required this.p});
  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(children: [
        _TRow(_C.royal, 'ACCOUNT CREATED', p.formattedJoinDate, '${p.tenureLabel} member', _C.royal),
        _TLine(),
        _TRow(_C.amber, 'PASSWORD LAST CHANGED',
            p.passwordLastChangedLabel ?? 'Not updated yet',
            p.passwordLastChanged != null ? 'Updated' : 'Pending',
            p.passwordLastChanged != null ? _C.green : _C.amber),
        _TLine(),
        _TRow(_C.green, 'PROFILE LAST UPDATED',
            p.updatedAtLabel ?? 'No updates yet', 'Auto-saved', _C.teal, last: true),
      ]),
    ),
  );
}

class _TRow extends StatelessWidget {
  final Color dot; final String lbl, val, badge; final Color bdgC; final bool last;
  const _TRow(this.dot, this.lbl, this.val, this.badge, this.bdgC, {this.last = false});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Column(children: [const SizedBox(height: 3),
      Container(width: 12, height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot,
              boxShadow: [BoxShadow(color: dot.withOpacity(.45), blurRadius: 6, spreadRadius: 1)]))]),
    const SizedBox(width: 15),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(lbl, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: _C.muted, letterSpacing: .5)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bdgC.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: bdgC))),
      ]),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
      if (!last) const SizedBox(height: 18),
    ])),
  ]);
}

class _TLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 1.5, height: 22, margin: const EdgeInsets.only(left: 5.25), color: _C.line)]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PERF BLOCK
// ─────────────────────────────────────────────────────────────────────────────
class _PBlk extends StatelessWidget {
  final String emoji, lbl, val; final Color c;
  const _PBlk({required this.emoji, required this.lbl, required this.val, required this.c});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withOpacity(.05), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(.14))),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lbl, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: _C.muted, height: 1.3)),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c)),
        ])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  WEEK/MONTH PERFORMANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WeekMonthCard extends StatefulWidget {
  final ProfileProvider prov;
  const _WeekMonthCard({required this.prov});
  @override
  State<_WeekMonthCard> createState() => _WeekMonthCardState();
}
class _WeekMonthCardState extends State<_WeekMonthCard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final s  = widget.prov.perfStats;
    final ld = widget.prov.statsLoading;
    final wk = _tab == 0;
    return _Card(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
        child: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _C.royal.withOpacity(.09), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.bar_chart_rounded, color: _C.royal, size: 18)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Performance Summary',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink))),
          if (ld) const Padding(padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: _C.royal))),
          Container(
            decoration: BoxDecoration(color: _C.royalBg, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _TabBtn('Week',  _tab == 0, () => setState(() => _tab = 0)),
              _TabBtn('Month', _tab == 1, () => setState(() => _tab = 1)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(children: [
          Row(children: [
            _PBlk(emoji: '🧾', lbl: 'Total Orders\nHandled',
                val: ld ? '–' : '${wk ? s.ordersWeekCount : s.ordersMonthCount}', c: _C.royal),
            const SizedBox(width: 10),
            _PBlk(emoji: '💵', lbl: 'Total Revenue\nGenerated',
                val: ld ? '–' : _rev(wk ? s.revenueWeekAmount : s.revenueMonthAmount), c: _C.green),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _PBlk(emoji: '🪑', lbl: 'Tables\nManaged',
                val: ld ? '–' : '${wk ? s.tablesWeekCount : s.tablesMonthCount}', c: _C.teal),
            const SizedBox(width: 10),
            _PBlk(emoji: '📊', lbl: 'Avg Order\nValue',
                val: ld ? '–' : _rev(wk ? s.avgOrderValueWeek : s.avgOrderValueMonth), c: _C.amber),
          ]),
        ]),
      ),
    ]));
  }
}

class _TabBtn extends StatelessWidget {
  final String lbl; final bool on; final VoidCallback onTap;
  const _TabBtn(this.lbl, this.on, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: on ? _C.royal : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
      child: Text(lbl, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: on ? Colors.white : _C.royal)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALL-TIME CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AllTimeCard extends StatelessWidget {
  final UserProfile p; final ProfileProvider prov;
  const _AllTimeCard({required this.p, required this.prov});
  String get _tenure {
    final d = DateTime.now().difference(p.joinedDate);
    final y = d.inDays ~/ 365, mo = (d.inDays % 365) ~/ 30, dy = d.inDays % 30;
    if (y > 0)  return '$y yr ${mo}mo';
    if (mo > 0) return '${mo}mo ${dy}d';
    return '${d.inDays}d';
  }
  int get _weeks => (DateTime.now().difference(p.joinedDate).inDays / 7).floor();
  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats; final ld = prov.statsLoading;
    return _Card(child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_C.royal, _C.royalLt],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Row(children: [
          const Icon(Icons.insights_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 9),
          const Expanded(child: Text('All-Time Performance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
          if (ld) const Padding(padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('Since ${p.joinedDate.year}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            _PBlk(emoji: '🧾', lbl: 'Total Orders\nHandled',
                val: ld ? '–' : _num(s.ordersAllTimeCount), c: _C.royal),
            const SizedBox(width: 10),
            _PBlk(emoji: '💰', lbl: 'Total Revenue\nGenerated',
                val: ld ? '–' : _rev(s.revenueAllTimeAmount), c: _C.green),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _PBlk(emoji: '🪑', lbl: 'Tables\nManaged',
                val: ld ? '–' : _num(s.tablesAllTimeCount), c: _C.teal),
            const SizedBox(width: 10),
            _PBlk(emoji: '📅', lbl: 'Weeks\nWorked', val: '$_weeks', c: _C.violet),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _C.royal.withOpacity(.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.royal.withOpacity(.14))),
            child: Row(children: [
              const Text('⏱️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Work Experience',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.muted)),
                const SizedBox(height: 3),
                Text(_tenure, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                    color: _C.royal, letterSpacing: -.3)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _C.green.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.green.withOpacity(.25))),
                child: Text(p.tenureLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _C.green)),
              ),
            ]),
          ),
        ]),
      ),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEAM SECTION  (shown only for owner / system / admin / manager)
// ─────────────────────────────────────────────────────────────────────────────
class _TeamSection extends StatefulWidget {
  final EmployeeManagementProvider emp;
  final UserProfile p;
  const _TeamSection({required this.emp, required this.p});
  @override
  State<_TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<_TeamSection> {
  final _searchCtrl = TextEditingController();
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final emp  = widget.emp;
    final list = emp.employees;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // ── Summary chips ──────────────────────────────────────────────────
        _TeamSummary(total: emp.totalCount, active: emp.activeCount, inactive: emp.inactiveCount),
        const SizedBox(height: 12),

        // ── Search ─────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.line),
              boxShadow: [BoxShadow(color: _C.royal.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 3))]),
          child: TextField(
            controller: _searchCtrl,
            onChanged: emp.setSearch,
            style: const TextStyle(fontSize: 13, color: _C.ink, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search name, email or role…',
              hintStyle: const TextStyle(fontSize: 13, color: _C.muted),
              prefixIcon: const Icon(Icons.search_rounded, color: _C.muted, size: 20),
              suffixIcon: emp.searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _searchCtrl.clear(); emp.setSearch(''); },
                      child: const Icon(Icons.close_rounded, color: _C.muted, size: 18))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Role filter chips ──────────────────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: emp.availableRoles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final r   = emp.availableRoles[i];
              final sel = emp.roleFilter == r;
              final rc  = r == 'All' ? _C.royal : _roleColor(r);
              return GestureDetector(
                onTap: () => emp.setRoleFilter(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: sel ? rc : _C.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? rc : _C.line, width: 1.2)),
                  child: Text(r, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : _C.muted)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Content ────────────────────────────────────────────────────────
        if (emp.isLoading)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line)),
            child: const Center(child: CircularProgressIndicator(color: _C.royal)),
          )
        else if (list.isEmpty)
          _TeamEmpty(hasFilter: emp.searchQuery.isNotEmpty || emp.roleFilter != 'All')
        else
          Container(
            decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line),
                boxShadow: [BoxShadow(color: _C.royal.withOpacity(.05), blurRadius: 20, offset: const Offset(0, 6))]),
            child: Column(
              children: list.asMap().entries.map((e) => _EmpRow(
                emp:      e.value,
                isLast:   e.key == list.length - 1,
                isSelf:   widget.emp.isSelf(e.value.uid),
                canDel:   widget.emp.canDelete(e.value),
                canTog:   widget.emp.canToggle(e.value),
                onTap:    () => _detail(e.value),
                onToggle: () => _confirmToggle(e.value),
                onDelete: () => _confirmDelete(e.value),
              )).toList(),
            ),
          ),
      ]),
    );
  }

  // ── Detail sheet ───────────────────────────────────────────────────────────
  void _detail(EmployeeModel e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EmpSheet(
        emp: e,
        prov: widget.emp,
        isSelf: widget.emp.isSelf(e.uid),
        onToggle: () { Navigator.pop(context); _confirmToggle(e); },
        onDelete: () { Navigator.pop(context); _confirmDelete(e); },
      ),
    );
  }

  // ── Confirm toggle ─────────────────────────────────────────────────────────
  Future<void> _confirmToggle(EmployeeModel e) async {
    final action = e.isActive ? 'Deactivate' : 'Activate';
    final color  = e.isActive ? _C.amber : _C.green;
    final ok = await _confirm(
      icon: e.isActive ? Icons.person_off_outlined : Icons.person_outlined,
      iconColor: color,
      title: '$action ${e.name}?',
      msg: e.isActive
          ? '${e.name} will lose system access immediately.'
          : '${e.name} will regain system access.',
      confirm: action, confirmColor: color,
    );
    if (!ok) return;
    final res = await widget.emp.toggleStatus(e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res ? '${e.name} ${e.isActive ? 'deactivated' : 'activated'}' : 'Permission denied'),
        backgroundColor: res ? _C.green : _C.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  // ── Confirm delete ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete(EmployeeModel e) async {
    final ok = await _confirm(
      icon: Icons.delete_forever_rounded, iconColor: _C.rose,
      title: 'Remove ${e.name}?',
      msg: 'This will permanently remove ${e.name} from the company. '
           'They will lose all access immediately. This cannot be undone.',
      confirm: 'Remove', confirmColor: _C.rose, danger: true,
    );
    if (!ok) return;
    final res = await widget.emp.deleteEmployee(e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res ? '${e.name} has been removed' : 'Failed to remove member'),
        backgroundColor: res ? _C.green : _C.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<bool> _confirm({
    required IconData icon, required Color iconColor,
    required String title, required String msg,
    required String confirm, required Color confirmColor, bool danger = false,
  }) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialog(icon: icon, iconColor: iconColor, title: title,
          msg: msg, confirmLabel: confirm, confirmColor: confirmColor),
    );
    return v == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEAM SUMMARY CHIPS
// ─────────────────────────────────────────────────────────────────────────────
class _TeamSummary extends StatelessWidget {
  final int total, active, inactive;
  const _TeamSummary({required this.total, required this.active, required this.inactive});
  @override
  Widget build(BuildContext context) => Row(children: [
    _TSChip('$total', 'Total', _C.royal, _C.royalBg),
    const SizedBox(width: 8),
    _TSChip('$active', 'Active', _C.green, _C.green.withOpacity(.09)),
    const SizedBox(width: 8),
    _TSChip('$inactive', 'Inactive', _C.muted, _C.muted.withOpacity(.09)),
  ]);
}

class _TSChip extends StatelessWidget {
  final String val, lbl; final Color c, bg;
  const _TSChip(this.val, this.lbl, this.c, this.bg);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(.20))),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
        const SizedBox(height: 2),
        Text(lbl, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.muted)),
      ]),
    ),
  );
}

class _TeamEmpty extends StatelessWidget {
  final bool hasFilter;
  const _TeamEmpty({required this.hasFilter});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line)),
    child: Column(children: [
      const Text('👥', style: TextStyle(fontSize: 36)),
      const SizedBox(height: 10),
      Text(hasFilter ? 'No members match your filter' : 'No team members yet',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
      const SizedBox(height: 4),
      Text(hasFilter ? 'Try clearing the search or filter' : 'Add staff using Create Account',
          style: const TextStyle(fontSize: 12, color: _C.muted), textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _EmpRow extends StatelessWidget {
  final EmployeeModel emp;
  final bool isLast, isSelf, canDel, canTog;
  final VoidCallback onTap, onToggle, onDelete;
  const _EmpRow({required this.emp, required this.isLast, required this.isSelf,
      required this.canDel, required this.canTog,
      required this.onTap, required this.onToggle, required this.onDelete});

  Color get rc => _roleColor(emp.role);

  @override
  Widget build(BuildContext context) => Column(children: [
    InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(children: [
          // Avatar
          Stack(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: emp.profilePhoto.isEmpty
                      ? LinearGradient(colors: [rc, rc.withOpacity(.65)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null),
              child: emp.profilePhoto.isNotEmpty
                  ? ClipOval(child: Image.network(emp.profilePhoto, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _empInitials()))
                  : _empInitials(),
            ),
            Positioned(right: 0, bottom: 0,
              child: Container(width: 13, height: 13,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: emp.isActive ? _C.green : _C.muted,
                      border: Border.all(color: _C.white, width: 2)))),
          ]),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name + (You) badge
            Row(children: [
              Flexible(
                child: Text(emp.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isSelf) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _C.royal.withOpacity(.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _C.royal.withOpacity(.25))),
                  child: const Text('You', style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w800, color: _C.royal)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(emp.email, style: const TextStyle(fontSize: 11, color: _C.muted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              _miniPill('${_roleEmoji(emp.role)} ${emp.role}', rc),
              const SizedBox(width: 6),
              _miniPill(emp.isActive ? '● Active' : '○ Inactive',
                  emp.isActive ? _C.green : _C.muted),
            ]),
          ])),
          // Action buttons — hidden for self
          if (!isSelf)
            Column(children: [
              if (canTog)
                _ABtn(
                  icon: emp.isActive ? Icons.person_off_outlined : Icons.person_outlined,
                  color: emp.isActive ? _C.amber : _C.green,
                  onTap: onToggle,
                ),
              if (canDel) ...[
                const SizedBox(height: 6),
                _ABtn(icon: Icons.delete_outline_rounded, color: _C.rose, onTap: onDelete),
              ],
            ]),
        ]),
      ),
    ),
    if (!isLast) Container(height: 1, color: _C.line, margin: const EdgeInsets.only(left: 74)),
  ]);

  Widget _empInitials() => Center(child: Text(emp.initials,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)));

  Widget _miniPill(String lbl, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(.09), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(.22))),
    child: Text(lbl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );
}

class _ABtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _ABtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 15, color: color)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EmpSheet extends StatelessWidget {
  final EmployeeModel emp;
  final EmployeeManagementProvider prov;
  final bool isSelf;
  final VoidCallback onToggle, onDelete;
  const _EmpSheet({required this.emp, required this.prov, required this.isSelf,
      required this.onToggle, required this.onDelete});

  Color get rc => _roleColor(emp.role);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: _C.line, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        // Avatar
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: emp.profilePhoto.isEmpty
                  ? LinearGradient(colors: [rc, rc.withOpacity(.65)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              boxShadow: [BoxShadow(color: rc.withOpacity(.30), blurRadius: 16, offset: const Offset(0, 6))]),
          child: emp.profilePhoto.isNotEmpty
              ? ClipOval(child: Image.network(emp.profilePhoto, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avi()))
              : _avi(),
        ),
        const SizedBox(height: 14),
        // Name + (You) tag
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emp.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.ink)),
          if (isSelf) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _C.royal.withOpacity(.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.royal.withOpacity(.25))),
              child: const Text('You', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w800, color: _C.royal)),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Text(emp.email, style: const TextStyle(fontSize: 13, color: _C.muted)),
        const SizedBox(height: 12),
        // Badges
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _sheetBadge('${_roleEmoji(emp.role)} ${emp.role}', rc),
          const SizedBox(width: 8),
          _sheetBadge(emp.isActive ? '● Active' : '○ Inactive', emp.isActive ? _C.green : _C.muted),
        ]),
        const SizedBox(height: 20),
        // Details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            _SDRow(Icons.phone_outlined,        'Phone',    emp.phone.isEmpty ? 'Not provided' : emp.phone),
            _SDRow(Icons.business_outlined,     'Business', emp.businessName.isEmpty ? 'Not assigned' : emp.businessName),
            _SDRow(Icons.person_add_outlined,   'Added By', emp.createdByName.isEmpty ? 'Unknown' : emp.createdByName),
            _SDRow(Icons.calendar_today_outlined,'Joined',  emp.joinedLabel, last: true),
          ]),
        ),
        const SizedBox(height: 20),
        // Action buttons — only shown for other members, not self
        if (!isSelf && (prov.canToggle(emp) || prov.canDelete(emp)))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(children: [
              if (prov.canToggle(emp))
                Expanded(child: OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(emp.isActive ? Icons.person_off_outlined : Icons.person_outlined, size: 16),
                  label: Text(emp.isActive ? 'Deactivate' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: emp.isActive ? _C.amber : _C.green,
                    side: BorderSide(color: emp.isActive ? _C.amber : _C.green, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                )),
              if (prov.canToggle(emp) && prov.canDelete(emp)) const SizedBox(width: 10),
              if (prov.canDelete(emp))
                Expanded(child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.rose, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                )),
            ]),
          )
        else
          const SizedBox(height: 8),
      ]),
    );
  }

  Widget _avi() => Center(child: Text(emp.initials,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)));

  Widget _sheetBadge(String lbl, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: c.withOpacity(.09), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.25))),
    child: Text(lbl, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
  );
}

class _SDRow extends StatelessWidget {
  final IconData icon; final String lbl, val; final bool last;
  const _SDRow(this.icon, this.lbl, this.val, {this.last = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 34, height: 34,
            decoration: BoxDecoration(color: _C.royalBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: _C.royal)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lbl.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
              color: _C.muted, letterSpacing: .5)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
        ])),
      ]),
    ),
    if (!last) Container(height: 1, color: _C.line),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _Dialog extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, msg, confirmLabel; final Color confirmColor;
  const _Dialog({required this.icon, required this.iconColor, required this.title,
      required this.msg, required this.confirmLabel, required this.confirmColor});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 40, offset: const Offset(0, 12))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
            decoration: BoxDecoration(color: iconColor.withOpacity(.09), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: iconColor, size: 26)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.ink),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _C.muted, height: 1.4)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                side: const BorderSide(color: _C.line, width: 1.5)),
            child: const Text('Cancel', style: TextStyle(color: _C.body, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsGrid extends StatelessWidget {
  final UserProfile p; final ProfileProvider prov;
  const _ActionsGrid({required this.p, required this.prov});
  bool get _canCreate {
    final r = p.role.label.toLowerCase();
    return r == 'owner' || r == 'admin' || r == 'manager' || r == 'system';
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Expanded(child: _ACard(
        icon: Icons.person_add_alt_1_rounded,
        lbl: 'Create\nAccount', sub: _canCreate ? 'Add new staff' : 'No permission',
        c: _canCreate ? _C.royal : _C.muted, disabled: !_canCreate,
        onTap: _canCreate
            ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CreateAccountScreen(
                    businessId: p.businessId, businessName: p.businessName)))
            : null,
      )),
      const SizedBox(width: 12),
      Expanded(child: _ACard(
        icon: Icons.lock_reset_rounded,
        lbl: 'Change\nPassword', sub: 'Update security', c: _C.amber,
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ChangePasswordScreen()))
            .then((_) => prov.loadProfile()),
      )),
    ]),
  );
}

class _ACard extends StatelessWidget {
  final IconData icon; final String lbl, sub; final Color c;
  final VoidCallback? onTap; final bool disabled;
  const _ACard({required this.icon, required this.lbl, required this.sub,
      required this.c, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Opacity(
      opacity: disabled ? .45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(.18)),
            boxShadow: disabled ? [] : [BoxShadow(color: c.withOpacity(.10), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withOpacity(.75)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: disabled ? [] : [BoxShadow(color: c.withOpacity(.30), blurRadius: 8, offset: const Offset(0, 4))]),
              child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(height: 14),
          Text(lbl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _C.ink, height: 1.2)),
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 11, color: _C.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(children: [
            Text(disabled ? 'Restricted' : 'Open',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
            const SizedBox(width: 3),
            Icon(disabled ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded, size: 13, color: c),
          ]),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final UserProfile p; final ProfileProvider prov;
  const _ActivityCard({required this.p, required this.prov});
  @override
  Widget build(BuildContext context) => _Card(child: Column(
    children: p.recentActivity.asMap().entries.map((e) {
      final lg   = e.value;
      final last = e.key == p.recentActivity.length - 1;
      return Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: BoxDecoration(color: _C.royalBg, borderRadius: BorderRadius.circular(11)),
                child: Center(child: Text(lg.icon, style: const TextStyle(fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lg.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
              const SizedBox(height: 2),
              Text(lg.subtitle, style: const TextStyle(fontSize: 11, color: _C.muted)),
            ])),
            Text(prov.activityTimeLabel(lg),
                style: const TextStyle(fontSize: 11, color: _C.muted, fontWeight: FontWeight.w500)),
          ]),
        ),
        if (!last) Container(height: 1, color: _C.line, margin: const EdgeInsets.only(left: 68)),
      ]);
    }).toList(),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIGN OUT
// ─────────────────────────────────────────────────────────────────────────────
class _SignOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: GestureDetector(
      onTap: () => _confirm(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.rose.withOpacity(.22)),
            boxShadow: [BoxShadow(color: _C.rose.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 30, height: 30,
              decoration: BoxDecoration(color: _C.rose.withOpacity(.09), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.logout_rounded, color: _C.rose, size: 15)),
          const SizedBox(width: 10),
          const Text('Sign Out', style: TextStyle(color: _C.rose, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );

  void _confirm(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 40, offset: const Offset(0, 12))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56,
              decoration: BoxDecoration(color: _C.rose.withOpacity(.09), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.logout_rounded, color: _C.rose, size: 26)),
          const SizedBox(height: 16),
          const Text('Sign out?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.ink)),
          const SizedBox(height: 8),
          const Text('You will be signed out of your account.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _C.muted, height: 1.4)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  side: const BorderSide(color: _C.line, width: 1.5)),
              child: const Text('Cancel', style: TextStyle(color: _C.body, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ctx.read<AppAuthenticationProvider>().logout();
                if (ctx.mounted) Navigator.pushAndRemoveUntil(ctx,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _C.rose, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DOT GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF1847C4).withOpacity(.03);
    for (double x = 0; x < size.width; x += 22)
      for (double y = 0; y < size.height; y += 22)
        canvas.drawCircle(Offset(x, y), 1.1, p);
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER
// ─────────────────────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _a = Tween<double>(begin: .5, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  Widget _b({double w = double.infinity, double h = 14, double r = 8}) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(width: w, height: h,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(r),
            color: Color.lerp(const Color(0xFFDDE6F8), const Color(0xFFEEF3FC), _a.value))),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        _b(w: 160, h: 30, r: 8), const SizedBox(height: 7), _b(w: 110, h: 14, r: 6),
        const SizedBox(height: 24), _b(h: 130, r: 22),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _b(h: 78, r: 16)), const SizedBox(width: 8),
          Expanded(child: _b(h: 78, r: 16)), const SizedBox(width: 8),
          Expanded(child: _b(h: 78, r: 16)), const SizedBox(width: 8),
          Expanded(child: _b(h: 78, r: 16))]),
        const SizedBox(height: 26), _b(w: 80, h: 10, r: 4), const SizedBox(height: 10), _b(h: 170, r: 20),
        const SizedBox(height: 22), _b(w: 90, h: 10, r: 4), const SizedBox(height: 10), _b(h: 120, r: 20),
        const SizedBox(height: 22), _b(w: 110, h: 10, r: 4), const SizedBox(height: 10), _b(h: 155, r: 20),
        const SizedBox(height: 22), _b(w: 100, h: 10, r: 4), const SizedBox(height: 10), _b(h: 180, r: 20),
        const SizedBox(height: 22), _b(w: 120, h: 10, r: 4), const SizedBox(height: 10), _b(h: 240, r: 20),
        const SizedBox(height: 22),
        Row(children: [Expanded(child: _b(h: 140, r: 20)), const SizedBox(width: 12), Expanded(child: _b(h: 140, r: 20))]),
      ]),
    ),
  );
}


/*except ur profile in employee sec import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/employee_management_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/screens/change_pwd_screen.dart';
import 'package:pos_app/screens/create_account_screen.dart';
import 'package:pos_app/screens/edit_profile_Screen.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const royal = Color(0xFF1847C4);
  static const royalLt = Color(0xFF3B6FE8);
  static const royalBg = Color(0xFFEBF0FF);
  static const royalBd = Color(0xFFCDD8FB);
  static const ink = Color(0xFF0D1B3E);
  static const body = Color(0xFF3A4A6B);
  static const muted = Color(0xFF8C9AB8);
  static const line = Color(0xFFE4EAF8);
  static const green = Color(0xFF0EA472);
  static const amber = Color(0xFFD97706);
  static const teal = Color(0xFF0891B2);
  static const violet = Color(0xFF7C3AED);
  static const rose = Color(0xFFE11D48);
  static const indigo = Color(0xFF6366F1);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _rev(double v) {
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

String _num(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
    case 'system':
    case 'admin':
      return _C.indigo;
    case 'manager':
      return _C.royal;
    case 'cashier':
      return _C.teal;
    case 'waiter':
    case 'server':
      return _C.green;
    case 'chef':
      return _C.amber;
    default:
      return _C.muted;
  }
}

String _roleEmoji(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
    case 'system':
      return '👑';
    case 'admin':
      return '⚡';
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
      if (!mounted) return;
      context.read<ProfileProvider>().loadProfile();
      context.read<EmployeeManagementProvider>().init();
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
      builder: (_, prov, __) {
        if (prov.isLoading || prov.profile == null) {
          return const Scaffold(backgroundColor: _C.bg, body: _Shimmer());
        }
        return _Body(prov: prov, p: prov.profile!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BODY
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final ProfileProvider prov;
  final UserProfile p;
  const _Body({required this.prov, required this.p});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeManagementProvider>(
      builder: (ctx, emp, __) {
        return Scaffold(
          backgroundColor: _C.bg,
          body: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _Dots())),
              SafeArea(
                child: RefreshIndicator(
                  color: _C.royal,
                  backgroundColor: _C.white,
                  onRefresh: () async {
                    await prov.loadProfile();
                    if (emp.canManage) await emp.refresh();
                  },
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      _sliver(_TopBar(onEdit: () => _goEdit(ctx))),
                      _sliver(_IdentityCard(p: p, onShift: prov.toggleShift)),
                      _sliver(_TodayStrip(prov: prov)),
                      _sliver(const _SHead('PERSONAL INFO')),
                      _sliver(_PersonalCard(p: p)),
                      _sliver(const _SHead('ORGANISATION')),
                      _sliver(_OrgCard(p: p, prov: prov)),
                      _sliver(const _SHead('ACCOUNT TIMELINE')),
                      _sliver(_TimelineCard(p: p)),
                      _sliver(const _SHead('PERFORMANCE SUMMARY')),
                      _sliver(_WeekMonthCard(prov: prov)),
                      _sliver(const _SHead('ALL-TIME PERFORMANCE')),
                      _sliver(_AllTimeCard(p: p, prov: prov)),
                      // ── Employee section: only for privileged roles ──────────
                      if (emp.canManage) ...[
                        _sliver(const _SHead('TEAM MEMBERS')),
                        _sliver(_TeamSection(emp: emp, p: p)),
                      ],
                      _sliver(const _SHead('QUICK ACTIONS')),
                      _sliver(_ActionsGrid(p: p, prov: prov)),
                      if (p.recentActivity.isNotEmpty) ...[
                        _sliver(const _SHead('RECENT ACTIVITY')),
                        _sliver(_ActivityCard(p: p, prov: prov)),
                      ],
                      _sliver(_SignOut()),
                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    ],
                  ),
                ),
              ),
              if (prov.isLoading || emp.isDeleting)
                Container(
                  color: Colors.white54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: _C.royal),
                        if (emp.isDeleting) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Removing member…',
                            style: TextStyle(
                              color: _C.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  SliverToBoxAdapter _sliver(Widget w) => SliverToBoxAdapter(child: w);

  void _goEdit(BuildContext ctx) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const EditProfileScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    ).then((_) => prov.loadProfile());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onEdit;
  const _TopBar({required this.onEdit});

  @override
  Widget build(BuildContext context) => Padding(
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
                color: _C.ink,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Account overview',
              style: TextStyle(
                fontSize: 13,
                color: _C.muted,
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
              color: _C.royalBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.royalBd),
            ),
            child: const Icon(Icons.edit_outlined, color: _C.royal, size: 20),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final UserProfile p;
  final VoidCallback onShift;
  const _IdentityCard({required this.p, required this.onShift});

  @override
  Widget build(BuildContext context) => _Card(
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
                    color: _C.ink,
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
                    color: _C.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (p.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.phone,
                    style: const TextStyle(fontSize: 12, color: _C.muted),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      '${p.role.emoji} ${p.role.label}',
                      p.role.color.withOpacity(.10),
                      p.role.color.withOpacity(.25),
                      p.role.color,
                    ),
                    _Pill(
                      p.isActive ? '● Active' : '○ Inactive',
                      p.isActive
                          ? _C.green.withOpacity(.09)
                          : _C.muted.withOpacity(.08),
                      p.isActive
                          ? _C.green.withOpacity(.25)
                          : _C.muted.withOpacity(.15),
                      p.isActive ? _C.green : _C.muted,
                    ),
                    GestureDetector(
                      onTap: onShift,
                      child: _Pill(
                        p.isOnShift ? '🕐 On Shift' : '⏸ Off Shift',
                        p.isOnShift ? _C.royalBg : _C.line,
                        p.isOnShift ? _C.royalBd : _C.line,
                        p.isOnShift ? _C.royal : _C.muted,
                        trail: Icons.swap_horiz_rounded,
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

// ─────────────────────────────────────────────────────────────────────────────
//  AVATAR
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String initials, photoUrl;
  final Color roleColor;
  final bool isActive;
  const _Avatar({
    required this.initials,
    required this.roleColor,
    required this.isActive,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photoUrl.isEmpty
              ? LinearGradient(
                  colors: [roleColor, roleColor.withOpacity(.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: roleColor.withOpacity(.30),
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
                  errorBuilder: (_, __, ___) => _txt(),
                ),
              )
            : _txt(),
      ),
      Positioned(
        right: 1,
        bottom: 1,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _C.green : _C.muted,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
        ),
      ),
    ],
  );

  Widget _txt() => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PILL
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color bg, border, text;
  final IconData? trail;
  const _Pill(this.label, this.bg, this.border, this.text, {this.trail});

  @override
  Widget build(BuildContext context) => Container(
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
            color: text,
          ),
        ),
        if (trail != null) ...[
          const SizedBox(width: 3),
          Icon(trail, size: 11, color: text),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TODAY STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _TodayStrip extends StatelessWidget {
  final ProfileProvider prov;
  const _TodayStrip({required this.prov});

  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats;
    final ld = prov.statsLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text(
                  "TODAY'S SUMMARY",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _C.muted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                if (ld)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _C.royal,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              _SBox(
                ld ? '–' : '${s.ordersTodayCount}',
                'Orders\nToday',
                _C.royal,
              ),
              const SizedBox(width: 8),
              _SBox(
                ld ? '–' : '${s.tablesTodayCount}',
                'Tables\nToday',
                _C.teal,
              ),
              const SizedBox(width: 8),
              _SBox(
                ld ? '–' : _rev(s.revenueTodayAmount),
                'Revenue\nToday',
                _C.green,
              ),
              const SizedBox(width: 8),
              _SBox(
                ld ? '–' : '${s.shiftsThisWeek}/6',
                'Shifts\nWeek',
                _C.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SBox extends StatelessWidget {
  final String v, lbl;
  final Color c;
  const _SBox(this.v, this.lbl, this.c);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: c, width: 2.5)),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: c,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lbl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: _C.muted,
              height: 1.3,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEAD
// ─────────────────────────────────────────────────────────────────────────────
class _SHead extends StatelessWidget {
  final String t;
  const _SHead(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _C.muted,
        letterSpacing: 2.0,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _Card({
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _C.line),
      boxShadow: [
        BoxShadow(
          color: _C.royal.withOpacity(.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FIELD ROW
// ─────────────────────────────────────────────────────────────────────────────
class _FRow extends StatelessWidget {
  final String lbl, val;
  final IconData icon;
  final Color iconC;
  final bool last;
  final Widget? trail;
  const _FRow({
    required this.lbl,
    required this.val,
    required this.icon,
    required this.iconC,
    this.last = false,
    this.trail,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconC.withOpacity(.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconC),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lbl,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _C.muted,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    val.isEmpty ? '—' : val,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (trail != null) trail!,
          ],
        ),
      ),
      if (!last)
        Container(
          height: 1,
          color: _C.line,
          margin: const EdgeInsets.only(left: 69),
        ),
    ],
  );
}

class _Bdg extends StatelessWidget {
  final String lbl;
  final Color c;
  const _Bdg(this.lbl, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withOpacity(.22)),
    ),
    child: Text(
      lbl,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c),
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
    return _Card(
      child: Column(
        children: [
          _FRow(
            lbl: 'FULL NAME',
            val: p.name,
            icon: Icons.badge_outlined,
            iconC: _C.royal,
          ),
          _FRow(
            lbl: 'EMAIL ADDRESS',
            val: p.email,
            icon: Icons.alternate_email_rounded,
            iconC: _C.violet,
            trail: _Bdg('Verified', _C.green),
          ),
          _FRow(
            lbl: 'PHONE NUMBER',
            val: p.phone.isEmpty ? 'Not added' : p.phone,
            icon: Icons.phone_outlined,
            iconC: _C.teal,
          ),
          _FRow(
            lbl: 'USER ID (UID)',
            val: shortUid,
            icon: Icons.fingerprint_rounded,
            iconC: _C.muted,
            last: true,
            trail: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: p.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('UID copied'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _C.royalBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.copy_outlined,
                  size: 14,
                  color: _C.royal,
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
//  ORG CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OrgCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _OrgCard({required this.p, required this.prov});
  @override
  Widget build(BuildContext context) {
    final isSelf = p.createdBy == p.id;
    final cName = prov.creatorName.isNotEmpty
        ? (isSelf ? '${prov.creatorName} (You)' : prov.creatorName)
        : (p.createdByName.isNotEmpty
              ? (isSelf ? '${p.createdByName} (You)' : p.createdByName)
              : '—');
    final cRole = prov.creatorRole.isNotEmpty
        ? prov.creatorRole
        : p.createdByRole;

    return _Card(
      child: Column(
        children: [
          _FRow(
            lbl: 'BUSINESS NAME',
            val: p.businessName.isEmpty ? 'Not assigned' : p.businessName,
            icon: Icons.storefront_outlined,
            iconC: _C.royal,
            trail: _Bdg(
              p.isActive ? 'Active' : 'Inactive',
              p.isActive ? _C.green : _C.muted,
            ),
          ),
          _FRow(
            lbl: 'BUSINESS ID',
            val: p.businessId.isEmpty ? 'Not assigned' : p.businessId,
            icon: Icons.corporate_fare_rounded,
            iconC: _C.teal,
          ),
          // Created by row
          Column(
            children: [
              Container(
                height: 1,
                color: _C.line,
                margin: const EdgeInsets.only(left: 69),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.violet.withOpacity(.09),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        size: 18,
                        color: _C.violet,
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
                              color: _C.muted,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cRole.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(cRole).withOpacity(.09),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _roleColor(cRole).withOpacity(.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _roleEmoji(cRole),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cRole,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _roleColor(cRole),
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
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        children: [
          _TRow(
            _C.royal,
            'ACCOUNT CREATED',
            p.formattedJoinDate,
            '${p.tenureLabel} member',
            _C.royal,
          ),
          _TLine(),
          _TRow(
            _C.amber,
            'PASSWORD LAST CHANGED',
            p.passwordLastChangedLabel ?? 'Not updated yet',
            p.passwordLastChanged != null ? 'Updated' : 'Pending',
            p.passwordLastChanged != null ? _C.green : _C.amber,
          ),
          _TLine(),
          _TRow(
            _C.green,
            'PROFILE LAST UPDATED',
            p.updatedAtLabel ?? 'No updates yet',
            'Auto-saved',
            _C.teal,
            last: true,
          ),
        ],
      ),
    ),
  );
}

class _TRow extends StatelessWidget {
  final Color dot;
  final String lbl, val, badge;
  final Color bdgC;
  final bool last;
  const _TRow(
    this.dot,
    this.lbl,
    this.val,
    this.badge,
    this.bdgC, {
    this.last = false,
  });
  @override
  Widget build(BuildContext context) => Row(
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
              color: dot,
              boxShadow: [
                BoxShadow(
                  color: dot.withOpacity(.45),
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
                  lbl,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.muted,
                    letterSpacing: .5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bdgC.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: bdgC,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _C.ink,
              ),
            ),
            if (!last) const SizedBox(height: 18),
          ],
        ),
      ),
    ],
  );
}

class _TLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 1.5,
        height: 22,
        margin: const EdgeInsets.only(left: 5.25),
        color: _C.line,
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PERF BLOCK
// ─────────────────────────────────────────────────────────────────────────────
class _PBlk extends StatelessWidget {
  final String emoji, lbl, val;
  final Color c;
  const _PBlk({
    required this.emoji,
    required this.lbl,
    required this.val,
    required this.c,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(.14)),
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
                  lbl,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _C.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: c,
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

// ─────────────────────────────────────────────────────────────────────────────
//  WEEK/MONTH PERFORMANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WeekMonthCard extends StatefulWidget {
  final ProfileProvider prov;
  const _WeekMonthCard({required this.prov});
  @override
  State<_WeekMonthCard> createState() => _WeekMonthCardState();
}

class _WeekMonthCardState extends State<_WeekMonthCard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final s = widget.prov.perfStats;
    final ld = widget.prov.statsLoading;
    final wk = _tab == 0;
    return _Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _C.royal.withOpacity(.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _C.royal,
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
                      color: _C.ink,
                    ),
                  ),
                ),
                if (ld)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _C.royal,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: _C.royalBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TabBtn(
                        'Week',
                        _tab == 0,
                        () => setState(() => _tab = 0),
                      ),
                      _TabBtn(
                        'Month',
                        _tab == 1,
                        () => setState(() => _tab = 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _PBlk(
                      emoji: '🧾',
                      lbl: 'Total Orders\nHandled',
                      val: ld
                          ? '–'
                          : '${wk ? s.ordersWeekCount : s.ordersMonthCount}',
                      c: _C.royal,
                    ),
                    const SizedBox(width: 10),
                    _PBlk(
                      emoji: '💵',
                      lbl: 'Total Revenue\nGenerated',
                      val: ld
                          ? '–'
                          : _rev(
                              wk ? s.revenueWeekAmount : s.revenueMonthAmount,
                            ),
                      c: _C.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PBlk(
                      emoji: '🪑',
                      lbl: 'Tables\nManaged',
                      val: ld
                          ? '–'
                          : '${wk ? s.tablesWeekCount : s.tablesMonthCount}',
                      c: _C.teal,
                    ),
                    const SizedBox(width: 10),
                    _PBlk(
                      emoji: '📊',
                      lbl: 'Avg Order\nValue',
                      val: ld
                          ? '–'
                          : _rev(
                              wk ? s.avgOrderValueWeek : s.avgOrderValueMonth,
                            ),
                      c: _C.amber,
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

class _TabBtn extends StatelessWidget {
  final String lbl;
  final bool on;
  final VoidCallback onTap;
  const _TabBtn(this.lbl, this.on, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: on ? _C.royal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lbl,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: on ? Colors.white : _C.royal,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALL-TIME CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AllTimeCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _AllTimeCard({required this.p, required this.prov});
  String get _tenure {
    final d = DateTime.now().difference(p.joinedDate);
    final y = d.inDays ~/ 365, mo = (d.inDays % 365) ~/ 30, dy = d.inDays % 30;
    if (y > 0) return '$y yr ${mo}mo';
    if (mo > 0) return '${mo}mo ${dy}d';
    return '${d.inDays}d';
  }

  int get _weeks =>
      (DateTime.now().difference(p.joinedDate).inDays / 7).floor();
  @override
  Widget build(BuildContext context) {
    final s = prov.perfStats;
    final ld = prov.statsLoading;
    return _Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.royal, _C.royalLt],
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
                    ),
                  ),
                ),
                if (ld)
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
                    color: Colors.white.withOpacity(.18),
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _PBlk(
                      emoji: '🧾',
                      lbl: 'Total Orders\nHandled',
                      val: ld ? '–' : _num(s.ordersAllTimeCount),
                      c: _C.royal,
                    ),
                    const SizedBox(width: 10),
                    _PBlk(
                      emoji: '💰',
                      lbl: 'Total Revenue\nGenerated',
                      val: ld ? '–' : _rev(s.revenueAllTimeAmount),
                      c: _C.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PBlk(
                      emoji: '🪑',
                      lbl: 'Tables\nManaged',
                      val: ld ? '–' : _num(s.tablesAllTimeCount),
                      c: _C.teal,
                    ),
                    const SizedBox(width: 10),
                    _PBlk(
                      emoji: '📅',
                      lbl: 'Weeks\nWorked',
                      val: '$_weeks',
                      c: _C.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.royal.withOpacity(.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.royal.withOpacity(.14)),
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
                                color: _C.muted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tenure,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _C.royal,
                                letterSpacing: -.3,
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
                          color: _C.green.withOpacity(.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _C.green.withOpacity(.25)),
                        ),
                        child: Text(
                          p.tenureLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _C.green,
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
//  TEAM SECTION  (shown only for owner / system / admin / manager)
// ─────────────────────────────────────────────────────────────────────────────
class _TeamSection extends StatefulWidget {
  final EmployeeManagementProvider emp;
  final UserProfile p;
  const _TeamSection({required this.emp, required this.p});
  @override
  State<_TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<_TeamSection> {
  final _searchCtrl = TextEditingController();
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final list = emp.employees;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Summary chips ──────────────────────────────────────────────────
          _TeamSummary(
            total: emp.totalCount,
            active: emp.activeCount,
            inactive: emp.inactiveCount,
          ),
          const SizedBox(height: 12),

          // ── Search ─────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: _C.royal.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: emp.setSearch,
              style: const TextStyle(
                fontSize: 13,
                color: _C.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, email or role…',
                hintStyle: const TextStyle(fontSize: 13, color: _C.muted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _C.muted,
                  size: 20,
                ),
                suffixIcon: emp.searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          emp.setSearch('');
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          color: _C.muted,
                          size: 18,
                        ),
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

          // ── Role filter chips ──────────────────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: emp.availableRoles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = emp.availableRoles[i];
                final sel = emp.roleFilter == r;
                final rc = r == 'All' ? _C.royal : _roleColor(r);
                return GestureDetector(
                  onTap: () => emp.setRoleFilter(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? rc : _C.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? rc : _C.line, width: 1.2),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _C.muted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ────────────────────────────────────────────────────────
          if (emp.isLoading)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: _C.royal),
              ),
            )
          else if (list.isEmpty)
            _TeamEmpty(
              hasFilter: emp.searchQuery.isNotEmpty || emp.roleFilter != 'All',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line),
                boxShadow: [
                  BoxShadow(
                    color: _C.royal.withOpacity(.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: list
                    .asMap()
                    .entries
                    .map(
                      (e) => _EmpRow(
                        emp: e.value,
                        isLast: e.key == list.length - 1,
                        canDel: widget.emp.canDelete(e.value),
                        canTog: widget.emp.canToggle(e.value),
                        onTap: () => _detail(e.value),
                        onToggle: () => _confirmToggle(e.value),
                        onDelete: () => _confirmDelete(e.value),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Detail sheet ───────────────────────────────────────────────────────────
  void _detail(EmployeeModel e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EmpSheet(
        emp: e,
        prov: widget.emp,
        onToggle: () {
          Navigator.pop(context);
          _confirmToggle(e);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(e);
        },
      ),
    );
  }

  // ── Confirm toggle ─────────────────────────────────────────────────────────
  Future<void> _confirmToggle(EmployeeModel e) async {
    final action = e.isActive ? 'Deactivate' : 'Activate';
    final color = e.isActive ? _C.amber : _C.green;
    final ok = await _confirm(
      icon: e.isActive ? Icons.person_off_outlined : Icons.person_outlined,
      iconColor: color,
      title: '$action ${e.name}?',
      msg: e.isActive
          ? '${e.name} will lose system access immediately.'
          : '${e.name} will regain system access.',
      confirm: action,
      confirmColor: color,
    );
    if (!ok) return;
    final res = await widget.emp.toggleStatus(e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res
                ? '${e.name} ${e.isActive ? 'deactivated' : 'activated'}'
                : 'Permission denied',
          ),
          backgroundColor: res ? _C.green : _C.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── Confirm delete ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete(EmployeeModel e) async {
    final ok = await _confirm(
      icon: Icons.delete_forever_rounded,
      iconColor: _C.rose,
      title: 'Remove ${e.name}?',
      msg:
          'This will permanently remove ${e.name} from the company. '
          'They will lose all access immediately. This cannot be undone.',
      confirm: 'Remove',
      confirmColor: _C.rose,
      danger: true,
    );
    if (!ok) return;
    final res = await widget.emp.deleteEmployee(e);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res ? '${e.name} has been removed' : 'Failed to remove member',
          ),
          backgroundColor: res ? _C.green : _C.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<bool> _confirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String msg,
    required String confirm,
    required Color confirmColor,
    bool danger = false,
  }) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        msg: msg,
        confirmLabel: confirm,
        confirmColor: confirmColor,
      ),
    );
    return v == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEAM SUMMARY CHIPS
// ─────────────────────────────────────────────────────────────────────────────
class _TeamSummary extends StatelessWidget {
  final int total, active, inactive;
  const _TeamSummary({
    required this.total,
    required this.active,
    required this.inactive,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TSChip('$total', 'Total', _C.royal, _C.royalBg),
      const SizedBox(width: 8),
      _TSChip('$active', 'Active', _C.green, _C.green.withOpacity(.09)),
      const SizedBox(width: 8),
      _TSChip('$inactive', 'Inactive', _C.muted, _C.muted.withOpacity(.09)),
    ],
  );
}

class _TSChip extends StatelessWidget {
  final String val, lbl;
  final Color c, bg;
  const _TSChip(this.val, this.lbl, this.c, this.bg);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.20)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lbl,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _C.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TeamEmpty extends StatelessWidget {
  final bool hasFilter;
  const _TeamEmpty({required this.hasFilter});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.line),
    ),
    child: Column(
      children: [
        const Text('👥', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 10),
        Text(
          hasFilter ? 'No members match your filter' : 'No team members yet',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _C.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasFilter
              ? 'Try clearing the search or filter'
              : 'Add staff using Create Account',
          style: const TextStyle(fontSize: 12, color: _C.muted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _EmpRow extends StatelessWidget {
  final EmployeeModel emp;
  final bool isLast, canDel, canTog;
  final VoidCallback onTap, onToggle, onDelete;
  const _EmpRow({
    required this.emp,
    required this.isLast,
    required this.canDel,
    required this.canTog,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  Color get rc => _roleColor(emp.role);

  @override
  Widget build(BuildContext context) {
    log('Building row for ${emp.name} (active: ${emp.isActive})');
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: emp.profilePhoto.isEmpty
                            ? LinearGradient(
                                colors: [rc, rc.withOpacity(.65)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                      child: emp.profilePhoto.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                emp.profilePhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _empInitials(),
                              ),
                            )
                          : _empInitials(),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: emp.isActive ? _C.green : _C.muted,
                          border: Border.all(color: _C.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emp.email,
                        style: const TextStyle(fontSize: 11, color: _C.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _miniPill('${_roleEmoji(emp.role)} ${emp.role}', rc),
                          const SizedBox(width: 6),
                          _miniPill(
                            emp.isActive ? '● Active' : '○ Inactive',
                            emp.isActive ? _C.green : _C.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  children: [
                    if (canTog)
                      _ABtn(
                        icon: emp.isActive
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                        color: emp.isActive ? _C.amber : _C.green,
                        onTap: onToggle,
                      ),
                    if (canDel) ...[
                      const SizedBox(height: 6),
                      _ABtn(
                        icon: Icons.delete_outline_rounded,
                        color: _C.rose,
                        onTap: onDelete,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            color: _C.line,
            margin: const EdgeInsets.only(left: 74),
          ),
      ],
    );
  }

  Widget _empInitials() => Center(
    child: Text(
      emp.initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 16,
      ),
    ),
  );

  Widget _miniPill(String lbl, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(.09),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withOpacity(.22)),
    ),
    child: Text(
      lbl,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
    ),
  );
}

class _ABtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ABtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EmpSheet extends StatelessWidget {
  final EmployeeModel emp;
  final EmployeeManagementProvider prov;
  final VoidCallback onToggle, onDelete;
  const _EmpSheet({
    required this.emp,
    required this.prov,
    required this.onToggle,
    required this.onDelete,
  });

  Color get rc => _roleColor(emp.role);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _C.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: emp.profilePhoto.isEmpty
                  ? LinearGradient(
                      colors: [rc, rc.withOpacity(.65)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: rc.withOpacity(.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: emp.profilePhoto.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      emp.profilePhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avi(),
                    ),
                  )
                : _avi(),
          ),
          const SizedBox(height: 14),
          Text(
            emp.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            emp.email,
            style: const TextStyle(fontSize: 13, color: _C.muted),
          ),
          const SizedBox(height: 12),
          // Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _sheetBadge('${_roleEmoji(emp.role)} ${emp.role}', rc),
              const SizedBox(width: 8),
              _sheetBadge(
                emp.isActive ? '● Active' : '○ Inactive',
                emp.isActive ? _C.green : _C.muted,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _SDRow(
                  Icons.phone_outlined,
                  'Phone',
                  emp.phone.isEmpty ? 'Not provided' : emp.phone,
                ),
                _SDRow(
                  Icons.business_outlined,
                  'Business',
                  emp.businessName.isEmpty ? 'Not assigned' : emp.businessName,
                ),
                _SDRow(
                  Icons.person_add_outlined,
                  'Added By',
                  emp.createdByName.isEmpty ? 'Unknown' : emp.createdByName,
                ),
                _SDRow(
                  Icons.calendar_today_outlined,
                  'Joined',
                  emp.joinedLabel,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(
              children: [
                if (prov.canToggle(emp))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: Icon(
                        emp.isActive
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                        size: 16,
                      ),
                      label: Text(emp.isActive ? 'Deactivate' : 'Activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: emp.isActive ? _C.amber : _C.green,
                        side: BorderSide(
                          color: emp.isActive ? _C.amber : _C.green,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                if (prov.canToggle(emp) && prov.canDelete(emp))
                  const SizedBox(width: 10),
                if (prov.canDelete(emp))
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.rose,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avi() => Center(
    child: Text(
      emp.initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _sheetBadge(String lbl, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(.09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(.25)),
    ),
    child: Text(
      lbl,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
    ),
  );
}

class _SDRow extends StatelessWidget {
  final IconData icon;
  final String lbl, val;
  final bool last;
  const _SDRow(this.icon, this.lbl, this.val, {this.last = false});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _C.royalBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: _C.royal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lbl.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: _C.muted,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    val,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!last) Container(height: 1, color: _C.line),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _Dialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, msg, confirmLabel;
  final Color confirmColor;
  const _Dialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.msg,
    required this.confirmLabel,
    required this.confirmColor,
  });
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
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
              color: iconColor.withOpacity(.09),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _C.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _C.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    side: const BorderSide(color: _C.line, width: 1.5),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _C.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK ACTIONS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsGrid extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _ActionsGrid({required this.p, required this.prov});
  bool get _canCreate {
    final r = p.role.label.toLowerCase();
    return r == 'owner' || r == 'admin' || r == 'manager' || r == 'system';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: _ACard(
            icon: Icons.person_add_alt_1_rounded,
            lbl: 'Create\nAccount',
            sub: _canCreate ? 'Add new staff' : 'No permission',
            c: _canCreate ? _C.royal : _C.muted,
            disabled: !_canCreate,
            onTap: _canCreate
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
          child: _ACard(
            icon: Icons.lock_reset_rounded,
            lbl: 'Change\nPassword',
            sub: 'Update security',
            c: _C.amber,
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

class _ACard extends StatelessWidget {
  final IconData icon;
  final String lbl, sub;
  final Color c;
  final VoidCallback? onTap;
  final bool disabled;
  const _ACard({
    required this.icon,
    required this.lbl,
    required this.sub,
    required this.c,
    required this.onTap,
    this.disabled = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Opacity(
      opacity: disabled ? .45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(.18)),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: c.withOpacity(.10),
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
                  colors: [c, c.withOpacity(.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: disabled
                    ? []
                    : [
                        BoxShadow(
                          color: c.withOpacity(.30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              lbl,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _C.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: _C.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  disabled ? 'Restricted' : 'Open',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_rounded,
                  size: 13,
                  color: c,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final UserProfile p;
  final ProfileProvider prov;
  const _ActivityCard({required this.p, required this.prov});
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      children: p.recentActivity.asMap().entries.map((e) {
        final lg = e.value;
        final last = e.key == p.recentActivity.length - 1;
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
                      color: _C.royalBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        lg.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lg.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _C.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lg.subtitle,
                          style: const TextStyle(fontSize: 11, color: _C.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    prov.activityTimeLabel(lg),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!last)
              Container(
                height: 1,
                color: _C.line,
                margin: const EdgeInsets.only(left: 68),
              ),
          ],
        );
      }).toList(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIGN OUT
// ─────────────────────────────────────────────────────────────────────────────
class _SignOut extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: GestureDetector(
      onTap: () => _confirm(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.rose.withOpacity(.22)),
          boxShadow: [
            BoxShadow(
              color: _C.rose.withOpacity(.06),
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
                color: _C.rose.withOpacity(.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.logout_rounded, color: _C.rose, size: 15),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sign Out',
              style: TextStyle(
                color: _C.rose,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _confirm(BuildContext ctx) => showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
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
                color: _C.rose.withOpacity(.09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.logout_rounded, color: _C.rose, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _C.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be signed out of your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _C.muted, height: 1.4),
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
                      side: const BorderSide(color: _C.line, width: 1.5),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _C.body,
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
                      if (ctx.mounted)
                        Navigator.pushAndRemoveUntil(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (r) => false,
                        );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.rose,
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

// ─────────────────────────────────────────────────────────────────────────────
//  DOT GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF1847C4).withOpacity(.03);
    for (double x = 0; x < size.width; x += 22)
      for (double y = 0; y < size.height; y += 22)
        canvas.drawCircle(Offset(x, y), 1.1, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER
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
      begin: .5,
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
  Widget build(BuildContext context) => SafeArea(
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




*/
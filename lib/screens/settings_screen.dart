import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const SettingsScreen(),
  );
}

// ─── TOKENS ──────────────────────────────────────────────────────────────────
class T {
  // Warm cream base
  static const bg = Color(0xFFF7F3EE);
  static const bgAlt = Color(0xFFEFEAE2);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE8E2D9);

  // Accent palette — terracotta, sage, sky, plum, gold
  static const terra = Color(0xFFD4663A);
  static const terraLt = Color(0xFFFAEDE6);
  static const sage = Color(0xFF5C8E6E);
  static const sageLt = Color(0xFFE4F0E9);
  static const sky = Color(0xFF3A7BD4);
  static const skyLt = Color(0xFFE4EDFA);
  static const plum = Color(0xFF8B4DA8);
  static const plumLt = Color(0xFFF3E8FA);
  static const gold = Color(0xFFBF8A2E);
  static const goldLt = Color(0xFFFAF2E0);

  // Text
  static const txtHi = Color(0xFF1A1612);
  static const txtMid = Color(0xFF6B6157);
  static const txtLow = Color(0xFFAEA59B);
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  // Toggle states
  bool _pushNotif = true;
  bool _orderAlerts = true;
  bool _emailNotif = false;
  bool _promoEmail = false;
  bool _sound = true;
  bool _vibration = false;
  bool _orderBell = true;
  bool _cloudBackup = true;
  bool _autoLock = true;
  String _language = 'English';
  String _currency = 'INR ₹';
  String _dateFormat = 'DD/MM/YYYY';

  late final AnimationController _entryCtrl;
  late final List<Animation<double>> _fadeAnims;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _fadeAnims = List.generate(
      12,
      (i) => CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(
          (i * 0.07).clamp(0, 1.0),
          ((i * 0.07) + 0.5).clamp(0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Widget _slide(int i, Widget child) => FadeTransition(
    opacity: _fadeAnims[i],
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(_fadeAnims[i]),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Artistic Header ────────────────────────────────────────────────
          SliverToBoxAdapter(child: _slide(0, const _ArtHeader())),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Notification Section ───────────────────────────────────
                _slide(
                  1,
                  _ChapterLabel(
                    number: '01',
                    label: 'Notifications',
                    accent: T.terra,
                  ),
                ),
                const SizedBox(height: 12),
                _slide(
                  2,
                  _BentoGrid(
                    children: [
                      _BentoToggle(
                        icon: Icons.notifications_active_rounded,
                        label: 'Push',
                        sublabel: 'Live alerts',
                        color: T.terra,
                        bgColor: T.terraLt,
                        value: _pushNotif,
                        onChanged: (v) => setState(() => _pushNotif = v),
                      ),
                      _BentoToggle(
                        icon: Icons.receipt_long_rounded,
                        label: 'Orders',
                        sublabel: 'New pings',
                        color: T.gold,
                        bgColor: T.goldLt,
                        value: _orderAlerts,
                        onChanged: (v) => setState(() => _orderAlerts = v),
                      ),
                      _BentoToggle(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        sublabel: 'Reports',
                        color: T.sky,
                        bgColor: T.skyLt,
                        value: _emailNotif,
                        onChanged: (v) => setState(() => _emailNotif = v),
                      ),
                      _BentoToggle(
                        icon: Icons.local_offer_rounded,
                        label: 'Promos',
                        sublabel: 'Offers',
                        color: T.plum,
                        bgColor: T.plumLt,
                        value: _promoEmail,
                        onChanged: (v) => setState(() => _promoEmail = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Sound Section ──────────────────────────────────────────
                _slide(
                  3,
                  _ChapterLabel(
                    number: '02',
                    label: 'Sound & Feel',
                    accent: T.plum,
                  ),
                ),
                const SizedBox(height: 12),
                _slide(
                  4,
                  _StripCard(
                    children: [
                      _StripToggle(
                        icon: Icons.volume_up_rounded,
                        label: 'Sound Effects',
                        sub: 'Tap & action audio',
                        color: T.plum,
                        value: _sound,
                        onChanged: (v) => setState(() => _sound = v),
                      ),
                      _StripToggle(
                        icon: Icons.vibration_rounded,
                        label: 'Vibration',
                        sub: 'Haptic feedback',
                        color: T.sky,
                        value: _vibration,
                        onChanged: (v) => setState(() => _vibration = v),
                      ),
                      _StripToggle(
                        icon: Icons.doorbell_rounded,
                        label: 'Order Bell',
                        sub: 'Distinct order ring',
                        color: T.terra,
                        value: _orderBell,
                        onChanged: (v) => setState(() => _orderBell = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Preferences Section ────────────────────────────────────
                _slide(
                  5,
                  _ChapterLabel(
                    number: '03',
                    label: 'Preferences',
                    accent: T.sage,
                  ),
                ),
                const SizedBox(height: 12),
                _slide(
                  6,
                  _PillSelector(
                    icon: Icons.language_rounded,
                    label: 'Language',
                    color: T.sage,
                    bgColor: T.sageLt,
                    options: const [
                      'English',
                      'Hindi',
                      'Tamil',
                      'Telugu',
                      'Kannada',
                      'Marathi',
                    ],
                    selected: _language,
                    onSelect: (v) => setState(() => _language = v),
                  ),
                ),
                const SizedBox(height: 10),
                _slide(
                  7,
                  Row(
                    children: [
                      Expanded(
                        child: _DropCard(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Currency',
                          value: _currency,
                          color: T.gold,
                          bgColor: T.goldLt,
                          options: const ['INR ₹', 'USD \$', 'EUR €', 'GBP £'],
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DropCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date Format',
                          value: _dateFormat,
                          color: T.sky,
                          bgColor: T.skyLt,
                          options: const [
                            'DD/MM/YYYY',
                            'MM/DD/YYYY',
                            'YYYY-MM-DD',
                          ],
                          onChanged: (v) => setState(() => _dateFormat = v!),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Security Section ───────────────────────────────────────
                _slide(
                  8,
                  _ChapterLabel(number: '04', label: 'Security', accent: T.sky),
                ),
                const SizedBox(height: 12),
                _slide(
                  9,
                  _StripCard(
                    children: [
                      _StripToggle(
                        icon: Icons.lock_clock_rounded,
                        label: 'Auto Lock',
                        sub: 'Lock after 5 min idle',
                        color: T.sky,
                        value: _autoLock,
                        onChanged: (v) => setState(() => _autoLock = v),
                      ),
                      _StripToggle(
                        icon: Icons.cloud_done_rounded,
                        label: 'Cloud Backup',
                        sub: 'Auto-sync data',
                        color: T.sage,
                        value: _cloudBackup,
                        onChanged: (v) => setState(() => _cloudBackup = v),
                      ),
                      _StripNav(
                        icon: Icons.fingerprint_rounded,
                        label: 'Biometric Auth',
                        sub: 'Face / fingerprint',
                        color: T.plum,
                        onTap: () {},
                      ),
                      _StripNav(
                        icon: Icons.password_rounded,
                        label: 'Change Password',
                        sub: 'Update credentials',
                        color: T.terra,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Integrations Section ───────────────────────────────────
                _slide(
                  10,
                  _ChapterLabel(
                    number: '05',
                    label: 'Integrations',
                    accent: T.gold,
                  ),
                ),
                const SizedBox(height: 12),
                _slide(
                  10,
                  _StripCard(
                    children: [
                      _StripNav(
                        icon: Icons.print_rounded,
                        label: 'Printer Settings',
                        sub: 'KOT & receipt printer',
                        color: T.gold,
                        onTap: () {},
                      ),
                      _StripNav(
                        icon: Icons.tablet_android_rounded,
                        label: 'Mobile POS Sync',
                        sub: 'Link tablet devices',
                        color: T.sky,
                        onTap: () {},
                      ),
                      _StripNav(
                        icon: Icons.api_rounded,
                        label: 'API Access',
                        sub: 'Third-party connections',
                        color: T.sage,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Support & Legal ────────────────────────────────────────
                _slide(
                  10,
                  _ChapterLabel(
                    number: '06',
                    label: 'Help & Legal',
                    accent: T.terra,
                  ),
                ),
                const SizedBox(height: 12),
                _slide(
                  11,
                  _IconRowGroup(
                    items: [
                      _IconRowItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help Center',
                        color: T.sky,
                        onTap: () {},
                      ),
                      _IconRowItem(
                        icon: Icons.headset_mic_rounded,
                        label: 'Contact Support',
                        color: T.sage,
                        onTap: () {},
                      ),
                      _IconRowItem(
                        icon: Icons.star_outline_rounded,
                        label: 'Rate the App',
                        color: T.gold,
                        onTap: () {},
                      ),
                      _IconRowItem(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        color: T.txtMid,
                        onTap: () {},
                      ),
                      _IconRowItem(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        color: T.txtMid,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Danger Zone ────────────────────────────────────────────
                _slide(11, _DangerSection()),

                const SizedBox(height: 32),
                _slide(11, const _Footer()),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ARTISTIC HEADER ─────────────────────────────────────────────────────────
class _ArtHeader extends StatelessWidget {
  const _ArtHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Decorative blobs
        Positioned(
          right: -40,
          top: 10,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [T.terra.withOpacity(0.12), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          left: -20,
          top: 60,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [T.sage.withOpacity(0.1), Colors.transparent],
              ),
            ),
          ),
        ),

        // Diagonal accent strip
        Positioned.fill(
          child: ClipRect(
            child: Align(
              alignment: Alignment.topRight,
              child: Transform.rotate(
                angle: -0.18,
                child: Container(
                  width: 220,
                  height: 8,
                  margin: const EdgeInsets.only(top: 80),
                  decoration: BoxDecoration(
                    color: T.terra.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 16,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_BackBtn(), const Spacer(), _VersionChip()]),
              const SizedBox(height: 26),

              // Oversized label
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: T.txtMid,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: T.txtHi,
                          letterSpacing: -2.5,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Stacked accent dots
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          _Dot(T.terra),
                          const SizedBox(width: 5),
                          _Dot(T.sage),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _Dot(T.sky),
                          const SizedBox(width: 5),
                          _Dot(T.gold),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: T.bgAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Manage your app preferences',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: T.txtMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.maybePop(context),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: T.txtMid),
    ),
  );
}

class _VersionChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: T.terraLt,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: T.terra.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: T.terra),
        ),
        const SizedBox(width: 6),
        Text(
          'v3.2.1',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: T.terra,
          ),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(0.4),
    ),
  );
}

// ─── CHAPTER LABEL ────────────────────────────────────────────────────────────
class _ChapterLabel extends StatelessWidget {
  final String number, label;
  final Color accent;
  const _ChapterLabel({
    required this.number,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(width: 8),
      Container(height: 1.5, width: 16, color: accent.withOpacity(0.4)),
      const SizedBox(width: 8),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: T.txtMid,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: T.divider)),
    ],
  );
}

// ─── BENTO GRID (2×2 toggle tiles) ───────────────────────────────────────────
class _BentoGrid extends StatelessWidget {
  final List<Widget> children;
  const _BentoGrid({required this.children});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 10),
          Expanded(child: children[1]),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: children[2]),
          const SizedBox(width: 10),
          Expanded(child: children[3]),
        ],
      ),
    ],
  );
}

class _BentoToggle extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color, bgColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BentoToggle({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: value ? bgColor : T.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: value ? color.withOpacity(0.25) : T.divider),
      boxShadow: [
        if (value)
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        if (!value)
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value ? color.withOpacity(0.18) : T.bgAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: value ? color : T.txtLow, size: 18),
            ),
            const Spacer(),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              trackColor: T.bgAlt,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: value ? T.txtHi : T.txtMid,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11.5,
            color: value ? color : T.txtLow,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ─── STRIP CARD ───────────────────────────────────────────────────────────────
class _StripCard extends StatelessWidget {
  final List<Widget> children;
  const _StripCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: T.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: children
          .asMap()
          .entries
          .map(
            (e) => Column(
              children: [
                e.value,
                if (e.key < children.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 66),
                    color: T.divider,
                  ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _StripToggle extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _StripToggle({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value ? color.withOpacity(0.14) : T.bgAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: value ? color : T.txtLow, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: T.txtHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 11.5, color: T.txtMid)),
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          trackColor: T.bgAlt,
        ),
      ],
    ),
  );
}

class _StripNav extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _StripNav({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(0),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: T.txtHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11.5, color: T.txtMid)),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: T.bgAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right_rounded, color: T.txtMid, size: 16),
          ),
        ],
      ),
    ),
  );
}

// ─── PILL SELECTOR ───────────────────────────────────────────────────────────
class _PillSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PillSelector({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: T.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: T.txtHi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.map((o) {
            final sel = o == selected;
            return GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: sel ? color : T.bgAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: sel ? color : T.divider),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: sel ? Colors.white : T.txtMid,
                    fontSize: 12.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

// ─── DROP CARD ───────────────────────────────────────────────────────────────
class _DropCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color, bgColor;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
            style: TextStyle(
              color: T.txtHi,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            dropdownColor: T.surface,
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o,
                      style: TextStyle(color: T.txtHi, fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

// ─── ICON ROW GROUP ───────────────────────────────────────────────────────────
class _IconRowItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _IconRowItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _IconRowGroup extends StatelessWidget {
  final List<_IconRowItem> items;
  const _IconRowGroup({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: T.divider),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: items
          .asMap()
          .entries
          .map(
            (e) => Column(
              children: [
                InkWell(
                  onTap: e.value.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: e.value.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            e.value.icon,
                            color: e.value.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: T.txtHi,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: T.txtLow,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (e.key < items.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 65),
                    color: T.divider,
                  ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

// ─── DANGER SECTION ──────────────────────────────────────────────────────────
class _DangerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            '07',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 1.5,
            width: 16,
            color: const Color(0xFFEF4444).withOpacity(0.4),
          ),
          const SizedBox(width: 8),
          const Text(
            'DANGER ZONE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: T.txtMid,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: T.divider)),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            _DRow(
              icon: Icons.delete_sweep_rounded,
              label: 'Clear All Data',
              sub: 'Remove cached app data',
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 66),
              color: const Color(0xFFEF4444).withOpacity(0.1),
            ),
            _DRow(
              icon: Icons.restart_alt_rounded,
              label: 'Reset Settings',
              sub: 'Restore defaults',
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 66),
              color: const Color(0xFFEF4444).withOpacity(0.1),
            ),
            _DRow(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              sub: 'Sign out of this account',
              bold: true,
            ),
          ],
        ),
      ),
    ],
  );
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool bold;
  const _DRow({
    required this.icon,
    required this.label,
    required this.sub,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFFEF4444), size: 19),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFB45454),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFEF4444),
            size: 18,
          ),
        ],
      ),
    ),
  );
}

// ─── FOOTER ──────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(height: 1, color: T.divider),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.terraLt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: T.terra,
              size: 22,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'PetPooja',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: T.txtHi,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'v3.2.1 · Build 2025',
        style: TextStyle(fontSize: 11, color: T.txtLow),
      ),
      const SizedBox(height: 6),
      Text(
        'Made with 🔥 for restaurateurs',
        style: TextStyle(fontSize: 11, color: T.txtMid),
      ),
    ],
  );
}

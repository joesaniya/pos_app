import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/screens/create_account_screen.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/screens/widgets/profile_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const _ProfileView(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROOT VIEW
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F3FA),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Hero ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _HeroSection(
                      profile: profile,
                      onToggleShift: provider.toggleShift,
                      onEditTap: () => _showEditSheet(context, provider),
                    ),
                  ),

                  // ── Today's Stats ────────────────────────────
                  SliverToBoxAdapter(
                    child: _TodayStatsSection(profile: profile),
                  ),

                  // ── All-time Stats ───────────────────────────
                  SliverToBoxAdapter(child: _AllTimeSection(profile: profile)),

                  // ── Create Account Banner ─────────────────────
                  SliverToBoxAdapter(child: _CreateAccountBanner()),

                  // ── Settings ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SettingsSection(provider: provider),
                  ),

                  // ── Recent Activity ──────────────────────────
                  SliverToBoxAdapter(
                    child: _ActivitySection(
                      profile: profile,
                      provider: provider,
                    ),
                  ),

                  // ── Logout button ────────────────────────────
                  SliverToBoxAdapter(child: _LogoutButton()),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),

              // Loading overlay
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(
                    child: CircularProgressIndicator(color: PColors.heroAccent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditSheet(BuildContext context, ProfileProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(provider: provider),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CREATE ACCOUNT BANNER  ← NEW
// ═════════════════════════════════════════════════════════════════════════════
class _CreateAccountBanner extends StatefulWidget {
  @override
  State<_CreateAccountBanner> createState() => _CreateAccountBannerState();
}

class _CreateAccountBannerState extends State<_CreateAccountBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, animation, __) => FadeTransition(
                opacity: animation,
                child: const CreateAccountScreen(
                  businessId: 'POS001',
                  businessName: 'SriSoftwarez',
                ),
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
        },
        child: ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF3730A3),
                  Color(0xFF4F46E5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Background decorative circles ─────────────
                Positioned(
                  right: -12,
                  top: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -15,
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),

                // ── Main content ──────────────────────────────
                Row(
                  children: [
                    // Left: icon box
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Center: text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN PANEL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Create Staff Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Add Admin · Manager · Server',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: arrow
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),

                // ── Role badges at bottom ──────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 68),
                  child: Row(
                    children: [
                      _rolePill(
                        icon: Icons.shield_outlined,
                        label: 'Admin',
                        color: const Color(0xFFA5B4FC),
                      ),
                      const SizedBox(width: 8),
                      _rolePill(
                        icon: Icons.bar_chart_rounded,
                        label: 'Manager',
                        color: const Color(0xFF6EE7B7),
                      ),
                      const SizedBox(width: 8),
                      _rolePill(
                        icon: Icons.receipt_outlined,
                        label: 'Server',
                        color: const Color(0xFFFDBA74),
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

  Widget _rolePill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO SECTION  — dark gradient with avatar + info
// ═════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onToggleShift;
  final VoidCallback onEditTap;

  const _HeroSection({
    required this.profile,
    required this.onToggleShift,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PColors.heroBg, Color(0xFF1C1535)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Decorative mesh circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PColors.heroAccent.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: 80,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PColors.heroAccent2.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5E4AE3).withOpacity(0.10),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(24, statusBarH + 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title + edit button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    GestureDetector(
                      onTap: onEditTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Avatar + info row
                Row(
                  children: [
                    // Avatar
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: ProfileAvatar(
                        initials: profile.avatarInitials ?? 'U',
                        size: 80,
                        isOnline: profile.isOnShift,
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Name + role + shift
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              RoleBadge(role: profile.role),
                              const SizedBox(width: 8),
                              ShiftBadge(
                                isOnShift: profile.isOnShift,
                                onToggle: onToggleShift,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info pills row
                Row(
                  children: [
                    _InfoPill(icon: Icons.phone_outlined, label: profile.phone),
                    const SizedBox(width: 10),
                    _InfoPill(
                      icon: Icons.calendar_today_outlined,
                      label: 'Since ${profile.formattedJoinDate}',
                    ),
                    const SizedBox(width: 10),
                    _InfoPill(
                      icon: Icons.timelapse_outlined,
                      label: profile.tenureLabel,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TODAY'S STATS
// ═════════════════════════════════════════════════════════════════════════════
class _TodayStatsSection extends StatelessWidget {
  final UserProfile profile;
  const _TodayStatsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = profile.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: "Today's Performance"),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.90,
            children: [
              ProfileStatCard(
                label: 'Orders',
                value: '${stats.ordersToday}',
                emoji: '📦',
                color: const Color(0xFF5E5CE6),
              ),
              ProfileStatCard(
                label: 'Tables',
                value: '${stats.tablesManaged}',
                emoji: '🪑',
                color: const Color(0xFF30D158),
              ),
              ProfileStatCard(
                label: 'Revenue',
                value: '₹${(stats.revenueToday / 1000).toStringAsFixed(1)}K',
                emoji: '💰',
                color: const Color(0xFFFF9500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALL-TIME STATS
// ═════════════════════════════════════════════════════════════════════════════
class _AllTimeSection extends StatelessWidget {
  final UserProfile profile;
  const _AllTimeSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = profile.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: 'All-time Record'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _AllTimeTile(
                  emoji: '🧾',
                  label: 'Total Orders Handled',
                  value:
                      '${stats.totalOrdersAllTime.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                  color: const Color(0xFF5E5CE6),
                  isFirst: true,
                ),
                const Divider(height: 1, indent: 64, color: PColors.divider),
                _AllTimeTile(
                  emoji: '💵',
                  label: 'Avg. Order Value',
                  value: '₹${stats.avgOrderValue.toStringAsFixed(0)}',
                  color: const Color(0xFFFF9500),
                ),
                const Divider(height: 1, indent: 64, color: PColors.divider),
                _AllTimeTile(
                  emoji: '⏰',
                  label: 'Shifts This Week',
                  value: '${stats.shiftsThisWeek} / 6',
                  color: const Color(0xFF30D158),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTimeTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _AllTimeTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A3A5C),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsSection extends StatelessWidget {
  final ProfileProvider provider;
  const _SettingsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Preferences
          ProfileSectionCard(
            title: 'Preferences',
            children: [
              SettingsRow(
                emoji: '🔔',
                label: 'Notifications',
                subtitle: 'Order alerts and updates',
                iconBg: const Color(0xFFFFF3E0),
                trailing: ProfileSwitch(
                  value: p.notificationsEnabled,
                  onChanged: (_) => provider.toggleNotifications(),
                  activeColor: const Color(0xFFFF9500),
                ),
              ),
              SettingsRow(
                emoji: '🔊',
                label: 'Sound Effects',
                subtitle: 'Beep on new orders',
                iconBg: const Color(0xFFE8F5E9),
                trailing: ProfileSwitch(
                  value: p.soundEnabled,
                  onChanged: (_) => provider.toggleSound(),
                  activeColor: const Color(0xFF30D158),
                ),
              ),
              SettingsRow(
                emoji: '🌙',
                label: 'Dark Mode',
                subtitle: 'Switch app appearance',
                iconBg: const Color(0xFFEDE7F6),
                trailing: ProfileSwitch(
                  value: p.darkModeEnabled,
                  onChanged: (_) => provider.toggleDarkMode(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Account
          ProfileSectionCard(
            title: 'Account',
            children: [
              SettingsRow(
                emoji: '🌐',
                label: 'Language',
                subtitle: p.language,
                iconBg: const Color(0xFFE3F2FD),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '🔒',
                label: 'Change Password',
                subtitle: 'Last changed 30 days ago',
                iconBg: const Color(0xFFFCE4EC),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '🛡️',
                label: 'Privacy & Security',
                iconBg: const Color(0xFFE8EAF6),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Support
          ProfileSectionCard(
            title: 'Support',
            children: [
              SettingsRow(
                emoji: '💬',
                label: 'Help & Support',
                iconBg: const Color(0xFFE0F7FA),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '⭐',
                label: 'Rate the App',
                iconBg: const Color(0xFFFFFDE7),
                onTap: () {},
              ),
              SettingsRow(
                emoji: 'ℹ️',
                label: 'About',
                subtitle: 'Version 1.0.0 · SriSoftwarez',
                iconBg: const Color(0xFFF3E5F5),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ACTIVITY SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _ActivitySection extends StatelessWidget {
  final UserProfile profile;
  final ProfileProvider provider;

  const _ActivitySection({required this.profile, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(title: 'Recent Activity'),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: PColors.heroAccent,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: profile.recentActivity.asMap().entries.map((entry) {
                final i = entry.key;
                final log = entry.value;
                final isLast = i == profile.recentActivity.length - 1;
                return ActivityItem(
                  emoji: log.icon,
                  title: log.title,
                  subtitle: log.subtitle,
                  timeLabel: provider.activityTimeLabel(log),
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  LOGOUT BUTTON
// ═════════════════════════════════════════════════════════════════════════════
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () => _confirmLogout(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: PColors.dangerRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PColors.dangerRed.withOpacity(0.25)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: PColors.dangerRed, size: 20),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: PColors.dangerRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will be signed out of your account.',
          style: TextStyle(color: PColors.labelGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PColors.labelGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: PColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  final ProfileProvider provider;
  const _EditProfileSheet({required this.provider});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.provider.profile;
    _nameCtrl = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDEE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PColors.heroAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: PColors.heroAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Update your personal information',
                      style: TextStyle(fontSize: 12, color: PColors.labelGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: PColors.divider),

          // Fields
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PColors.divider),
            ),
            child: Column(
              children: [
                ProfileEditField(
                  label: 'Full Name',
                  emoji: '👤',
                  controller: _nameCtrl,
                ),
                ProfileEditField(
                  label: 'Email Address',
                  emoji: '✉️',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                ProfileEditField(
                  label: 'Phone Number',
                  emoji: '📱',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: PColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: PColors.labelGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.provider.updateProfile(
                        name: _nameCtrl.text.trim(),
                        email: _emailCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PColors.heroAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL  — shared heading widget
// ═════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: PColors.labelGrey,
        letterSpacing: 1.2,
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/screens/utils/user_profile.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/profile_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const _ProfileView(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ROOT VIEW
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F3FA),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Hero ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _HeroSection(
                      profile: profile,
                      onToggleShift: provider.toggleShift,
                      onEditTap: () => _showEditSheet(context, provider),
                    ),
                  ),

                  // ── Today's Stats ────────────────────────────
                  SliverToBoxAdapter(
                    child: _TodayStatsSection(profile: profile),
                  ),

                  // ── All-time Stats ───────────────────────────
                  SliverToBoxAdapter(
                    child: _AllTimeSection(profile: profile),
                  ),

                  // ── Settings ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SettingsSection(provider: provider),
                  ),

                  // ── Recent Activity ──────────────────────────
                  SliverToBoxAdapter(
                    child: _ActivitySection(
                      profile: profile,
                      provider: provider,
                    ),
                  ),

                  // ── Logout button ────────────────────────────
                  SliverToBoxAdapter(
                    child: _LogoutButton(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),

              // Loading overlay
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: PColors.heroAccent,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditSheet(BuildContext context, ProfileProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(provider: provider),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HERO SECTION  — dark gradient with avatar + info
// ═════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onToggleShift;
  final VoidCallback onEditTap;

  const _HeroSection({
    required this.profile,
    required this.onToggleShift,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PColors.heroBg, Color(0xFF1C1535)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Decorative mesh circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PColors.heroAccent.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: 80,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PColors.heroAccent2.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5E4AE3).withOpacity(0.10),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(24, statusBarH + 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title + edit button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    GestureDetector(
                      onTap: onEditTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Avatar + info row
                Row(
                  children: [
                    // Avatar
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: ProfileAvatar(
                        initials: profile.avatarInitials ?? 'U',
                        size: 80,
                        isOnline: profile.isOnShift,
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Name + role + shift
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              RoleBadge(role: profile.role),
                              const SizedBox(width: 8),
                              ShiftBadge(
                                isOnShift: profile.isOnShift,
                                onToggle: onToggleShift,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info pills row
                Row(
                  children: [
                    _InfoPill(
                      icon: Icons.phone_outlined,
                      label: profile.phone,
                    ),
                    const SizedBox(width: 10),
                    _InfoPill(
                      icon: Icons.calendar_today_outlined,
                      label: 'Since ${profile.formattedJoinDate}',
                    ),
                    const SizedBox(width: 10),
                    _InfoPill(
                      icon: Icons.timelapse_outlined,
                      label: profile.tenureLabel,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  TODAY'S STATS
// ═════════════════════════════════════════════════════════════════════════════
class _TodayStatsSection extends StatelessWidget {
  final UserProfile profile;
  const _TodayStatsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = profile.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: "Today's Performance"),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.90,
            children: [
              ProfileStatCard(
                label: 'Orders',
                value: '${stats.ordersToday}',
                emoji: '📦',
                color: const Color(0xFF5E5CE6),
              ),
              ProfileStatCard(
                label: 'Tables',
                value: '${stats.tablesManaged}',
                emoji: '🪑',
                color: const Color(0xFF30D158),
              ),
              ProfileStatCard(
                label: 'Revenue',
                value: '₹${(stats.revenueToday / 1000).toStringAsFixed(1)}K',
                emoji: '💰',
                color: const Color(0xFFFF9500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALL-TIME STATS
// ═════════════════════════════════════════════════════════════════════════════
class _AllTimeSection extends StatelessWidget {
  final UserProfile profile;
  const _AllTimeSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = profile.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: 'All-time Record'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _AllTimeTile(
                  emoji: '🧾',
                  label: 'Total Orders Handled',
                  value: '${stats.totalOrdersAllTime.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                  color: const Color(0xFF5E5CE6),
                  isFirst: true,
                ),
                const Divider(height: 1, indent: 64, color: PColors.divider),
                _AllTimeTile(
                  emoji: '💵',
                  label: 'Avg. Order Value',
                  value: '₹${stats.avgOrderValue.toStringAsFixed(0)}',
                  color: const Color(0xFFFF9500),
                ),
                const Divider(height: 1, indent: 64, color: PColors.divider),
                _AllTimeTile(
                  emoji: '⏰',
                  label: 'Shifts This Week',
                  value: '${stats.shiftsThisWeek} / 6',
                  color: const Color(0xFF30D158),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTimeTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _AllTimeTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A3A5C),
              ),
            ),
          ),
          // Progress-style value badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsSection extends StatelessWidget {
  final ProfileProvider provider;
  const _SettingsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider.profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Preferences
          ProfileSectionCard(
            title: 'Preferences',
            children: [
              SettingsRow(
                emoji: '🔔',
                label: 'Notifications',
                subtitle: 'Order alerts and updates',
                iconBg: const Color(0xFFFFF3E0),
                trailing: ProfileSwitch(
                  value: p.notificationsEnabled,
                  onChanged: (_) => provider.toggleNotifications(),
                  activeColor: const Color(0xFFFF9500),
                ),
              ),
              SettingsRow(
                emoji: '🔊',
                label: 'Sound Effects',
                subtitle: 'Beep on new orders',
                iconBg: const Color(0xFFE8F5E9),
                trailing: ProfileSwitch(
                  value: p.soundEnabled,
                  onChanged: (_) => provider.toggleSound(),
                  activeColor: const Color(0xFF30D158),
                ),
              ),
              SettingsRow(
                emoji: '🌙',
                label: 'Dark Mode',
                subtitle: 'Switch app appearance',
                iconBg: const Color(0xFFEDE7F6),
                trailing: ProfileSwitch(
                  value: p.darkModeEnabled,
                  onChanged: (_) => provider.toggleDarkMode(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Account
          ProfileSectionCard(
            title: 'Account',
            children: [
              SettingsRow(
                emoji: '🌐',
                label: 'Language',
                subtitle: p.language,
                iconBg: const Color(0xFFE3F2FD),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '🔒',
                label: 'Change Password',
                subtitle: 'Last changed 30 days ago',
                iconBg: const Color(0xFFFCE4EC),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '🛡️',
                label: 'Privacy & Security',
                iconBg: const Color(0xFFE8EAF6),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Support
          ProfileSectionCard(
            title: 'Support',
            children: [
              SettingsRow(
                emoji: '💬',
                label: 'Help & Support',
                iconBg: const Color(0xFFE0F7FA),
                onTap: () {},
              ),
              SettingsRow(
                emoji: '⭐',
                label: 'Rate the App',
                iconBg: const Color(0xFFFFFDE7),
                onTap: () {},
              ),
              SettingsRow(
                emoji: 'ℹ️',
                label: 'About',
                subtitle: 'Version 1.0.0 · SriSoftwarez',
                iconBg: const Color(0xFFF3E5F5),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ACTIVITY SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _ActivitySection extends StatelessWidget {
  final UserProfile profile;
  final ProfileProvider provider;

  const _ActivitySection({
    required this.profile,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(title: 'Recent Activity'),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: PColors.heroAccent,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: profile.recentActivity.asMap().entries.map((entry) {
                final i = entry.key;
                final log = entry.value;
                final isLast = i == profile.recentActivity.length - 1;
                return ActivityItem(
                  emoji: log.icon,
                  title: log.title,
                  subtitle: log.subtitle,
                  timeLabel: provider.activityTimeLabel(log),
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  LOGOUT BUTTON
// ═════════════════════════════════════════════════════════════════════════════
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () => _confirmLogout(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: PColors.dangerRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PColors.dangerRed.withOpacity(0.25),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: PColors.dangerRed, size: 20),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: PColors.dangerRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will be signed out of your account.',
          style: TextStyle(color: PColors.labelGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PColors.labelGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: PColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  final ProfileProvider provider;
  const _EditProfileSheet({required this.provider});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.provider.profile;
    _nameCtrl  = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDEE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PColors.heroAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: PColors.heroAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Update your personal information',
                      style: TextStyle(
                        fontSize: 12,
                        color: PColors.labelGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: PColors.divider),

          // Fields
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PColors.divider),
            ),
            child: Column(
              children: [
                ProfileEditField(
                  label: 'Full Name',
                  emoji: '👤',
                  controller: _nameCtrl,
                ),
                ProfileEditField(
                  label: 'Email Address',
                  emoji: '✉️',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                ProfileEditField(
                  label: 'Phone Number',
                  emoji: '📱',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: PColors.divider, width: 1.5),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: PColors.labelGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.provider.updateProfile(
                        name: _nameCtrl.text.trim(),
                        email: _emailCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PColors.heroAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL  — shared heading widget
// ═════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: PColors.labelGrey,
        letterSpacing: 1.2,
      ),
    );
  }
}*/

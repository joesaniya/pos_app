import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/screens/team_member_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_app/providers/employee_management_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DROP-IN REPLACEMENT: paste this card inside your QUICK ACTIONS Row/Wrap
//  alongside your existing "Create Account" and "Change Password" cards.
// ─────────────────────────────────────────────────────────────────────────────

class TeamMembersQuickActionCard extends StatefulWidget {
  const TeamMembersQuickActionCard({super.key});

  @override
  State<TeamMembersQuickActionCard> createState() =>
      _TeamMembersQuickActionCardState();
}

class _TeamMembersQuickActionCardState extends State<TeamMembersQuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  // ── Match your existing card style (white bg, soft shadow, rounded) ────────
  static const _iconBg = Color(
    0xFF4F6EF7,
  ); // blue — same family as "Create Account"
  static const _iconGlow = Color(0x284F6EF7);
  static const _openColor = Color(0xFF4F6EF7);
  static const _badgeBg = Color(0xFFE8F5F0);
  static const _badgeText = Color(0xFF00B574);

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _open(BuildContext ctx) {
    final prov = context.read<EmployeeManagementProvider>();
    Navigator.of(ctx).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: ChangeNotifierProvider.value(
              value: prov,
              child: const TeamMembersScreen(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeManagementProvider>(
      builder: (ctx, prov, _) {
        final activeCount = prov.activeCount;
        final totalCount = prov.totalCount;

        return ScaleTransition(
          scale: _pressScale,
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              _pressCtrl.forward();
            },
            onTapUp: (_) {
              _pressCtrl.reverse();
              _open(ctx);
            },
            onTapCancel: () => _pressCtrl.reverse(),

            // ── Card shell — matches your existing white cards exactly ──────
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    width:
                        155, // same width as your existing quick-action cards
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Icon box ──────────────────────────────────────────────
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _iconBg,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _iconGlow,
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),

                            // Active count badge (top-right of icon)
                            if (!prov.isLoading && totalCount > 0)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '$activeCount active',
                                    style: const TextStyle(
                                      color: _badgeText,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Title ─────────────────────────────────────────────────
                        const Text(
                          'Team\nMembers',
                          style: TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ── Subtitle ──────────────────────────────────────────────
                        Text(
                          prov.isLoading
                              ? 'Loading...'
                              : '$totalCount member${totalCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFFADB5C7),
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── "Open →" link — identical style to your existing cards ─
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Open',
                              style: TextStyle(
                                color: _openColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: _openColor,
                              size: 13,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(),
                ), // empty space to match your existing card layout
              ],
            ),
          ),
        );
      },
    );
  }
}

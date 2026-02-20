import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/user_profile.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS  (profile-specific)
// ═══════════════════════════════════════════════════════════════
class PColors {
  static const heroBg        = Color(0xFF0D0D1A);
  static const heroSurface   = Color(0xFF161625);
  static const heroAccent    = Color(0xFF7C5CFC);
  static const heroAccent2   = Color(0xFFFF6B6B);
  static const avatarRing    = Color(0xFF7C5CFC);
  static const onlineGreen   = Color(0xFF30D158);
  static const cardBg        = Colors.white;
  static const labelGrey     = Color(0xFF9898AA);
  static const divider       = Color(0xFFF0F0F5);
  static const settingsBg    = Color(0xFFF8F8FC);
  static const dangerRed     = Color(0xFFFF3B30);
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE AVATAR  — with initials, ring, online badge
// ═══════════════════════════════════════════════════════════════
class ProfileAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool isOnline;
  final bool showRing;

  const ProfileAvatar({
    Key? key,
    required this.initials,
    this.size = 80,
    this.isOnline = false,
    this.showRing = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glow ring
        if (showRing)
          Container(
            width: size + 8,
            height: size + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF7C5CFC),
                  Color(0xFFFF6B6B),
                  Color(0xFF7C5CFC),
                ],
              ),
            ),
          ),
        // White gap ring
        Positioned(
          left: 3,
          top: 3,
          child: Container(
            width: size + 2,
            height: size + 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PColors.heroBg,
            ),
          ),
        ),
        // Avatar circle
        Positioned(
          left: 4,
          top: 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C5CFC), Color(0xFFAA8BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.30,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        // Online indicator
        if (isOnline)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: PColors.onlineGreen,
                shape: BoxShape.circle,
                border: Border.all(color: PColors.heroBg, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ROLE BADGE  — pill with emoji + label
// ═══════════════════════════════════════════════════════════════
class RoleBadge extends StatelessWidget {
  final StaffRole role;

  const RoleBadge({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: PColors.heroAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PColors.heroAccent.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(role.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            role.label,
            style: const TextStyle(
              color: Color(0xFFBBADFF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHIFT BADGE  — on/off shift indicator
// ═══════════════════════════════════════════════════════════════
class ShiftBadge extends StatelessWidget {
  final bool isOnShift;
  final VoidCallback onToggle;

  const ShiftBadge({
    Key? key,
    required this.isOnShift,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isOnShift
              ? PColors.onlineGreen.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnShift
                ? PColors.onlineGreen.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnShift ? PColors.onlineGreen : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnShift ? 'On Shift' : 'Off Shift',
              style: TextStyle(
                color: isOnShift ? PColors.onlineGreen : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STAT CARD  — single metric tile
// ═══════════════════════════════════════════════════════════════
class ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const ProfileStatCard({
    Key? key,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: PColors.labelGrey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SECTION CARD  — white card container for a group of settings
// ═══════════════════════════════════════════════════════════════
class ProfileSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ProfileSectionCard({
    Key? key,
    required this.title,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PColors.labelGrey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: PColors.divider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SETTINGS ROW  — icon + label + trailing widget
// ═══════════════════════════════════════════════════════════════
class SettingsRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color iconBg;
  final VoidCallback? onTap;
  final bool isDanger;

  const SettingsRow({
    Key? key,
    required this.emoji,
    required this.label,
    this.subtitle,
    this.trailing,
    this.iconBg = const Color(0xFFF0F0F8),
    this.onTap,
    this.isDanger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDanger
                    ? PColors.dangerRed.withOpacity(0.10)
                    : iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 14),
            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDanger ? PColors.dangerRed : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PColors.labelGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Trailing
            if (trailing != null)
              trailing!
            else if (onTap != null && !isDanger)
              const Icon(
                Icons.chevron_right_rounded,
                color: PColors.labelGrey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CUSTOM SWITCH  — branded toggle
// ═══════════════════════════════════════════════════════════════
class ProfileSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const ProfileSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
    this.activeColor = PColors.heroAccent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: activeColor,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFDDDDEE),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVITY ITEM  — single recent activity row
// ═══════════════════════════════════════════════════════════════
class ActivityItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String timeLabel;
  final bool isLast;

  const ActivityItem({
    Key? key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.isLast = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PColors.heroAccent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: PColors.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: PColors.labelGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PColors.labelGrey,
                    ),
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

// ═══════════════════════════════════════════════════════════════
//  EDITABLE FIELD  — inline text field for profile editing
// ═══════════════════════════════════════════════════════════════
class ProfileEditField extends StatelessWidget {
  final String label;
  final String emoji;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isLast;

  const ProfileEditField({
    Key? key,
    required this.label,
    required this.emoji,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.isLast = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PColors.heroAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PColors.labelGrey,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Enter $label',
                        hintStyle: const TextStyle(
                          color: PColors.labelGrey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 66, color: PColors.divider),
      ],
    );
  }
}
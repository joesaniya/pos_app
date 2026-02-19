import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — soft pink/rose
// ═══════════════════════════════════════════════════════════════
class SC {
  static const bg = Color(0xFFFDF2F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFCE7F3);

  static const pink = Color(0xFFEC4899);
  static const pinkDark = Color(0xFFDB2777);
  static const pinkLight = Color(0xFFFCE7F3);

  static const blue = Color(0xFF3B82F6);
  static const blueBg = Color(0xFFDBEAFE);
  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFD1FAE5);
  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFF3E8FF);
  static const orange = Color(0xFFF59E0B);
  static const orangeBg = Color(0xFFFEF3C7);

  static const textPri = Color(0xFF1F2937);
  static const textSec = Color(0xFF6B7280);
  static const textMute = Color(0xFF9CA3AF);
  static const border = Color(0xFFFCE7F3);
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: SC.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PinkHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    _ProfileCard(),
                    const SizedBox(height: 24),
                    _QuickStats(),
                    const SizedBox(height: 24),
                    _SectionLabel('Account'),
                    _SettingsGroup(
                      items: [
                        _SettingItem(
                          '👤',
                          'Profile Settings',
                          'Update personal info',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '🔐',
                          'Security',
                          'Password & 2FA',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '📧',
                          'Email Notifications',
                          'Daily reports',
                          true,
                          null,
                        ),
                        _SettingItem(
                          '🔔',
                          'Push Notifications',
                          'Order alerts',
                          true,
                          null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Restaurant'),
                    _SettingsGroup(
                      items: [
                        _SettingItem(
                          '🏪',
                          'Business Info',
                          'Name, address, hours',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '💳',
                          'Payment Methods',
                          'Accepted payments',
                          null,
                          SC.blue,
                        ),
                        _SettingItem(
                          '🧾',
                          'Receipts & Invoices',
                          'Customize templates',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '📊',
                          'Tax Settings',
                          'GST & tax rates',
                          null,
                          SC.green,
                        ),
                        _SettingItem(
                          '🍽️',
                          'Menu Management',
                          'Add/edit items',
                          null,
                          SC.orange,
                        ),
                        _SettingItem(
                          '🪑',
                          'Table Settings',
                          'Layout & capacity',
                          null,
                          SC.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Preferences'),
                    _SettingsGroup(
                      items: [
                        _SettingItem('🌍', 'Language', 'English', null, null),
                        _SettingItem('💱', 'Currency', 'INR (₹)', null, null),
                        _SettingItem(
                          '📅',
                          'Date Format',
                          'DD/MM/YYYY',
                          null,
                          null,
                        ),
                        _SettingItem('⏰', 'Time Format', '12-hour', null, null),
                        _SettingItem(
                          '🔊',
                          'Sound Effects',
                          'Button sounds',
                          true,
                          null,
                        ),
                        _SettingItem(
                          '📳',
                          'Haptic Feedback',
                          'Vibration',
                          false,
                          null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Integrations'),
                    _SettingsGroup(
                      items: [
                        _SettingItem(
                          '☁️',
                          'Cloud Backup',
                          'Auto backup data',
                          true,
                          SC.blue,
                        ),
                        _SettingItem(
                          '📱',
                          'Mobile POS',
                          'Tablet sync',
                          false,
                          SC.purple,
                        ),
                        _SettingItem(
                          '🖨️',
                          'Printer Settings',
                          'KOT & receipt',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '📡',
                          'API Access',
                          'Third-party apps',
                          null,
                          SC.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Support'),
                    _SettingsGroup(
                      items: [
                        _SettingItem(
                          '❓',
                          'Help Center',
                          'FAQs & tutorials',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '📞',
                          'Contact Support',
                          'Get help from team',
                          null,
                          SC.blue,
                        ),
                        _SettingItem(
                          '💬',
                          'Chat with Us',
                          'Live support',
                          null,
                          SC.green,
                        ),
                        _SettingItem(
                          '⭐',
                          'Rate App',
                          'Share your feedback',
                          null,
                          SC.orange,
                        ),
                        _SettingItem(
                          '📝',
                          'Send Feedback',
                          'Suggest improvements',
                          null,
                          null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Legal'),
                    _SettingsGroup(
                      items: [
                        _SettingItem(
                          '📄',
                          'Terms of Service',
                          'Read our terms',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '🔒',
                          'Privacy Policy',
                          'How we use data',
                          null,
                          null,
                        ),
                        _SettingItem(
                          '📋',
                          'Licenses',
                          'Open source licenses',
                          null,
                          null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DangerZone(),
                    const SizedBox(height: 24),
                    _AppVersion(),
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

// ═════════════════════════════════════════════════════════════════════════════
//  PINK HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _PinkHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SC.pink, SC.pinkDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'App preferences & configuration',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
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
//  PROFILE CARD
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SC.pink, SC.pinkDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SC.pink.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'RS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: SC.pink,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resto Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'admin@restopos.com',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  QUICK STATS
// ═════════════════════════════════════════════════════════════════════════════
class _QuickStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile('Active since', 'Jan 2024', SC.blue)),
        const SizedBox(width: 12),
        Expanded(child: _StatTile('Total Orders', '2,348', SC.green)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SC.textSec,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ═════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: SC.textMute,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS GROUP
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsGroup extends StatelessWidget {
  final List<_SettingItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          return Column(
            children: [
              _SettingItemWidget(item: e.value),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 58, color: SC.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTING ITEM DATA
// ═════════════════════════════════════════════════════════════════════════════
class _SettingItem {
  final String emoji, title, subtitle;
  final bool? hasSwitch;
  final Color? accentColor;
  const _SettingItem(
    this.emoji,
    this.title,
    this.subtitle,
    this.hasSwitch,
    this.accentColor,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTING ITEM WIDGET
// ═════════════════════════════════════════════════════════════════════════════
class _SettingItemWidget extends StatefulWidget {
  final _SettingItem item;
  const _SettingItemWidget({required this.item});

  @override
  State<_SettingItemWidget> createState() => _SettingItemWidgetState();
}

class _SettingItemWidgetState extends State<_SettingItemWidget> {
  late bool _switchValue;

  @override
  void initState() {
    super.initState();
    _switchValue = widget.item.hasSwitch ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.item.hasSwitch == null ? () {} : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(widget.item.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SC.textPri,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.subtitle,
                    style: const TextStyle(fontSize: 12, color: SC.textSec),
                  ),
                ],
              ),
            ),
            if (widget.item.hasSwitch != null)
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: _switchValue,
                  onChanged: (v) => setState(() => _switchValue = v),
                  activeColor: Colors.white,
                  activeTrackColor: widget.item.accentColor ?? SC.pink,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFDDDDE8),
                ),
              )
            else if (widget.item.accentColor != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.item.accentColor!.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: widget.item.accentColor,
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 14, color: SC.textMute),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DANGER ZONE
// ═════════════════════════════════════════════════════════════════════════════
class _DangerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SC.redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: SC.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: SC.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DangerButton('Clear All Data', Icons.delete_sweep_outlined, () {}),
          const SizedBox(height: 8),
          _DangerButton('Reset Settings', Icons.restart_alt, () {}),
          const SizedBox(height: 8),
          _DangerButton('Logout', Icons.logout, () {}),
          const SizedBox(height: 8),
          _DangerButton('Delete Account', Icons.person_remove_outlined, () {}),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DangerButton(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SC.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: SC.red),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SC.red,
            ),
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  APP VERSION
// ═════════════════════════════════════════════════════════════════════════════
class _AppVersion extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SC.pinkLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.restaurant_menu, color: SC.pink, size: 24),
        ),
        const SizedBox(height: 10),
        const Text(
          'Resto POS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: SC.textPri,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Version 1.0.0 (Build 2025)',
          style: TextStyle(fontSize: 11, color: SC.textMute),
        ),
        const SizedBox(height: 8),
        const Text(
          'Made with ❤️ in India',
          style: TextStyle(fontSize: 11, color: SC.textSec),
        ),
      ],
    ),
  );
}

/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — soft pink/rose theme
// ═══════════════════════════════════════════════════════════════
class SC {
  static const bg          = Color(0xFFFDF2F8);
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceAlt  = Color(0xFFFCE7F3);
  
  // Pink/Rose
  static const pink        = Color(0xFFEC4899);
  static const pinkDark    = Color(0xFFDB2777);
  static const pinkLight   = Color(0xFFFCE7F3);
  static const rose        = Color(0xFFF472B6);
  
  // Supporting
  static const blue        = Color(0xFF3B82F6);
  static const blueBg      = Color(0xFFDBEAFE);
  static const green       = Color(0xFF10B981);
  static const greenBg     = Color(0xFFD1FAE5);
  static const red         = Color(0xFFEF4444);
  static const redBg       = Color(0xFFFEE2E2);
  static const purple      = Color(0xFF7C3AED);
  static const purpleBg    = Color(0xFFF3E8FF);
  
  // Text
  static const textPri  = Color(0xFF1F2937);
  static const textSec  = Color(0xFF6B7280);
  static const textMute = Color(0xFF9CA3AF);
  static const border   = Color(0xFFFCE7F3);
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    
    return Scaffold(
      backgroundColor: SC.bg,
      body: SafeArea(
        child: Column(
          children: [
            _PinkHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileCard(),
                    const SizedBox(height: 20),
                    _SectionLabel('Account'),
                    _SettingsGroup(items: [
                      ('👤', 'Profile Settings', 'Update personal info', null),
                      ('🔐', 'Security', 'Password & authentication', null),
                      ('📧', 'Notifications', 'Email & push alerts', true),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel('Restaurant'),
                    _SettingsGroup(items: [
                      ('🏪', 'Business Info', 'Name, address, hours', null),
                      ('💳', 'Payment Methods', 'Accepted payments', null),
                      ('🧾', 'Receipts & Invoices', 'Customize templates', null),
                      ('📊', 'Tax Settings', 'GST & tax rates', null),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel('Preferences'),
                    _SettingsGroup(items: [
                      ('🌍', 'Language', 'English', null),
                      ('💱', 'Currency', 'INR (₹)', null),
                      ('📅', 'Date Format', 'DD/MM/YYYY', null),
                      ('🔔', 'Sound', 'Notification sounds', true),
                    ]),
                    const SizedBox(height: 20),
                    _SectionLabel('Support'),
                    _SettingsGroup(items: [
                      ('❓', 'Help Center', 'FAQs & tutorials', null),
                      ('📞', 'Contact Support', 'Get help from team', null),
                      ('⭐', 'Rate App', 'Share your feedback', null),
                    ]),
                    const SizedBox(height: 20),
                    _DangerZone(),
                    const SizedBox(height: 20),
                    _AppVersion(),
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

// ═════════════════════════════════════════════════════════════════════════════
//  PINK HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _PinkHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SC.pink, SC.pinkDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    )),
                SizedBox(height: 2),
                Text('App preferences & configuration',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PROFILE CARD
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SC.pink, SC.pinkDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SC.pink.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('RS',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: SC.pink)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resto Admin',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                SizedBox(height: 3),
                Text('admin@restopos.com',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ═════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: SC.textMute,
              letterSpacing: 1.2)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS GROUP
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsGroup extends StatelessWidget {
  final List<(String, String, String, bool?)> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              _SettingsItem(
                emoji: item.$1,
                title: item.$2,
                subtitle: item.$3,
                hasSwitch: item.$4,
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 58, color: SC.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS ITEM
// ═════════════════════════════════════════════════════════════════════════════
class _SettingsItem extends StatefulWidget {
  final String emoji, title, subtitle;
  final bool? hasSwitch;
  const _SettingsItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.hasSwitch,
  });

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _switchValue = true;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.hasSwitch == null ? () {} : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SC.textPri)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle,
                      style: const TextStyle(fontSize: 12, color: SC.textSec)),
                ],
              ),
            ),
            if (widget.hasSwitch != null)
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: _switchValue,
                  onChanged: (v) => setState(() => _switchValue = v),
                  activeColor: Colors.white,
                  activeTrackColor: SC.pink,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFDDDDE8),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: SC.textMute),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  DANGER ZONE
// ═════════════════════════════════════════════════════════════════════════════
class _DangerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SC.redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: SC.red, size: 20),
              SizedBox(width: 8),
              Text('Danger Zone',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SC.red)),
            ],
          ),
          const SizedBox(height: 12),
          _DangerButton(
            label: 'Clear All Data',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _DangerButton(
            label: 'Logout',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _DangerButton(
            label: 'Delete Account',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SC.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 16, color: SC.red),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: SC.red)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  APP VERSION
// ═════════════════════════════════════════════════════════════════════════════
class _AppVersion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Text('Resto POS',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: SC.textSec)),
          SizedBox(height: 4),
          Text('Version 1.0.0',
              style: TextStyle(fontSize: 11, color: SC.textMute)),
        ],
      ),
    );
  }
}*/

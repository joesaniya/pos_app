import 'package:flutter/material.dart';
import 'package:pos_app/models/table_modal.dart';
import 'package:pos_app/screens/tables_screen/table_theme.dart';


// ═════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════

class InfoTile extends StatelessWidget {
  final String label, value, emoji;
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: TC.textPri,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 10, color: TC.textMute)),
          ],
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  final String icon, label, value;
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: TC.textMute,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TC.textPri,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActionBtn extends StatelessWidget {
  final String label, emoji;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const ActionBtn({
    super.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: outlined ? color : color.withOpacity(0.3),
            width: outlined ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const OutlineBtn({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class SheetSection extends StatelessWidget {
  final String text;
  const SheetSection(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: TC.textMute,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: TC.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class SheetTopBar extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  const SheetTopBar({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: TC.textPri,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: TC.textSec)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: TC.divider),
      ],
    );
  }
}

class FormFieldWidget extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  const FormFieldWidget({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: TC.textSec,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TC.textPri,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: TC.textMute, fontSize: 13),
            filled: true,
            fillColor: TC.surfaceWarm,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TC.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class ToggleRow extends StatelessWidget {
  final String label, subtitle, emoji;
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TC.textPri,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: TC.textMute)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: TC.accent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDDDDE8),
            ),
          ),
        ],
      ),
    );
  }
}

class TableIconWidget extends StatelessWidget {
  final TableShape shape;
  final int capacity;
  final Color color, bg;
  final String tableName;
  const TableIconWidget({
    super.key,
    required this.shape,
    required this.capacity,
    required this.color,
    required this.bg,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final w = shape == TableShape.rectangle ? 52.0 : 44.0;
    return Container(
      width: w,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape == TableShape.round
            ? BorderRadius.circular(22)
            : shape == TableShape.rectangle
                ? BorderRadius.circular(8)
                : BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        tableName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class DurationChips extends StatelessWidget {
  final DateTime checkIn;
  final DateTime? checkOut;
  final ValueChanged<DateTime?> onCheckOutChanged;

  const DurationChips({
    super.key,
    required this.checkIn,
    required this.checkOut,
    required this.onCheckOutChanged,
  });

  static const _presets = [
    ('10 min', 10),
    ('20 min', 20),
    ('30 min', 30),
    ('1 hr', 60),
    ('2 hr', 120),
    ('3 hr', 180),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _presets.map((p) {
          final label = p.$1;
          final mins = p.$2;
          final target = checkIn.add(Duration(minutes: mins));
          final isSel =
              checkOut != null &&
              checkOut!.difference(checkIn).inMinutes == mins;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onCheckOutChanged(target),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel ? TC.reserved.withOpacity(0.12) : TC.surfaceWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? TC.reserved : TC.border,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSel ? TC.reserved : TC.textSec,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: TC.accentLight, shape: BoxShape.circle),
            child: const Text('🪑', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No tables found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.textPri),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different filter or add a new table',
            style: TextStyle(fontSize: 13, color: TC.textSec),
          ),
        ],
      ),
    );
  }
}

class AddTableFAB extends StatelessWidget {
  final VoidCallback onTap;
  const AddTableFAB({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: TC.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: TC.accent.withOpacity(0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Table',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavArrow({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: TC.surfaceWarm,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TC.border),
        ),
        child: Icon(icon, color: TC.textSec, size: 20),
      ),
    );
  }
}
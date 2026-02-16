import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_modal.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
class IColors {
  // Page background — warm off-white with subtle warmth
  static const bg = Color(0xFFF5F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF9F8F5);

  // Accent — deep teal/slate-green (unique for inventory)
  static const accent = Color(0xFF1B4D3E);
  static const accentMid = Color(0xFF2D7A5F);
  static const accentLight = Color(0xFFE8F5F0);

  // Status
  static const inStock = Color(0xFF1E8A5E);
  static const inStockBg = Color(0xFFE6F5EE);
  static const lowStock = Color(0xFFB8800A);
  static const lowStockBg = Color(0xFFFFF3DC);
  static const critical = Color(0xFFCC3300);
  static const criticalBg = Color(0xFFFFEDE8);
  static const outOfStock = Color(0xFF5A5A6E);
  static const outOfStockBg = Color(0xFFF0EFF5);

  // Text
  static const textPrimary = Color(0xFF1A1A28);
  static const textSecondary = Color(0xFF6B6B80);
  static const textMuted = Color(0xFFAAABBB);

  // Misc
  static const divider = Color(0xFFEEEDF0);
  static const cardShadow = Color(0x14000000);
  static const inputFill = Color(0xFFF2F1EE);
}

// Status → color mapping
Color iStatusColor(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStock;
    case StockStatus.lowStock:
      return IColors.lowStock;
    case StockStatus.critical:
      return IColors.critical;
    case StockStatus.outOfStock:
      return IColors.outOfStock;
  }
}

Color iStatusBg(StockStatus s) {
  switch (s) {
    case StockStatus.inStock:
      return IColors.inStockBg;
    case StockStatus.lowStock:
      return IColors.lowStockBg;
    case StockStatus.critical:
      return IColors.criticalBg;
    case StockStatus.outOfStock:
      return IColors.outOfStockBg;
  }
}

// ═══════════════════════════════════════════════════════════════
//  STOCK PROGRESS BAR
// ═══════════════════════════════════════════════════════════════
class StockBar extends StatelessWidget {
  final double percent; // 0.0–1.0
  final double height;
  final StockStatus status;

  const StockBar({
    Key? key,
    required this.percent,
    this.height = 6,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(status);
    return Stack(
      children: [
        // Track
        Container(
          height: height,
          decoration: BoxDecoration(
            color: IColors.divider,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
        // Fill
        FractionallySizedBox(
          widthFactor: percent.clamp(0.0, 1.0),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STATUS BADGE
// ═══════════════════════════════════════════════════════════════
class StockStatusBadge extends StatelessWidget {
  final StockStatus status;
  final bool compact;

  const StockStatusBadge({Key? key, required this.status, this.compact = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(status);
    final bg = iStatusBg(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  INVENTORY ITEM CARD
// ═══════════════════════════════════════════════════════════════
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onAddStock;

  const InventoryItemCard({
    Key? key,
    required this.item,
    required this.onTap,
    required this.onAddStock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = iStatusColor(item.status);
    final isCritical =
        item.status == StockStatus.critical ||
        item.status == StockStatus.outOfStock;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: IColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: isCritical
              ? Border.all(color: color.withOpacity(0.35), width: 1.5)
              : Border.all(color: IColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: isCritical ? color.withOpacity(0.08) : IColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: emoji + badge + quick-add ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji in tinted box
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iStatusBg(item.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const Spacer(),
                  // Quick add button
                  GestureDetector(
                    onTap: onAddStock,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: IColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: IColors.accentMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Name + category ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: IColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: IColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Stock bar ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: StockBar(percent: item.stockPercent, status: item.status),
            ),

            const SizedBox(height: 8),

            // ── Stock amount + status ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.stockDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  StockStatusBadge(status: item.status, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY METRIC TILE
// ═══════════════════════════════════════════════════════════════
class InventoryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;
  final bool isWide;

  const InventoryMetricTile({
    Key? key,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
    this.isWide = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: isWide
          ? Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: IColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TRANSACTION TILE
// ═══════════════════════════════════════════════════════════════
class TransactionTile extends StatelessWidget {
  final StockTransaction tx;
  final StockUnit unit;

  const TransactionTile({Key? key, required this.tx, required this.unit})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.type.isPositive;
    final color = isPositive ? IColors.inStock : IColors.critical;
    final sign = isPositive ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(tx.type.emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.note,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Amount + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${tx.quantity.toInt()} ${unit.label}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeLabel(tx.date),
                style: const TextStyle(fontSize: 10, color: IColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════
//  INVENTORY FORM FIELD  (consistent input across add/edit)
// ═══════════════════════════════════════════════════════════════
class InventoryField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefix;
  final String? suffix;
  final bool isLast;
  final String? Function(String?)? validator;

  const InventoryField({
    Key? key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.suffix,
    this.isLast = false,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: IColors.textSecondary,
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
              color: IColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: IColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixText: prefix,
              suffixText: suffix,
              filled: true,
              fillColor: IColors.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: IColors.accentMid,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: IColors.critical,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: IColors.critical,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SECTION HEADER (sheet sections)
// ═══════════════════════════════════════════════════════════════
class SheetSection extends StatelessWidget {
  final String title;
  const SheetSection({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: IColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BOTTOM SHEET HANDLE + HEADER
// ═══════════════════════════════════════════════════════════════
class SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final Color accentColor;

  const SheetHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    this.accentColor = IColors.accentMid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 18),
          decoration: BoxDecoration(
            color: IColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
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
                        color: IColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: IColors.divider),
      ],
    );
  }
}

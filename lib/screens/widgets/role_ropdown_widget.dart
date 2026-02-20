
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/screens/utils/role_config.dart';



class RoleDropdown extends StatefulWidget {
  final String? selectedValue;
  final ValueChanged<String> onChanged;
  final Color accentColor;

  const RoleDropdown({
    super.key,
    required this.selectedValue,
    required this.onChanged,
    this.accentColor = const Color(0xFF1B4332),
  });

  @override
  State<RoleDropdown> createState() => _RoleDropdownState();
}

class _RoleDropdownState extends State<RoleDropdown>
    with TickerProviderStateMixin {
  // ── Overlay ────────────────────────────────────────────────────
  OverlayEntry? _overlayEntry;
  final _triggerKey = GlobalKey();
  bool _isOpen = false;

  // ── Animations ─────────────────────────────────────────────────
  late AnimationController _chevronCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _chevronAngle;
  late Animation<double> _shimmerPos;

  @override
  void initState() {
    super.initState();

    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _chevronAngle = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeOutCubic),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerPos = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _chevronCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Overlay control ────────────────────────────────────────────
  void _toggle() {
    HapticFeedback.lightImpact();
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final renderBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = _buildOverlay(offset, size);
    Overlay.of(context).insert(_overlayEntry!);
    _chevronCtrl.forward();
    setState(() => _isOpen = true);
  }

  void _close() {
    _removeOverlay();
    _chevronCtrl.reverse();
    setState(() => _isOpen = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _select(String value) {
    widget.onChanged(value);
    _close();
    HapticFeedback.selectionClick();
  }

  // ── Overlay builder ────────────────────────────────────────────
  OverlayEntry _buildOverlay(Offset triggerOffset, Size triggerSize) {
    return OverlayEntry(
      builder: (ctx) => _DropdownOverlay(
        triggerOffset: triggerOffset,
        triggerWidth: triggerSize.width,
        selectedValue: widget.selectedValue,
        onSelect: _select,
        onDismiss: _close,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedValue != null
        ? RoleConfig.fromValue(widget.selectedValue!)
        : null;

    return GestureDetector(
      key: _triggerKey,
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 62.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: _isOpen
                ? (selected?.color ?? widget.accentColor).withOpacity(0.5)
                : selected != null
                    ? selected.color.withOpacity(0.25)
                    : const Color(0xFFE5E7EB),
            width: _isOpen ? 2 : 1.5,
          ),
          boxShadow: _isOpen
              ? [
                  BoxShadow(
                    color: (selected?.color ?? widget.accentColor)
                        .withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Shimmer sweep (only when no selection)
            if (selected == null)
              AnimatedBuilder(
                animation: _shimmerPos,
                builder: (_, __) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(_shimmerPos.value - 0.5, 0),
                          end: Alignment(_shimmerPos.value + 0.5, 0),
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ).createShader(bounds);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Left accent bar (when selected)
            if (selected != null)
              Positioned(
                left: 0,
                top: 8.h,
                bottom: 8.h,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: selected.color,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.r),
                      bottomLeft: Radius.circular(18.r),
                      topRight: Radius.circular(4.r),
                      bottomRight: Radius.circular(4.r),
                    ),
                  ),
                ),
              ),

            // Main content row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  // Icon container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: selected != null
                          ? selected.color.withOpacity(0.1)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(11.r),
                    ),
                    child: Icon(
                      selected?.icon ?? Icons.badge_outlined,
                      color: selected?.color ?? const Color(0xFFD1D5DB),
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Text stack
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected != null ? 'Staff Role' : 'Select Role',
                          style: TextStyle(
                            color: selected != null
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFFD1D5DB),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            selected?.label ?? 'Choose access level',
                            key: ValueKey(selected?.value ?? '__empty__'),
                            style: TextStyle(
                              color: selected != null
                                  ? const Color(0xFF111827)
                                  : const Color(0xFF9CA3AF),
                              fontSize: 14.sp,
                              fontWeight: selected != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tag pill (when selected)
                  if (selected != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: selected.light,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: selected.border),
                      ),
                      child: Text(
                        selected.tag,
                        style: TextStyle(
                          color: selected.color,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                  ],

                  // Chevron
                  RotationTransition(
                    turns: _chevronAngle,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: selected?.color ?? const Color(0xFFD1D5DB),
                      size: 22.sp,
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
//  DROPDOWN OVERLAY PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownOverlay extends StatefulWidget {
  final Offset triggerOffset;
  final double triggerWidth;
  final String? selectedValue;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.triggerOffset,
    required this.triggerWidth,
    required this.selectedValue,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_DropdownOverlay> createState() => _DropdownOverlayState();
}

class _DropdownOverlayState extends State<_DropdownOverlay>
    with TickerProviderStateMixin {
  late AnimationController _panelCtrl;
  late Animation<double> _panelScale;
  late Animation<double> _panelFade;
  late List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _panelScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic),
    );
    _panelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _panelCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _itemCtrls = List.generate(
      RoleConfig.all.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      ),
    );

    _panelCtrl.forward().then((_) {
      for (int i = 0; i < _itemCtrls.length; i++) {
        Future.delayed(Duration(milliseconds: i * 60), () {
          if (mounted) _itemCtrls[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.triggerOffset.dy + 70.h;
    final left = widget.triggerOffset.dx;
    final width = widget.triggerWidth;

    return Stack(
      children: [
        // Dismiss layer
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Panel
        Positioned(
          top: top,
          left: left,
          width: width,
          child: FadeTransition(
            opacity: _panelFade,
            child: ScaleTransition(
              scale: _panelScale,
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Panel header
                        _PanelHeader(),

                        // Role items
                        ...RoleConfig.all.asMap().entries.map((entry) {
                          final i = entry.key;
                          final role = entry.value;
                          final isSelected =
                              widget.selectedValue == role.value;
                          final isLast = i == RoleConfig.all.length - 1;

                          return AnimatedBuilder(
                            animation: _itemCtrls[i],
                            builder: (_, child) {
                              final t = _itemCtrls[i].value;
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, 12 * (1 - t)),
                                  child: child,
                                ),
                              );
                            },
                            child: _RoleItem(
                              role: role,
                              isSelected: isSelected,
                              isLast: isLast,
                              onTap: () => widget.onSelect(role.value),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PANEL HEADER (subtle label inside the dropdown)
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 22.w,
            height: 22.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Icon(
              Icons.manage_accounts_rounded,
              size: 13.sp,
              color: const Color(0xFF1B4332),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'ASSIGN ACCESS LEVEL',
            style: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            '${RoleConfig.all.length} roles',
            style: TextStyle(
              color: const Color(0xFFD1D5DB),
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INDIVIDUAL ROLE ITEM INSIDE DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _RoleItem extends StatefulWidget {
  final RoleConfig role;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _RoleItem({
    required this.role,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_RoleItem> createState() => _RoleItemState();
}

class _RoleItemState extends State<_RoleItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final selected = widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, widget.isLast ? 8.h : 0),
        decoration: BoxDecoration(
          color: selected
              ? role.color
              : _hovered
                  ? role.light
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              // Icon with layered rings on selection
              Stack(
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.2)
                          : role.light,
                      borderRadius: BorderRadius.circular(11.r),
                    ),
                    child: Icon(
                      role.icon,
                      color: selected ? Colors.white : role.color,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          role.label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withOpacity(0.2)
                                : role.light,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            role.tag,
                            style: TextStyle(
                              color: selected ? Colors.white : role.color,
                              fontSize: 7.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      role.caption,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withOpacity(0.65)
                            : const Color(0xFF9CA3AF),
                        fontSize: 11.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // Checkmark or arrow
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? Container(
                        key: const ValueKey('check'),
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: role.color,
                          size: 14.sp,
                        ),
                      )
                    : Icon(
                        key: const ValueKey('arrow'),
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFD1D5DB),
                        size: 18.sp,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
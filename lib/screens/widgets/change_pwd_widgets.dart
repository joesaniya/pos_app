// lib/screens/widgets/change_password_widgets.dart

import 'package:flutter/material.dart';
import 'package:pos_app/providers/change_pwd_provider.dart';

// ─── Design tokens — light theme, matches app's 0xFFF3F3FA world ─────────────
class CpColors {
  // Backgrounds
  static const pageBg      = Color(0xFFF3F3FA); // matches profile screen
  static const cardBg      = Color(0xFFFFFFFF);
  static const inputBg     = Color(0xFFF7F7FC);
  static const inputBgFocus = Color(0xFFFFFFFF);

  // Borders
  static const border      = Color(0xFFE8E8F2);
  static const borderFocus = Color(0xFF4F46E5); // matches app indigo

  // Accent — app's primary indigo
  static const accent      = Color(0xFF4F46E5);
  static const accentLight = Color(0xFFEEEDFD);
  static const accentMid   = Color(0xFF6366F1);

  // Semantic
  static const success     = Color(0xFF16A34A);
  static const successBg   = Color(0xFFF0FDF4);
  static const successBorder = Color(0xFFBBF7D0);
  static const error       = Color(0xFFDC2626);
  static const errorBg     = Color(0xFFFEF2F2);
  static const errorBorder = Color(0xFFFECACA);
  static const warning     = Color(0xFFD97706);
  static const warningBg   = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSub     = Color(0xFF6B6B8A);
  static const textMuted   = Color(0xFFAAAAAC);

  // Strength colours
  static const strengthWeak   = Color(0xFFEF4444);
  static const strengthFair   = Color(0xFFF97316);
  static const strengthGood   = Color(0xFFEAB308);
  static const strengthStrong = Color(0xFF22C55E);
}

// ─── 1. Password field ────────────────────────────────────────────────────────
class CpPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;
  final void Function(String)? onChanged;
  final Color accentColor;
  final IconData leadIcon;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const CpPasswordField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.validator,
    this.onChanged,
    this.accentColor = CpColors.accent,
    this.leadIcon = Icons.lock_outline_rounded,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  }) : super(key: key);

  @override
  State<CpPasswordField> createState() => _CpPasswordFieldState();
}

class _CpPasswordFieldState extends State<CpPasswordField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode!.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _focused ? widget.accentColor : CpColors.textSub,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),

        // Field container with animated border
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? CpColors.inputBgFocus : CpColors.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused
                  ? widget.accentColor.withOpacity(0.7)
                  : CpColors.border,
              width: _focused ? 1.5 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: !widget.isVisible,
            onChanged: widget.onChanged,
            validator: widget.validator,
            textInputAction: widget.textInputAction,
            style: const TextStyle(
              color: CpColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: widget.accentColor,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: CpColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0, vertical: 16,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 14, right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _focused
                      ? widget.accentColor.withOpacity(0.10)
                      : CpColors.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  widget.leadIcon,
                  color: _focused ? widget.accentColor : CpColors.textMuted,
                  size: 16,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: GestureDetector(
                onTap: widget.onToggleVisibility,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      widget.isVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(widget.isVisible),
                      color: widget.isVisible
                          ? widget.accentColor.withOpacity(0.7)
                          : CpColors.textMuted,
                      size: 19,
                    ),
                  ),
                ),
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),

        // Inline error — shown below the field
        Builder(builder: (context) {
          return const SizedBox.shrink(); // handled by Form validator
        }),
      ],
    );
  }
}

// ─── 2. Strength meter ────────────────────────────────────────────────────────
class CpStrengthMeter extends StatelessWidget {
  final PasswordStrength strength;
  const CpStrengthMeter({Key? key, required this.strength}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    return Column(
      children: [
        // 4-segment bar
        Row(
          children: List.generate(4, (i) {
            final filled = (strength.fraction * 4).ceil() > i;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: filled ? strength.color : CpColors.border,
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: strength.color.withOpacity(0.35),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password strength',
              style: TextStyle(
                color: CpColors.textMuted,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                strength.label,
                key: ValueKey(strength),
                style: TextStyle(
                  color: strength.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 3. Requirements checklist ────────────────────────────────────────────────
class CpChecklist extends StatelessWidget {
  final bool hasMin, hasUpper, hasLower, hasNumber, hasSpecial;

  const CpChecklist({
    Key? key,
    required this.hasMin,
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSpecial,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CpColors.accentLight.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CpColors.accent.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Row(children: [
            _Tile(label: '8+ characters', checked: hasMin),
            const SizedBox(width: 8),
            _Tile(label: 'Uppercase (A–Z)', checked: hasUpper),
          ]),
          const SizedBox(height: 7),
          Row(children: [
            _Tile(label: 'Lowercase (a–z)', checked: hasLower),
            const SizedBox(width: 8),
            _Tile(label: 'Number (0–9)', checked: hasNumber),
          ]),
          const SizedBox(height: 7),
          Row(children: [
            _Tile(label: 'Special (!@#…)', checked: hasSpecial),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final bool checked;
  const _Tile({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: checked ? CpColors.successBg : CpColors.cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: checked ? CpColors.successBorder : CpColors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? CpColors.success : Colors.transparent,
                border: Border.all(
                  color: checked ? CpColors.success : CpColors.border,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 9)
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: checked ? CpColors.success : CpColors.textMuted,
                  fontSize: 10.5,
                  fontWeight:
                      checked ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 4. Submit button ─────────────────────────────────────────────────────────
class CpSubmitButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const CpSubmitButton({
    Key? key,
    required this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<CpSubmitButton> createState() => _CpSubmitButtonState();
}

class _CpSubmitButtonState extends State<CpSubmitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Update Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── 5. Section divider ───────────────────────────────────────────────────────
class CpSectionDivider extends StatelessWidget {
  final String label;
  const CpSectionDivider({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, CpColors.border],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: CpColors.accentLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CpColors.accent.withOpacity(0.15)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: CpColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [CpColors.border, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 6. Error banner ──────────────────────────────────────────────────────────
class CpErrorBanner extends StatelessWidget {
  final String message;
  const CpErrorBanner({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CpColors.errorBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: CpColors.errorBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CpColors.error.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: CpColors.error, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: CpColors.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 7. Security tip ──────────────────────────────────────────────────────────
class CpTipCard extends StatelessWidget {
  const CpTipCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CpColors.warningBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: CpColors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CpColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tips_and_updates_outlined,
                color: CpColors.warning, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Use a mix of uppercase, lowercase, numbers and symbols. Avoid personal info like your name or birthday.',
              style: TextStyle(
                color: CpColors.warning.withOpacity(0.85),
                fontSize: 11.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 8. Background — light with soft geometric decoration ────────────────────
class CpBackground extends StatelessWidget {
  const CpBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Page base colour
        Container(color: CpColors.pageBg),

        // Top-right indigo arc
        Positioned(
          top: -140,
          right: -100,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom-left lavender tint
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF818CF8).withOpacity(0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Subtle dot grid
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.04)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── 9. Success overlay ───────────────────────────────────────────────────────
class CpSuccessView extends StatefulWidget {
  final VoidCallback onDone;
  const CpSuccessView({Key? key, required this.onDone}) : super(key: key);

  @override
  State<CpSuccessView> createState() => _CpSuccessViewState();
}

class _CpSuccessViewState extends State<CpSuccessView>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _iconCtrl;
  late AnimationController _textCtrl;

  late Animation<double> _bgFade;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _bgFade   = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut));
    _iconScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 24, end: 0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Sequence
    _bgCtrl.forward().then((_) {
      _iconCtrl.forward().then((_) => _textCtrl.forward());
    });

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _iconCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _bgFade,
      child: Container(
        color: CpColors.pageBg.withOpacity(0.97),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with ring
              ScaleTransition(
                scale: _iconScale,
                child: FadeTransition(
                  opacity: _iconFade,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CpColors.success.withOpacity(0.07),
                          border: Border.all(
                            color: CpColors.success.withOpacity(0.20),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Inner circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CpColors.successBg,
                          border: Border.all(
                            color: CpColors.successBorder,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CpColors.success.withOpacity(0.20),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: CpColors.success,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Text content
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Opacity(opacity: _textFade.value, child: child),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Password Updated!',
                      style: TextStyle(
                        color: CpColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account is now secured\nwith the new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CpColors.textSub,
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: CpColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: CpColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: CpColors.accent.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Returning to settings…',
                            style: TextStyle(
                              color: CpColors.textSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }
}
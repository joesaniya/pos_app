import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/models/onboard_data.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE — Warm Ivory / Slate / Gold editorial theme
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const ivory = Color(0xFFFAF8F4);
  static const cream = Color(0xFFF2EDE4);
  static const warmWhite = Color(0xFFFFFFFF);
  static const slate = Color(0xFF1C2333);
  static const slateLight = Color(0xFF2E3A52);
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFE8C96D);
  static const muted = Color(0xFF8A94A8);
  static const line = Color(0xFFE4DDD3);
  static const cardBg = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE DATA — extended for this design
// ─────────────────────────────────────────────────────────────────────────────
class _PageMeta {
  final String number;
  final String eyebrow;
  final String titleLine1;
  final String titleLine2;
  final String body;
  final Color accent;
  final Color accentSoft;
  final IconData icon;
  final List<_StatItem> stats;

  const _PageMeta({
    required this.number,
    required this.eyebrow,
    required this.titleLine1,
    required this.titleLine2,
    required this.body,
    required this.accent,
    required this.accentSoft,
    required this.icon,
    required this.stats,
  });
}

class _StatItem {
  final String value;
  final String label;
  const _StatItem(this.value, this.label);
}

const _pages = [
  _PageMeta(
    number: '01',
    eyebrow: 'POINT OF SALE',
    titleLine1: 'Smart',
    titleLine2: 'Checkout',
    body:
        'Lightning-fast transactions with real-time inventory sync. Every sale tracked, every moment optimised for your team.',
    accent: Color(0xFF4F6EF7),
    accentSoft: Color(0xFFECEFFE),
    icon: Icons.point_of_sale_rounded,
    stats: [
      _StatItem('3×', 'Faster checkout'),
      _StatItem('99.9%', 'Uptime'),
      _StatItem('0s', 'Lag'),
    ],
  ),
  _PageMeta(
    number: '02',
    eyebrow: 'ANALYTICS',
    titleLine1: 'Real-time',
    titleLine2: 'Insights',
    body:
        'Live dashboards and trend forecasting that transform raw numbers into decisions. Know your business before it knows itself.',
    accent: Color(0xFF0EA472),
    accentSoft: Color(0xFFE8F8F3),
    icon: Icons.insights_rounded,
    stats: [
      _StatItem('24/7', 'Live data'),
      _StatItem('50+', 'Metrics'),
      _StatItem('AI', 'Powered'),
    ],
  ),
  _PageMeta(
    number: '03',
    eyebrow: 'TEAM MANAGEMENT',
    titleLine1: 'Seamless',
    titleLine2: 'Collaboration',
    body:
        'Assign roles, track performance, and empower every team member with the tools they need to deliver exceptional service.',
    accent: Color(0xFFC9A84C),
    accentSoft: Color(0xFFFBF5E6),
    icon: Icons.groups_2_rounded,
    stats: [
      _StatItem('∞', 'Team size'),
      _StatItem('6', 'Roles'),
      _StatItem('100%', 'Control'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  ONBOARDING SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;

  // Per-page stagger controllers
  late List<AnimationController> _pageCtrl;
  late List<Animation<double>> _eyebrowFade;
  late List<Animation<Offset>> _titleSlide;
  late List<Animation<double>> _titleFade;
  late List<Animation<Offset>> _bodySlide;
  late List<Animation<double>> _bodyFade;
  late List<Animation<double>> _statsFade;
  late List<Animation<Offset>> _statsSlide;
  late List<Animation<double>> _illustrationScale;
  late List<Animation<double>> _illustrationFade;

  // Global ambient animation
  late AnimationController _ambientCtrl;
  late Animation<double> _ambientAnim;

  // Button press
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  // Page transition overlay
  late AnimationController _overlayCtrl;
  late Animation<double> _overlayAnim;
  Color _overlayColor = _pages[0].accent;

  @override
  void initState() {
    super.initState();
    // Setup animations synchronously — BEFORE any build can reference them.
    // We use _pages.length directly so we never depend on context here.
    _pageController = PageController(initialPage: 0);
    _setupAnimations(_pages.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OnboardingProvider>();
      // Sync controller to provider state (in case provider already has a page)
      if (provider.currentPage != 0) {
        _pageController.jumpToPage(provider.currentPage);
      }
      _playPage(provider.currentPage);
    });
  }

  void _setupAnimations(int count) {
    _pageCtrl = List.generate(
      count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 950),
      ),
    );

    CurvedAnimation _cv(
      AnimationController c,
      double s,
      double e, [
      Curve curve = Curves.easeOutCubic,
    ]) => CurvedAnimation(
      parent: c,
      curve: Interval(s, e, curve: curve),
    );

    _eyebrowFade = _pageCtrl
        .map((c) => Tween<double>(begin: 0, end: 1).animate(_cv(c, 0.0, 0.3)))
        .toList();

    _titleSlide = _pageCtrl
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(_cv(c, 0.15, 0.55)),
        )
        .toList();

    _titleFade = _pageCtrl
        .map((c) => Tween<double>(begin: 0, end: 1).animate(_cv(c, 0.15, 0.5)))
        .toList();

    _bodySlide = _pageCtrl
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_cv(c, 0.35, 0.72)),
        )
        .toList();

    _bodyFade = _pageCtrl
        .map((c) => Tween<double>(begin: 0, end: 1).animate(_cv(c, 0.35, 0.68)))
        .toList();

    _statsFade = _pageCtrl
        .map((c) => Tween<double>(begin: 0, end: 1).animate(_cv(c, 0.55, 0.90)))
        .toList();

    _statsSlide = _pageCtrl
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(_cv(c, 0.55, 0.88)),
        )
        .toList();

    _illustrationScale = _pageCtrl
        .map(
          (c) => Tween<double>(
            begin: 0.72,
            end: 1.0,
          ).animate(_cv(c, 0.0, 0.60, Curves.elasticOut)),
        )
        .toList();

    _illustrationFade = _pageCtrl
        .map((c) => Tween<double>(begin: 0, end: 1).animate(_cv(c, 0.0, 0.30)))
        .toList();

    // Ambient float
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _ambientAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ambientCtrl, curve: Curves.easeInOut));

    // Button
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _btnScale = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    // Overlay flash on page change
    _overlayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _overlayAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _overlayCtrl, curve: Curves.easeOut));
  }

  void _playPage(int index) {
    _pageCtrl[index]
      ..reset()
      ..forward();
  }

  Future<void> _flashOverlay(int newPage) async {
    _overlayColor = _pages[newPage % _pages.length].accent;
    await _overlayCtrl.forward();
    _overlayCtrl.reverse();
  }

  void _onPageChanged(int index) {
    context.read<OnboardingProvider>().onPageChanged(index);
    _playPage(index);
    _flashOverlay(index);
  }

  void _onNext() {
    final prov = context.read<OnboardingProvider>();
    if (prov.isLastPage) {
      prov.requestNavigateAway();
      _goLogin();
    } else {
      if (prov.goToNextPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _onBack() {
    if (context.read<OnboardingProvider>().goToPreviousPage()) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onSkip() {
    context.read<OnboardingProvider>().requestNavigateAway();
    _goLogin();
  }

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            FadeTransition(opacity: anim, child: LoginScreen()),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _pageCtrl) {
      c.dispose();
    }
    _ambientCtrl.dispose();
    _btnCtrl.dispose();
    _overlayCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Consumer<OnboardingProvider>(
        builder: (context, prov, _) {
          final meta = _pages[prov.currentPage % _pages.length];
          return Scaffold(
            backgroundColor: _C.ivory,
            body: Stack(
              children: [
                // ── Ambient background ───────────────────────
                _AmbientBackground(anim: _ambientAnim, accent: meta.accent),

                // ── Main layout ─────────────────────────────
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(prov: prov, onSkip: _onSkip),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemCount: prov.totalPages,
                          itemBuilder: (_, i) => _PageContent(
                            index: i,
                            meta: _pages[i % _pages.length],
                            ambientAnim: _ambientAnim,
                            eyebrowFade: _eyebrowFade[i],
                            titleSlide: _titleSlide[i],
                            titleFade: _titleFade[i],
                            bodySlide: _bodySlide[i],
                            bodyFade: _bodyFade[i],
                            statsFade: _statsFade[i],
                            statsSlide: _statsSlide[i],
                            illustrationScale: _illustrationScale[i],
                            illustrationFade: _illustrationFade[i],
                          ),
                        ),
                      ),
                      _BottomSection(
                        prov: prov,
                        meta: meta,
                        btnScale: _btnScale,
                        btnCtrl: _btnCtrl,
                        onNext: _onNext,
                        onBack: _onBack,
                      ),
                    ],
                  ),
                ),

                // ── Page-change flash overlay ────────────────
                AnimatedBuilder(
                  animation: _overlayAnim,
                  builder: (_, __) => Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _overlayAnim.value * 0.07,
                        child: Container(color: _overlayColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AMBIENT BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientBackground extends StatelessWidget {
  final Animation<double> anim;
  final Color accent;
  const _AmbientBackground({required this.anim, required this.accent});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        return Stack(
          children: [
            // Base ivory
            Container(color: _C.ivory),

            // Large geometric shape — top right
            Positioned(
              top: -size.width * 0.18 + t * 12,
              right: -size.width * 0.10 + t * 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: size.width * 0.72,
                height: size.width * 0.72,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.055),
                  borderRadius: BorderRadius.circular(size.width * 0.20),
                ),
              ),
            ),

            // Secondary cream ellipse — bottom left
            Positioned(
              bottom: size.height * 0.08 - t * 10,
              left: -size.width * 0.12 + t * 6,
              child: Container(
                width: size.width * 0.55,
                height: size.width * 0.55,
                decoration: BoxDecoration(
                  color: _C.cream,
                  borderRadius: BorderRadius.circular(size.width * 0.28),
                ),
              ),
            ),

            // Fine diagonal line art
            Positioned.fill(
              child: CustomPaint(
                painter: _GeometricLinesPainter(accent: accent, t: t),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GEOMETRIC LINES PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _GeometricLinesPainter extends CustomPainter {
  final Color accent;
  final double t;
  const _GeometricLinesPainter({required this.accent, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withOpacity(0.06)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Diagonal crosshatch top-right quadrant
    for (int i = 0; i < 6; i++) {
      final offset = i * 28.0 + t * 4;
      canvas.drawLine(
        Offset(size.width - offset, 0),
        Offset(size.width, offset),
        paint,
      );
    }

    // Dot grid — subtle
    final dotPaint = Paint()..color = _C.slate.withOpacity(0.04);
    for (double x = 20; x < size.width; x += 32) {
      for (double y = 20; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
      }
    }

    // Single long horizontal rule — editorial detail
    canvas.drawLine(
      Offset(24, size.height * 0.72),
      Offset(size.width * 0.30, size.height * 0.72),
      Paint()
        ..color = _C.slate.withOpacity(0.08)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _GeometricLinesPainter old) =>
      old.t != t || old.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final OnboardingProvider prov;
  final VoidCallback onSkip;
  const _TopBar({required this.prov, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 0),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _C.slate,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text(
                'POS',
                style: TextStyle(
                  color: _C.warmWhite,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            'App',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w300,
              color: _C.slate,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: prov.isLastPage ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: prov.isLastPage ? null : onSkip,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _C.cream,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: _C.line),
                ),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _C.muted,
                    letterSpacing: 0.3,
                  ),
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
//  PAGE CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final int index;
  final _PageMeta meta;
  final Animation<double> ambientAnim;
  final Animation<double> eyebrowFade;
  final Animation<Offset> titleSlide;
  final Animation<double> titleFade;
  final Animation<Offset> bodySlide;
  final Animation<double> bodyFade;
  final Animation<double> statsFade;
  final Animation<Offset> statsSlide;
  final Animation<double> illustrationScale;
  final Animation<double> illustrationFade;

  const _PageContent({
    required this.index,
    required this.meta,
    required this.ambientAnim,
    required this.eyebrowFade,
    required this.titleSlide,
    required this.titleFade,
    required this.bodySlide,
    required this.bodyFade,
    required this.statsFade,
    required this.statsSlide,
    required this.illustrationScale,
    required this.illustrationFade,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28.h),

          // ── Illustration card ──────────────────────────────
          Center(
            child: FadeTransition(
              opacity: illustrationFade,
              child: ScaleTransition(
                scale: illustrationScale,
                child: _IllustrationCard(meta: meta, ambient: ambientAnim),
              ),
            ),
          ),

          SizedBox(height: 36.h),

          // ── Eyebrow label ──────────────────────────────────
          FadeTransition(
            opacity: eyebrowFade,
            child: Row(
              children: [
                Container(width: 20.w, height: 1.5, color: meta.accent),
                SizedBox(width: 8.w),
                Text(
                  meta.eyebrow,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: meta.accent,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // ── Title ──────────────────────────────────────────
          FadeTransition(
            opacity: titleFade,
            child: SlideTransition(
              position: titleSlide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.titleLine1,
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w800,
                      color: meta.accent,
                      height: 0.95,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    meta.titleLine2,
                    style: TextStyle(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w300,
                      color: _C.slate,
                      height: 1.05,
                      letterSpacing: -1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18.h),

          // ── Body text ──────────────────────────────────────
          FadeTransition(
            opacity: bodyFade,
            child: SlideTransition(
              position: bodySlide,
              child: Text(
                meta.body,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: _C.muted,
                  height: 1.7,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),

          SizedBox(height: 28.h),

          // ── Stats row ──────────────────────────────────────
          FadeTransition(
            opacity: statsFade,
            child: SlideTransition(
              position: statsSlide,
              child: _StatsRow(meta: meta),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ILLUSTRATION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IllustrationCard extends StatelessWidget {
  final _PageMeta meta;
  final Animation<double> ambient;
  const _IllustrationCard({required this.meta, required this.ambient});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambient,
      builder: (_, __) {
        final t = ambient.value;
        return Container(
          width: double.infinity,
          height: 220.h,
          decoration: BoxDecoration(
            color: meta.accentSoft,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: meta.accent.withOpacity(0.12), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Decorative ring 1
              Positioned(
                right: 24.w - t * 6,
                top: 24.h - t * 4,
                child: Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: meta.accent.withOpacity(0.12),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Decorative ring 2 (larger, faint)
              Positioned(
                left: 16.w + t * 5,
                bottom: 20.h + t * 3,
                child: Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: meta.accent.withOpacity(0.06),
                  ),
                ),
              ),

              // Small floating geometric shapes
              Positioned(
                top: 22.h + t * 8,
                left: 28.w,
                child: Transform.rotate(
                  angle: math.pi / 5 + t * 0.2,
                  child: Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.r),
                      color: meta.accent.withOpacity(0.15),
                    ),
                  ),
                ),
              ),

              // Page number — large editorial watermark
              Positioned(
                right: 20.w,
                bottom: 14.h,
                child: Text(
                  meta.number,
                  style: TextStyle(
                    fontSize: 52.sp,
                    fontWeight: FontWeight.w900,
                    color: meta.accent.withOpacity(0.07),
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
              ),

              // Main icon in a layered circle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LimitedBox(
                    maxHeight: 150.h,
                    child: Transform.translate(
                      offset: Offset(0, -t * 6),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 110.w,
                            height: 110.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: meta.accent.withOpacity(0.08),
                            ),
                          ),
                          // Inner circle
                          Container(
                            width: 84.w,
                            height: 84.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: meta.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: meta.accent.withOpacity(0.30),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              meta.icon,
                              size: 38.w,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Top-left accent stripe
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 5.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: meta.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28.r),
                      bottomRight: Radius.circular(4.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final _PageMeta meta;
  const _StatsRow({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: meta.stats.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 14.h,
                    horizontal: 10.w,
                  ),
                  decoration: BoxDecoration(
                    color: _C.warmWhite,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _C.line, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _C.slate.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.value,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: meta.accent,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          color: _C.muted,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              if (i < meta.stats.length - 1) SizedBox(width: 8.w),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _BottomSection extends StatelessWidget {
  final OnboardingProvider prov;
  final _PageMeta meta;
  final Animation<double> btnScale;
  final AnimationController btnCtrl;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _BottomSection({
    required this.prov,
    required this.meta,
    required this.btnScale,
    required this.btnCtrl,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 36.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Step indicators ─────────────────────────────────
          Expanded(
            child: Row(
              children: List.generate(prov.totalPages, (i) {
                final isActive = i == prov.currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(right: 6.w),
                  width: isActive ? 24.w : 6.w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3.r),
                    color: isActive
                        ? meta.accent
                        : meta.accent.withOpacity(0.20),
                  ),
                );
              }),
            ),
          ),

          // ── Back button ─────────────────────────────────────
          AnimatedOpacity(
            opacity: prov.isFirstPage ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            child: AnimatedSlide(
              offset: prov.isFirstPage ? const Offset(-0.25, 0) : Offset.zero,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: prov.isFirstPage ? null : onBack,
                child: Container(
                  width: 50.w,
                  height: 50.w,
                  margin: EdgeInsets.only(right: 12.w),
                  decoration: BoxDecoration(
                    color: _C.warmWhite,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _C.line),
                    boxShadow: [
                      BoxShadow(
                        color: _C.slate.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20.w,
                    color: _C.slate,
                  ),
                ),
              ),
            ),
          ),

          // ── Next / Get Started button ────────────────────────
          GestureDetector(
            onTapDown: (_) => btnCtrl.forward(),
            onTapUp: (_) {
              btnCtrl.reverse();
              onNext();
            },
            onTapCancel: () => btnCtrl.reverse(),
            child: ScaleTransition(
              scale: btnScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                decoration: BoxDecoration(
                  color: meta.accent,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: meta.accent.withOpacity(0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        prov.isLastPage ? 'Get Started' : 'Continue',
                        key: ValueKey(prov.isLastPage),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Icon(
                        prov.isLastPage
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        key: ValueKey(prov.isLastPage),
                        color: Colors.white,
                        size: 18.w,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

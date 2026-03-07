import 'dart:math' as math;
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/splash_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/onboarding_screen.dart';
import 'package:pos_app/screens/page_switcher.dart';
import 'package:pos_app/screens/subscription_expired_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF5F8FF);
  static const white = Color(0xFFFFFFFF);
  static const royal = Color(0xFF1847C4);
  static const royalLt = Color(0xFF3B6FE8);
  static const royalSoft = Color(0xFFEBF0FF);
  static const ink = Color(0xFF0D1B3E);
  static const muted = Color(0xFF8C9AB8);
  static const accent = Color(0xFF00C9A7); // teal pop
  static const accentLt = Color(0xFFE0FAF5);
  static const amber = Color(0xFFF59E0B);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  late final AnimationController _bgCtrl; // background shapes drift
  late final AnimationController _entryCtrl; // logo + text stagger in
  late final AnimationController _pulseCtrl; // ring pulse
  late final AnimationController _exitCtrl; // slide-up exit

  // ── Background float animations ───────────────────────────────
  late final Animation<double> _shape1X;
  late final Animation<double> _shape1Y;
  late final Animation<double> _shape2X;
  late final Animation<double> _shape2Y;
  late final Animation<double> _shape3Rot;

  // ── Entry animations ──────────────────────────────────────────
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _pillSlide;
  late final Animation<double> _pillOpacity;
  late final Animation<double> _loaderOpacity;

  // ── Pulse ─────────────────────────────────────────────────────
  late final Animation<double> _pulse;

  // ── Exit ──────────────────────────────────────────────────────
  late final Animation<Offset> _exitSlide;
  late final Animation<double> _exitFade;

  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  void _setupAnimations() {
    // ── Background shapes — slow continuous drift ──────────────
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _shape1X = Tween<double>(
      begin: -10,
      end: 14,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));
    _shape1Y = Tween<double>(begin: -8, end: 12).animate(
      CurvedAnimation(
        parent: _bgCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    _shape2X = Tween<double>(begin: 10, end: -18).animate(
      CurvedAnimation(
        parent: _bgCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOut),
      ),
    );
    _shape2Y = Tween<double>(
      begin: 6,
      end: -14,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));
    _shape3Rot = Tween<double>(
      begin: 0,
      end: math.pi / 5,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));

    // ── Entry stagger ──────────────────────────────────────────
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Ring expands in from 0 → 1
    _ringScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      ),
    );
    _ringOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Logo pops in slightly after ring
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
      ),
    );

    // Title slides up
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.40, 0.70, curve: Curves.easeOutCubic),
          ),
        );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.40, 0.65, curve: Curves.easeOut),
      ),
    );

    // Subtitle slides up after
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.52, 0.80, curve: Curves.easeOutCubic),
          ),
        );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.52, 0.75, curve: Curves.easeOut),
      ),
    );

    // Feature pills
    _pillSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.64, 0.90, curve: Curves.easeOutCubic),
          ),
        );
    _pillOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.64, 0.85, curve: Curves.easeOut),
      ),
    );

    // Loader fades in last
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );

    _entryCtrl.forward();

    // ── Pulse ring ────────────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false);
    _pulse = Tween<double>(
      begin: 0.88,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Exit ──────────────────────────────────────────────────
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.0),
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  Future<void> _initializeApp() async {
    final splashProvider = context.read<SplashProvider>();
    final authProvider = context.read<AppAuthenticationProvider>();
    await splashProvider.initializeApp(authProvider: authProvider);
    if (!mounted) return;

    // Ensure entry animation finishes before exit
    if (_entryCtrl.value < 1.0) {
      await _entryCtrl.forward();
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => _exiting = true);
    await _exitCtrl.forward();
    if (!mounted) return;

    log(
      'Splash done. firstLaunch=${splashProvider.isFirstLaunch} loggedIn=${splashProvider.isLoggedIn} subscriptionExpired=${splashProvider.subscriptionExpired}',
    );

    if (splashProvider.isFirstLaunch) {
      _navigate(const OnboardingScreen());
    } else if (splashProvider.subscriptionExpired) {
      // Subscription expired — show the renewal screen, do NOT go to home.
      _navigate(const SubscriptionExpiredScreen());
    } else if (splashProvider.isLoggedIn) {
      _navigate(const PageSwitcher());
    } else {
      _navigate(const LoginScreen());
    }
  }

  void _navigate(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgCtrl,
          _entryCtrl,
          _pulseCtrl,
          _exitCtrl,
        ]),
        builder: (_, __) {
          return SlideTransition(
            position: _exitSlide,
            child: FadeTransition(
              opacity: _exiting ? _exitFade : const AlwaysStoppedAnimation(1.0),
              child: Stack(
                children: [
                  // ── Background ──────────────────────────────────────────
                  _buildBackground(size),

                  // ── Main Content ────────────────────────────────────────
                  SafeArea(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _buildLogoSection(),
                        const SizedBox(height: 36),
                        _buildTextSection(),
                        const SizedBox(height: 28),
                        _buildFeaturePills(),
                        const Spacer(flex: 3),
                        _buildBottomSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── BACKGROUND ────────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return Stack(
      children: [
        // Base
        Container(color: _C.bg),

        // Large royal blob — top right
        Positioned(
          top: -size.width * 0.32,
          right: -size.width * 0.22,
          child: Transform.translate(
            offset: Offset(_shape1X.value, _shape1Y.value),
            child: Container(
              width: size.width * 0.90,
              height: size.width * 0.90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _C.royal.withOpacity(0.13),
                    _C.royalLt.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Medium accent blob — bottom left
        Positioned(
          bottom: -size.width * 0.25,
          left: -size.width * 0.18,
          child: Transform.translate(
            offset: Offset(_shape2X.value, _shape2Y.value),
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _C.accent.withOpacity(0.10),
                    _C.accent.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Rotating geometric diamond — top left
        Positioned(
          top: size.height * 0.08,
          left: -30,
          child: Transform.rotate(
            angle: _shape3Rot.value,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _C.royal.withOpacity(0.09),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Small rotated square — bottom right
        Positioned(
          bottom: size.height * 0.14,
          right: 20,
          child: Transform.rotate(
            angle: -_shape3Rot.value * 0.7,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _C.amber.withOpacity(0.08),
                border: Border.all(
                  color: _C.amber.withOpacity(0.18),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),

        // Tiny dot grid pattern
        Positioned.fill(child: CustomPaint(painter: _DotGrid())),

        // Horizontal accent line
        Positioned(
          top: size.height * 0.13,
          left: size.width * 0.06,
          right: size.width * 0.55,
          child: Opacity(
            opacity: 0.12,
            child: Container(height: 1.5, color: _C.royal),
          ),
        ),
      ],
    );
  }

  // ── LOGO SECTION ──────────────────────────────────────────────
  Widget _buildLogoSection() {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          ScaleTransition(
            scale: _pulse,
            child: Opacity(
              opacity: 0.18,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.royal, width: 1.5),
                ),
              ),
            ),
          ),

          // Decorative ring
          ScaleTransition(
            scale: _ringScale,
            child: Opacity(
              opacity: _ringOpacity.value,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _C.royal.withOpacity(0.0),
                      _C.royal.withOpacity(0.18),
                      _C.royalLt.withOpacity(0.30),
                      _C.royal.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Logo card
          ScaleTransition(
            scale: _logoScale,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _C.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _C.royal.withOpacity(0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: _C.royal.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(48, 48),
                    painter: _POSLogoPainter(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TEXT SECTION ──────────────────────────────────────────────
  Widget _buildTextSection() {
    return Column(
      children: [
        // App name
        SlideTransition(
          position: _titleSlide,
          child: Opacity(
            opacity: _titleOpacity.value,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'POS',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w900,
                      color: _C.royal,
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' App',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w300,
                      color: _C.ink,
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Tagline
        SlideTransition(
          position: _subtitleSlide,
          child: Opacity(
            opacity: _subtitleOpacity.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 20, height: 1.5, color: _C.accent),
                const SizedBox(width: 8),
                Text(
                  'Smart. Simple. Seamless.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: _C.muted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 20, height: 1.5, color: _C.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── FEATURE PILLS ─────────────────────────────────────────────
  Widget _buildFeaturePills() {
    final pills = [
      ('Orders', Icons.receipt_long_rounded, _C.royal),
      ('Tables', Icons.table_restaurant_rounded, _C.accent),
      ('Reports', Icons.bar_chart_rounded, _C.amber),
    ];

    return SlideTransition(
      position: _pillSlide,
      child: Opacity(
        opacity: _pillOpacity.value,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: pills.asMap().entries.map((e) {
            final idx = e.key;
            final pill = e.value;
            return Padding(
              padding: EdgeInsets.only(right: idx < pills.length - 1 ? 10 : 0),
              child: _FeaturePill(
                label: pill.$1,
                icon: pill.$2,
                color: pill.$3,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── BOTTOM SECTION ────────────────────────────────────────────
  Widget _buildBottomSection() {
    return Opacity(
      opacity: _loaderOpacity.value,
      child: Consumer<SplashProvider>(
        builder: (_, provider, __) {
          return Column(
            children: [
              if (provider.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCCCC)),
                    ),
                    child: Text(
                      provider.errorMessage,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFFCC2222),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                // Custom segmented loader
                _SegmentedLoader(),
                const SizedBox(height: 14),
                Text(
                  'Initialising your workspace…',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _C.muted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // Version badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _C.royalSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.royal.withOpacity(0.14)),
                ),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _C.royal.withOpacity(0.65),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FEATURE PILL
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _FeaturePill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.20), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEGMENTED LOADER — 4 animated dots
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentedLoader extends StatefulWidget {
  @override
  State<_SegmentedLoader> createState() => _SegmentedLoaderState();
}

class _SegmentedLoaderState extends State<_SegmentedLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _scales = List.generate(4, (i) {
      final start = i * 0.20;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          final colors = [_C.royal, _C.royalLt, _C.accent, _C.amber];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: _scales[i].value,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i].withOpacity(0.25 + _scales[i].value * 0.75),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM POS LOGO PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _POSLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer ring segment — royal
    paint.color = _C.royal;
    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: size.width * 0.46,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.4,
      false,
      Paint()
        ..color = _C.royal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Outer ring segment — accent (teal)
    canvas.drawArc(
      rect,
      -math.pi / 2 + math.pi * 1.4,
      math.pi * 0.6,
      false,
      Paint()
        ..color = _C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Centre square — represents a POS terminal screen
    final squareSize = size.width * 0.34;
    final squareRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy - size.height * 0.04),
        width: squareSize,
        height: squareSize * 0.76,
      ),
      const Radius.circular(4),
    );
    paint.color = _C.royal;
    canvas.drawRRect(squareRect, paint);

    // Small stand
    paint.color = _C.royalLt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.20),
          width: squareSize * 0.45,
          height: size.height * 0.055,
        ),
        const Radius.circular(3),
      ),
      paint,
    );

    // Screen glare line
    canvas.drawLine(
      Offset(cx - squareSize * 0.22, cy - size.height * 0.14),
      Offset(cx - squareSize * 0.05, cy - size.height * 0.14),
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Accent dot
    paint.color = _C.accent;
    canvas.drawCircle(
      Offset(cx + squareSize * 0.30, cy - size.height * 0.30),
      3.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  DOT GRID PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _C.royal.withOpacity(0.04);
    for (double x = 0; x < size.width; x += 26) {
      for (double y = 0; y < size.height; y += 26) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  COLOUR CONSTANTS (mirrors profile_screen palette)
// ─────────────────────────────────────────────────────────────────────────────
// These are defined at the top of the file in class _C.
// Import your AppColors if you prefer — the values below match:
//   bg       = 0xFFF5F8FF
//   royal    = 0xFF1847C4
//   royalLt  = 0xFF3B6FE8
//   royalSoft= 0xFFEBF0FF
//   ink      = 0xFF0D1B3E
//   muted    = 0xFF8C9AB8
//   accent   = 0xFF00C9A7
//   amber    = 0xFFF59E0B

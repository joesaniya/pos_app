import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_app/providers/change_pwd_provider.dart';
import 'package:pos_app/screens/widgets/change_pwd_widgets.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  late AnimationController _entryCtrl;
  late List<Animation<Offset>> _slides;
  late List<Animation<double>> _fades;

  static const int _n = 6; // number of staggered elements

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _slides = List.generate(_n, (i) {
      final s = (i * 0.10).clamp(0.0, 0.5);
      final e = (s + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic),
        ),
      );
    });
    _fades = List.generate(_n, (i) {
      final s = (i * 0.10).clamp(0.0, 0.5);
      final e = (s + 0.40).clamp(0.0, 1.0);
      return Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: _entryCtrl, curve: Interval(s, e)));
    });
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Widget _a(int i, Widget child) => SlideTransition(
    position: _slides[i],
    child: FadeTransition(opacity: _fades[i], child: child),
  );

  Future<void> _submit(ChangePasswordProvider provider) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await provider.submit(
      currentPassword: _currentPwdCtrl.text,
      newPassword: _newPwdCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChangePasswordProvider(),
      child: Consumer<ChangePasswordProvider>(
        builder: (context, provider, _) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  Brightness.dark, // dark icons on light bg
            ),
            child: Scaffold(
              backgroundColor: CpColors.pageBg,
              body: Stack(
                children: [
                  // ── Background ───────────────────────────────
                  const CpBackground(),

                  // ── Scrollable content ───────────────────────
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Top bar ──────────────────────
                            _a(0, _TopBar()),
                            const SizedBox(height: 28),

                            // ── Card containing all fields ───
                            _a(1, _buildCard(provider)),

                            const SizedBox(height: 20),

                            // ── Tip ──────────────────────────
                            _a(5, const CpTipCard()),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Success overlay ──────────────────────────
                  if (provider.step == CpStep.success)
                    CpSuccessView(
                      onDone: () {
                        provider.reset();
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── White card that holds the entire form ──────────────────────────────────
  Widget _buildCard(ChangePasswordProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: CpColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CpColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ────────────────────────────────────
          _a(1, _buildCardHeader()),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Error banner ───────────────────────────
                if (provider.errorMessage.isNotEmpty) ...[
                  _a(1, CpErrorBanner(message: provider.errorMessage)),
                  const SizedBox(height: 20),
                ],

                // ── Current password ───────────────────────
                _a(
                  2,
                  CpPasswordField(
                    controller: _currentPwdCtrl,
                    label: 'CURRENT PASSWORD',
                    hint: 'Enter your current password',
                    isVisible: provider.currentVisible,
                    onToggleVisibility: provider.toggleCurrentVisibility,
                    focusNode: _currentFocus,
                    leadIcon: Icons.lock_outline_rounded,
                    accentColor: CpColors.textSub,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Divider ────────────────────────────────
                _a(3, const CpSectionDivider(label: 'NEW CREDENTIALS')),
                const SizedBox(height: 24),

                // ── New password ───────────────────────────
                _a(
                  3,
                  CpPasswordField(
                    controller: _newPwdCtrl,
                    label: 'NEW PASSWORD',
                    hint: 'Create a strong password',
                    isVisible: provider.newVisible,
                    onToggleVisibility: provider.toggleNewVisibility,
                    focusNode: _newFocus,
                    leadIcon: Icons.vpn_key_rounded,
                    accentColor: CpColors.accent,
                    textInputAction: TextInputAction.next,
                    onChanged: provider.analyzePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'New password is required';
                      if (v.length < 8) return 'Must be at least 8 characters';
                      if (v == _currentPwdCtrl.text) {
                        return 'Must differ from current password';
                      }
                      return null;
                    },
                  ),
                ),

                // ── Strength + checklist ───────────────────
                if (provider.strength != PasswordStrength.empty) ...[
                  const SizedBox(height: 14),
                  CpStrengthMeter(strength: provider.strength),
                  const SizedBox(height: 14),
                  CpChecklist(
                    hasMin: provider.hasMin,
                    hasUpper: provider.hasUpper,
                    hasLower: provider.hasLower,
                    hasNumber: provider.hasNumber,
                    hasSpecial: provider.hasSpecial,
                  ),
                ],

                const SizedBox(height: 24),

                // ── Confirm password ───────────────────────
                _a(
                  4,
                  CpPasswordField(
                    controller: _confirmPwdCtrl,
                    label: 'CONFIRM NEW PASSWORD',
                    hint: 'Repeat your new password',
                    isVisible: provider.confirmVisible,
                    onToggleVisibility: provider.toggleConfirmVisibility,
                    focusNode: _confirmFocus,
                    leadIcon: Icons.verified_user_outlined,
                    accentColor: const Color(0xFF16A34A),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (v != _newPwdCtrl.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // ── Submit ─────────────────────────────────
                _a(
                  5,
                  CpSubmitButton(
                    isLoading: provider.step == CpStep.loading,
                    onTap: () => _submit(provider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card header ─────────────────────────────────────────────────────────────
  Widget _buildCardHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        // Subtle indigo tint strip at top of card
        gradient: LinearGradient(
          colors: [Color(0xFFF0EFFE), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Shield icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: CpColors.accentLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CpColors.accent.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: CpColors.accent.withOpacity(0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: CpColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(
                    color: CpColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep your account protected',
                  style: TextStyle(
                    color: CpColors.textSub.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Steps pill: 3 steps indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: CpColors.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CpColors.accent.withOpacity(0.18)),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CpColors.accent.withOpacity(i == 0 ? 1.0 : 0.25),
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

// ─── Top navigation bar ───────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CpColors.cardBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: CpColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: CpColors.textPrimary,
              size: 15,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Page title
        const Text(
          'Security',
          style: TextStyle(
            color: CpColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),

        const Spacer(),

        // Secure badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CpColors.successBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CpColors.successBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CpColors.success,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'SSL Secured',
                style: TextStyle(
                  color: CpColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

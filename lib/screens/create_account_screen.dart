import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/create_account_provider.dart';
import 'package:pos_app/screens/utils/role_config.dart';
import 'package:pos_app/screens/widgets/create_account_widgets.dart';
import 'package:pos_app/screens/widgets/role_ropdown_widget.dart';
import 'package:provider/provider.dart';


class CreateAccountScreen extends StatelessWidget {
  /// Required business context passed from the logged-in admin session.
  final String businessId;
  final String businessName;

  const CreateAccountScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  /// Wrap screen with its own provider so it's self-contained.
  static Route<bool> route({
    required String businessId,
    required String businessName,
  }) {
    return MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => CreateAccountProvider(),
        child: CreateAccountScreen(
          businessId: businessId,
          businessName: businessName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _Body(businessId: businessId, businessName: businessName),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BODY — listens to provider; shows form or success screen
// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatefulWidget {
  final String businessId;
  final String businessName;

  const _Body({required this.businessId, required this.businessName});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with TickerProviderStateMixin {
  // ── Form Key ───────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── Animations ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _successCtrl;
  late List<Animation<double>> _fadeList;
  late List<Animation<Offset>> _slideList;
  late Animation<double> _successFade;
  late Animation<double> _successScale;

  static const int _itemCount = 6;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeList = [];
    _slideList = [];
    for (int i = 0; i < _itemCount; i++) {
      final start = (i * 0.10).clamp(0.0, 1.0);
      final end = (start + 0.42).clamp(0.0, 1.0);
      _fadeList.add(Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Interval(start, end, curve: Curves.easeOut)),
      ));
      _slideList.add(Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      ));
    }

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _successFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );
    _successScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    _entryCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ── Animate helper ─────────────────────────────────────────────
  Widget _s(int i, Widget child) {
    final idx = i.clamp(0, _itemCount - 1);
    return FadeTransition(
      opacity: _fadeList[idx],
      child: SlideTransition(position: _slideList[idx], child: child),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────
  Future<void> _submit(CreateAccountProvider provider) async {
    if (!provider.isRoleSelected) {
      showStaffToast(context, 'Please select a role to continue.', success: false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final ok = await provider.createAccount(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      password: _pwdCtrl.text,
      businessId: widget.businessId,
      businessName: widget.businessName,
    );

    if (!mounted) return;

    if (ok) {
      _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 2600));
      if (mounted) Navigator.of(context).pop(true);
    } else if (provider.errorMessage.isNotEmpty) {
      showStaffToast(context, provider.errorMessage, success: false);
      provider.clearError();
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<CreateAccountProvider>(
      builder: (context, provider, _) {
        if (provider.isSuccess) {
          final role = RoleConfig.fromValue(provider.createdRole)!;
          return CreateAccountSuccessView(
            role: role,
            name: provider.createdName,
            email: provider.createdEmail,
            fadeAnim: _successFade,
            scaleAnim: _successScale,
          );
        }

        final activeRole = RoleConfig.fromValue(provider.selectedRole);
        final accentColor = activeRole?.color ?? AppColors.primary;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top Bar ────────────────────────────────────────
            SliverToBoxAdapter(
              child: StaffPageTopBar(
                title: 'Create Account',
                subtitle: 'Staff management',
                onBack: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                trailing: const StatusBadge(label: 'Admin Panel'),
              ),
            ),

            // ── Head Banner ────────────────────────────────────
            SliverToBoxAdapter(
              child: _s(0, StaffHeadBanner(roles: RoleConfig.all)),
            ),

            // ── Role Selection ─────────────────────────────────
            SliverToBoxAdapter(
              child: _s(1, _RoleSection(provider: provider)),
            ),

            // ── Account Details ────────────────────────────────
            SliverToBoxAdapter(
              child: _s(3, _DetailsSection(
                formKey: _formKey,
                nameCtrl: _nameCtrl,
                emailCtrl: _emailCtrl,
                phoneCtrl: _phoneCtrl,
                pwdCtrl: _pwdCtrl,
                confirmCtrl: _confirmCtrl,
                accentColor: accentColor,
                provider: provider,
              )),
            ),

            // ── CTA ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _s(5, _CTASection(
                provider: provider,
                activeRole: activeRole,
                onSubmit: () => _submit(provider),
              )),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE SECTION — uses custom RoleDropdown
// ─────────────────────────────────────────────────────────────────────────────

class _RoleSection extends StatelessWidget {
  final CreateAccountProvider provider;

  const _RoleSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final activeRole = RoleConfig.fromValue(provider.selectedRole);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Select Role',
            subtitle: 'Choose access level for this staff member',
            accentColor: activeRole?.color ?? AppColors.primary,
          ),
          SizedBox(height: 14.h),
          RoleDropdown(
            selectedValue:
                provider.selectedRole.isEmpty ? null : provider.selectedRole,
            accentColor: activeRole?.color ?? AppColors.primary,
            onChanged: provider.selectRole,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAILS SECTION (all form fields)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController pwdCtrl;
  final TextEditingController confirmCtrl;
  final Color accentColor;
  final CreateAccountProvider provider;

  const _DetailsSection({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.pwdCtrl,
    required this.confirmCtrl,
    required this.accentColor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Account Details',
            subtitle: 'Name, email, phone & password are required',
            accentColor: accentColor,
          ),
          SizedBox(height: 14.h),
          Form(
            key: formKey,
            child: FormCard(
              children: [
                // Full Name
                StaffFormField(
                  controller: nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Ravi Kumar',
                  icon: Icons.person_outline_rounded,
                  accentColor: accentColor,
                  isFirst: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'Minimum 2 characters';
                    return null;
                  },
                ),
                const FormDivider(),

                // Email
                StaffFormField(
                  controller: emailCtrl,
                  label: 'Email Address *',
                  hint: 'staff@yourstore.com',
                  icon: Icons.alternate_email_rounded,
                  accentColor: accentColor,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                      return 'Enter a valid email';
                    return null;
                  },
                ),
                const FormDivider(),

                // Phone
                StaffFormField(
                  controller: phoneCtrl,
                  label: 'Phone Number *',
                  hint: '9876543210',
                  icon: Icons.phone_outlined,
                  accentColor: accentColor,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone is required';
                    if (v.trim().length < 10) return 'Enter a valid 10-digit number';
                    return null;
                  },
                ),
                const FormDivider(),

                // Password
                StaffFormField(
                  controller: pwdCtrl,
                  label: 'Password *',
                  hint: 'Min. 6 characters',
                  icon: Icons.lock_outline_rounded,
                  accentColor: accentColor,
                  obscureText: !provider.pwdVisible,
                  suffixIcon: EyeIconButton(
                    isVisible: provider.pwdVisible,
                    onTap: provider.togglePasswordVisibility,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const FormDivider(),

                // Confirm Password
                StaffFormField(
                  controller: confirmCtrl,
                  label: 'Confirm Password *',
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline_rounded,
                  accentColor: accentColor,
                  obscureText: !provider.confirmVisible,
                  isLast: true,
                  suffixIcon: EyeIconButton(
                    isVisible: provider.confirmVisible,
                    onTap: provider.toggleConfirmVisibility,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != pwdCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CTA SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _CTASection extends StatelessWidget {
  final CreateAccountProvider provider;
  final RoleConfig? activeRole;
  final VoidCallback onSubmit;

  const _CTASection({
    required this.provider,
    required this.activeRole,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        children: [
          // Role summary strip (animated in/out)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: activeRole != null
                ? RoleSummaryStrip(role: activeRole!)
                : const SizedBox.shrink(),
          ),

          // Submit button
          StaffCTAButton(
            isReady: provider.isRoleSelected,
            isLoading: provider.isLoading,
            role: activeRole,
            onTap: onSubmit,
          ),

          SizedBox(height: 14.h),

          const InfoNoteRow(
            message: 'A verification email will be sent to the staff member.',
          ),
        ],
      ),
    );
  }
}


//inital
/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/providers/create_account_provider.dart';
import 'package:pos_app/screens/utils/role_config.dart';
import 'package:pos_app/screens/widgets/create_account_widgets.dart';
import 'package:provider/provider.dart';

class CreateAccountScreen extends StatelessWidget {
  /// Required business context passed from the logged-in admin session.
  final String businessId;
  final String businessName;

  const CreateAccountScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  /// Wrap screen with its own provider so it's self-contained.
  static Route<bool> route({
    required String businessId,
    required String businessName,
  }) {
    return MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => CreateAccountProvider(),
        child: CreateAccountScreen(
          businessId: businessId,
          businessName: businessName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _Body(businessId: businessId, businessName: businessName),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BODY — listens to provider; shows form or success screen
// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatefulWidget {
  final String businessId;
  final String businessName;

  const _Body({required this.businessId, required this.businessName});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with TickerProviderStateMixin {
  // ── Form Key ───────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── Animations ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _successCtrl;
  late List<Animation<double>> _fadeList;
  late List<Animation<Offset>> _slideList;
  late Animation<double> _successFade;
  late Animation<double> _successScale;

  static const int _itemCount = 6;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeList = [];
    _slideList = [];
    for (int i = 0; i < _itemCount; i++) {
      final start = (i * 0.10).clamp(0.0, 1.0);
      final end = (start + 0.42).clamp(0.0, 1.0);
      _fadeList.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
      _slideList.add(
        Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _successFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _successScale = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    _entryCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ── Animate helper ─────────────────────────────────────────────
  Widget _s(int i, Widget child) {
    final idx = i.clamp(0, _itemCount - 1);
    return FadeTransition(
      opacity: _fadeList[idx],
      child: SlideTransition(position: _slideList[idx], child: child),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────
  Future<void> _submit(CreateAccountProvider provider) async {
    if (!provider.isRoleSelected) {
      showStaffToast(
        context,
        'Please select a role to continue.',
        success: false,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final ok = await provider.createAccount(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      password: _pwdCtrl.text,
      businessId: widget.businessId,
      businessName: widget.businessName,
    );

    if (!mounted) return;

    if (ok) {
      _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 2600));
      if (mounted) Navigator.of(context).pop(true);
    } else if (provider.errorMessage.isNotEmpty) {
      showStaffToast(context, provider.errorMessage, success: false);
      provider.clearError();
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<CreateAccountProvider>(
      builder: (context, provider, _) {
        if (provider.isSuccess) {
          final role = RoleConfig.fromValue(provider.createdRole)!;
          return CreateAccountSuccessView(
            role: role,
            name: provider.createdName,
            email: provider.createdEmail,
            fadeAnim: _successFade,
            scaleAnim: _successScale,
          );
        }

        final activeRole = RoleConfig.fromValue(provider.selectedRole);
        final accentColor = activeRole?.color ?? AppColors.primary;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top Bar ────────────────────────────────────────
            SliverToBoxAdapter(
              child: StaffPageTopBar(
                title: 'Create Account',
                subtitle: 'Staff management',
                onBack: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                trailing: const StatusBadge(label: 'Admin Panel'),
              ),
            ),

            // ── Head Banner ────────────────────────────────────
            SliverToBoxAdapter(
              child: _s(0, StaffHeadBanner(roles: RoleConfig.all)),
            ),

            // ── Role Selection ─────────────────────────────────
            SliverToBoxAdapter(child: _s(1, _RoleSection(provider: provider))),

            // ── Account Details ────────────────────────────────
            SliverToBoxAdapter(
              child: _s(
                3,
                _DetailsSection(
                  formKey: _formKey,
                  nameCtrl: _nameCtrl,
                  emailCtrl: _emailCtrl,
                  phoneCtrl: _phoneCtrl,
                  pwdCtrl: _pwdCtrl,
                  confirmCtrl: _confirmCtrl,
                  accentColor: accentColor,
                  provider: provider,
                ),
              ),
            ),

            // ── CTA ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _s(
                5,
                _CTASection(
                  provider: provider,
                  activeRole: activeRole,
                  onSubmit: () => _submit(provider),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _RoleSection extends StatelessWidget {
  final CreateAccountProvider provider;

  const _RoleSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Select Role',
            subtitle: 'Choose access level for this staff member',
          ),
          SizedBox(height: 14.h),
          Row(
            children: RoleConfig.all.asMap().entries.map((entry) {
              final i = entry.key;
              final role = entry.value;
              return Expanded(
                flex: provider.selectedRole == role.value ? 5 : 3,
                child: RoleCard(
                  role: role,
                  isSelected: provider.selectedRole == role.value,
                  isLast: i == RoleConfig.all.length - 1,
                  onTap: () => provider.selectRole(role.value),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAILS SECTION (all form fields)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController pwdCtrl;
  final TextEditingController confirmCtrl;
  final Color accentColor;
  final CreateAccountProvider provider;

  const _DetailsSection({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.pwdCtrl,
    required this.confirmCtrl,
    required this.accentColor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Account Details',
            subtitle: 'Email and password are mandatory',
            accentColor: accentColor,
          ),
          SizedBox(height: 14.h),
          Form(
            key: formKey,
            child: FormCard(
              children: [
                // Full Name
                StaffFormField(
                  controller: nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Ravi Kumar',
                  icon: Icons.person_outline_rounded,
                  accentColor: accentColor,
                  isFirst: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Name is required';
                    if (v.trim().length < 2) return 'Minimum 2 characters';
                    return null;
                  },
                ),
                const FormDivider(),

                // Email
                StaffFormField(
                  controller: emailCtrl,
                  label: 'Email Address *',
                  hint: 'staff@yourstore.com',
                  icon: Icons.alternate_email_rounded,
                  accentColor: accentColor,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                      return 'Enter a valid email';
                    return null;
                  },
                ),
                const FormDivider(),

                // Phone
                StaffFormField(
                  controller: phoneCtrl,
                  label: 'Phone Number',
                  hint: '9876543210',
                  icon: Icons.phone_outlined,
                  accentColor: accentColor,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Phone is required';
                    if (v.trim().length < 10)
                      return 'Enter a valid 10-digit number';
                    return null;
                  },
                ),
                const FormDivider(),

                // Password
                StaffFormField(
                  controller: pwdCtrl,
                  label: 'Password *',
                  hint: 'Min. 6 characters',
                  icon: Icons.lock_outline_rounded,
                  accentColor: accentColor,
                  obscureText: !provider.pwdVisible,
                  suffixIcon: EyeIconButton(
                    isVisible: provider.pwdVisible,
                    onTap: provider.togglePasswordVisibility,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const FormDivider(),

                // Confirm Password
                StaffFormField(
                  controller: confirmCtrl,
                  label: 'Confirm Password *',
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline_rounded,
                  accentColor: accentColor,
                  obscureText: !provider.confirmVisible,
                  isLast: true,
                  suffixIcon: EyeIconButton(
                    isVisible: provider.confirmVisible,
                    onTap: provider.toggleConfirmVisibility,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please confirm your password';
                    if (v != pwdCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CTA SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _CTASection extends StatelessWidget {
  final CreateAccountProvider provider;
  final RoleConfig? activeRole;
  final VoidCallback onSubmit;

  const _CTASection({
    required this.provider,
    required this.activeRole,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
      child: Column(
        children: [
          // Role summary strip (animated in/out)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: activeRole != null
                ? RoleSummaryStrip(role: activeRole!)
                : const SizedBox.shrink(),
          ),

          // Submit button
          StaffCTAButton(
            isReady: provider.isRoleSelected,
            isLoading: provider.isLoading,
            role: activeRole,
            onTap: onSubmit,
          ),

          SizedBox(height: 14.h),

          const InfoNoteRow(
            message: 'A verification email will be sent to the staff member.',
          ),
        ],
      ),
    );
  }
}

*/
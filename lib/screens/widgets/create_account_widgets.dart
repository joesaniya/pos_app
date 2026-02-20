import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/screens/utils/role_config.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS
//  All standalone, stateless, easily composable pieces.
// ─────────────────────────────────────────────────────────────────────────────

// ── App Colors ────────────────────────────────────────────────────────────────
class AppColors {
  static const background = Color(0xFFF7F5F0);
  static const card = Colors.white;
  static const primary = Color(0xFF1B4332);
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFF3F4F6);
  static const labelGray = Color(0xFF9CA3AF);
  static const placeholderGray = Color(0xFFD1D5DB);
  static const textDark = Color(0xFF111827);
  static const textBody = Color(0xFF374151);
  static const errorRed = Color(0xFFDC2626);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.labelGray,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BACK BUTTON + PAGE TITLE BAR
// ─────────────────────────────────────────────────────────────────────────────

class StaffPageTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  const StaffPageTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            _BackButton(onTap: onBack),
            SizedBox(width: 14.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.labelGray,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15.sp,
          color: AppColors.textBody,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BADGE CHIP (e.g. "Admin Panel")
// ─────────────────────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color lightColor;
  final Color borderColor;

  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.lightColor = const Color(0xFFEAF3EE),
    this.borderColor = const Color(0xFFB7D9C4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEAD BANNER (green hero card at the top)
// ─────────────────────────────────────────────────────────────────────────────

class StaffHeadBanner extends StatelessWidget {
  final List<RoleConfig> roles;

  const StaffHeadBanner({super.key, required this.roles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative circles
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Icon(Icons.person_add_rounded, color: Colors.white, size: 24.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Staff',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Assign a role and create login\ncredentials for your team member.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11.5.sp,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: roles
                      .map((r) => Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: _RoleChip(role: r),
                          ))
                      .toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final RoleConfig role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, color: Colors.white.withOpacity(0.8), size: 11.sp),
          SizedBox(width: 5.w),
          Text(
            role.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE CARD (animated, selectable)
// ─────────────────────────────────────────────────────────────────────────────

class RoleCard extends StatelessWidget {
  final RoleConfig role;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.role,
    required this.isSelected,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(right: isLast ? 0 : 8.w),
        padding: EdgeInsets.all(isSelected ? 14.w : 12.w),
        decoration: BoxDecoration(
          color: isSelected ? role.color : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: role.color.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.15) : role.light,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                role.icon,
                color: isSelected ? Colors.white : role.color,
                size: 18.sp,
              ),
            ),
            SizedBox(height: 10.h),

            // Label
            Text(
              role.label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),

            // Expanded detail when selected
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),
                        Text(
                          role.caption,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 9.5.sp,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            role.tag,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: 8.h),

            // Selection indicator
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 18.w : 8.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.7) : AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FORM CARD + FORM FIELD (unified, no borders between fields)
// ─────────────────────────────────────────────────────────────────────────────

class FormCard extends StatelessWidget {
  final List<Widget> children;

  const FormCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class FormDivider extends StatelessWidget {
  const FormDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(height: 1, color: AppColors.divider),
    );
  }
}

class StaffFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isFirst;
  final bool isLast;
  final int? maxLength;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const StaffFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isFirst = false,
    this.isLast = false,
    this.maxLength,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      validator: validator,
      cursorColor: accentColor,
      style: TextStyle(
        color: AppColors.textDark,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.labelGray,
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.placeholderGray, fontSize: 13.sp),
        prefixIcon: Icon(icon, color: AppColors.placeholderGray, size: 18.sp),
        suffixIcon: suffixIcon,
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? Radius.circular(20.r) : Radius.zero,
            topRight: isFirst ? Radius.circular(20.r) : Radius.zero,
            bottomLeft: isLast ? Radius.circular(20.r) : Radius.zero,
            bottomRight: isLast ? Radius.circular(20.r) : Radius.zero,
          ),
          borderSide: BorderSide(color: accentColor.withOpacity(0.45), width: 2),
        ),
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        errorStyle: TextStyle(color: AppColors.errorRed, fontSize: 11.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
      ),
    );
  }
}

class EyeIconButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;

  const EyeIconButton({super.key, required this.isVisible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.placeholderGray,
        size: 18.sp,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE SUMMARY STRIP (shows above CTA button)
// ─────────────────────────────────────────────────────────────────────────────

class RoleSummaryStrip extends StatelessWidget {
  final RoleConfig role;

  const RoleSummaryStrip({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: role.light,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: role.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: role.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(role.icon, color: role.color, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creating ${role.label} Account',
                  style: TextStyle(
                    color: role.color,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  role.caption,
                  style: TextStyle(
                    color: role.color.withOpacity(0.6),
                    fontSize: 10.5.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: role.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              role.tag,
              style: TextStyle(
                color: role.color,
                fontSize: 8.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CTA BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class StaffCTAButton extends StatelessWidget {
  final bool isReady;
  final bool isLoading;
  final RoleConfig? role;
  final VoidCallback? onTap;

  const StaffCTAButton({
    super.key,
    required this.isReady,
    required this.isLoading,
    this.role,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = role?.color ?? AppColors.border;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 56.h,
        decoration: BoxDecoration(
          color: isReady ? color : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    color: isReady ? Colors.white : AppColors.placeholderGray,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isReady && role != null) ...[
                      Icon(role!.icon, color: Colors.white, size: 18.sp),
                      SizedBox(width: 8.w),
                    ],
                    Text(
                      isReady && role != null
                          ? 'Create ${role!.label} Account'
                          : 'Select a Role to Continue',
                      style: TextStyle(
                        color: isReady ? Colors.white : AppColors.placeholderGray,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (isReady) ...[
                      SizedBox(width: 10.w),
                      Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14.sp),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INFO NOTE ROW (bottom hint)
// ─────────────────────────────────────────────────────────────────────────────

class InfoNoteRow extends StatelessWidget {
  final String message;

  const InfoNoteRow({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 12.sp, color: AppColors.placeholderGray),
        SizedBox(width: 5.w),
        Text(
          message,
          style: TextStyle(color: AppColors.placeholderGray, fontSize: 11.sp),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUCCESS SCREEN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class CreateAccountSuccessView extends StatelessWidget {
  final RoleConfig role;
  final String name;
  final String email;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;

  const CreateAccountSuccessView({
    super.key,
    required this.role,
    required this.name,
    required this.email,
    required this.fadeAnim,
    required this.scaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Check circle
                  Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      color: role.light,
                      shape: BoxShape.circle,
                      border: Border.all(color: role.border, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: role.color.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(Icons.check_rounded, color: role.color, size: 46.sp),
                  ),
                  SizedBox(height: 24.h),

                  Text(
                    'Account Created!',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    name,
                    style: TextStyle(
                      color: role.color,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'has been added as ${role.label}',
                    style: TextStyle(color: AppColors.labelGray, fontSize: 13.sp),
                  ),
                  SizedBox(height: 20.h),

                  // Role badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: role.light,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: role.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(role.icon, color: role.color, size: 14.sp),
                        SizedBox(width: 6.w),
                        Text(
                          role.tag,
                          style: TextStyle(
                            color: role.color,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 28.h),

                  // Email verification note
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            color: AppColors.labelGray, size: 16.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Verification email sent to $email',
                            style: TextStyle(
                              color: AppColors.labelGray,
                              fontSize: 11.5.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOAST HELPER (call from context)
// ─────────────────────────────────────────────────────────────────────────────

void showStaffToast(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(16.w),
      backgroundColor: success ? AppColors.primary : const Color(0xFF8B1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: Colors.white,
            size: 18.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
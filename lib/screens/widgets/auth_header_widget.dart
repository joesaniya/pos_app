import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showLogo;
  final IconData? logoIcon;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showLogo = true,
    this.logoIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLogo) ...[
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              logoIcon ?? Icons.point_of_sale_rounded,
              color: AppColors.white,
              size: 28.w,
            ),
          ),
          SizedBox(height: 24.h),
        ],
        Text(
          title,
          style: AppTheme.displayMedium.copyWith(
            fontSize: 32.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: AppTheme.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15.sp,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class AuthFooterText extends StatelessWidget {
  final String text;
  final String actionText;
  final VoidCallback onActionTap;

  const AuthFooterText({
    super.key,
    required this.text,
    required this.actionText,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            actionText,
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
        ),
      ],
    );
  }
}

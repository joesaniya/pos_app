import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class AuthCheckbox extends StatelessWidget {
  final bool value;
  final VoidCallback onChanged;
  final String label;

  const AuthCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20.w,
          height: 20.w,
          child: Checkbox(
            value: value,
            onChanged: (_) => onChanged(),
            activeColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }
}

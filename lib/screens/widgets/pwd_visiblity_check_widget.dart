import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';
class PasswordVisibilityButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;

  const PasswordVisibilityButton({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isVisible ? Icons.visibility_off : Icons.visibility,
        color: AppColors.textSecondary,
        size: 20.w,
      ),
      onPressed: onToggle,
    );
  }
}
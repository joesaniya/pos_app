import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';

class AuthIconContainer extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final double? size;

  const AuthIconContainer({
    super.key,
    required this.icon,
    required this.gradientColors,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final containerSize = size ?? 64.w;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: AppColors.white,
        size: containerSize * 0.5,
      ),
    );
  }
}

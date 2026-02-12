import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';


class AuthTabContainer extends StatelessWidget {
  final List<Widget> children;

  const AuthTabContainer({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.lightNeutral200,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: children
            .map((child) => Expanded(child: child))
            .toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pos_app/theme/app_colors.dart';


class AuthStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const AuthStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = currentStep == index;
        final isCompleted = index < currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.r),
                    color: isCompleted || isActive
                        ? AppColors.primaryPurple
                        : AppColors.lightNeutral300,
                  ),
                ),
              ),
              if (index < totalSteps - 1) SizedBox(width: 8.w),
            ],
          ),
        );
      }),
    );
  }
}

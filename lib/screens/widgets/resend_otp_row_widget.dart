import 'package:flutter/material.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class ResendOTPRow extends StatelessWidget {
  final VoidCallback onResend;

  const ResendOTPRow({super.key, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Didn\'t receive OTP?',
          style: AppTheme.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        GestureDetector(
          onTap: onResend,
          child: Text(
            'Resend',
            style: AppTheme.labelMedium.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

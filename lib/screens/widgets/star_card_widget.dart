import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import '../utils/responsive_utils.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final double? change;
  final IconData icon;
  final Color color;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    this.change,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? AppSizes.paddingMedium : AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: AppSizes.iconSizeSmall,
                ),
              ),
              if (change != null && change != 0.0) _buildChangeIndicator(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: ResponsiveUtils.getFontSize(context, 11),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeIndicator() {
    final isPositive = change! > 0;
    final changeColor = isPositive ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: changeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: changeColor,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            '${change!.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: changeColor,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
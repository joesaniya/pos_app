import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import '../utils/responsive_utils.dart';

class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;
  final Widget? bottomWidget;

  const GradientHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    this.actionIcon,
    this.onActionPressed,
    this.bottomWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      padding: EdgeInsets.all(size.width * 0.05),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.borderRadiusXLarge),
          bottomRight: Radius.circular(AppSizes.borderRadiusXLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getFontSize(context, 28),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: ResponsiveUtils.getFontSize(context, 12),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (actionIcon != null)
                _buildActionButton(context, actionIcon!, onActionPressed),
            ],
          ),
          if (bottomWidget != null) ...[
            const SizedBox(height: AppSizes.paddingMedium),
            bottomWidget!,
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: AppSizes.iconSizeMedium),
      ),
    );
  }
}

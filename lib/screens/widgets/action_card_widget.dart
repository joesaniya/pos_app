import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';


class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ActionCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.paddingMedium,
          horizontal: AppSizes.paddingSmall,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: AppSizes.iconSizeMedium,
            ),
            const SizedBox(width: AppSizes.paddingSmall),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
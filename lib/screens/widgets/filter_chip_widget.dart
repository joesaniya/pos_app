import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import '../utils/responsive_utils.dart';

class FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isWhiteBackground;

  const FilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isWhiteBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: AppSizes.paddingSmall),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isWhiteBackground ? Colors.white : Colors.white)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: ResponsiveUtils.getFontSize(context, 13),
          ),
        ),
      ),
    );
  }
}

class FilterChipRow extends StatelessWidget {
  final List<String> items;
  final String selectedItem;
  final Function(String) onItemSelected;
  final bool isWhiteBackground;

  const FilterChipRow({
    Key? key,
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
    this.isWhiteBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items
            .map(
              (item) => FilterChip(
                label: item,
                isSelected: selectedItem == item,
                onTap: () => onItemSelected(item),
                isWhiteBackground: isWhiteBackground,
              ),
            )
            .toList(),
      ),
    );
  }
}
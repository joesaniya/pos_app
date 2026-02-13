import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/tables_provider.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<TablesProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                GradientHeader(
                  title: 'Tables',
                  subtitle: '${provider.tables.length} tables',
                  bottomWidget: _buildStatusIndicators(provider),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
                        context,
                        mobile: 2,
                        tablet: 3,
                        desktop: 5,
                      );

                      return GridView.builder(
                        padding: EdgeInsets.all(size.width * 0.04),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: size.width * 0.03,
                          mainAxisSpacing: size.width * 0.03,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: provider.tables.length,
                        itemBuilder: (context, index) =>
                            TableCard(table: provider.tables[index]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(TablesProvider provider) {
    return Row(
      children: [
        _StatusIndicator(
          label: 'Active',
          color: AppColors.success,
          count: provider.activeTablesCount,
        ),
        const SizedBox(width: AppSizes.paddingMedium),
        _StatusIndicator(
          label: 'Reserved',
          color: AppColors.warning,
          count: provider.reservedTablesCount,
        ),
        const SizedBox(width: AppSizes.paddingMedium),
        _StatusIndicator(
          label: 'Vacant',
          color: Colors.white,
          count: provider.vacantTablesCount,
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _StatusIndicator({
    Key? key,
    required this.label,
    required this.color,
    required this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class TableCard extends StatelessWidget {
  final TableModel table;

  const TableCard({Key? key, required this.table}) : super(key: key);

  Color _getStatusColor() {
    switch (table.status) {
      case 'active':
        return AppColors.success;
      case 'reserved':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final size = MediaQuery.of(context).size;

    return Container(
      padding: EdgeInsets.all(size.width * 0.025),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.all(size.width * 0.03),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.table_restaurant,
                color: color,
                size: ResponsiveUtils.getFontSize(context, size.width * 0.07),
              ),
            ),
          ),
          SizedBox(height: size.width * 0.02),
          Flexible(
            child: Text(
              table.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, size.width * 0.045),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: Text(
              table.status.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, size.width * 0.028),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (table.status == 'active') ...[
            SizedBox(height: size.width * 0.015),
            Flexible(
              child: Text(
                '\$${table.amount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, size.width * 0.035),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: Text(
                table.time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, size.width * 0.025),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
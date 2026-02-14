import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Available', 'Occupied', 'Reserved'];

  final List<TableInfo> tables = [
    TableInfo(
      tableNumber: 1,
      capacity: 4,
      status: TableStatus.occupied,
      orderId: '#4523',
      customerName: 'John Doe',
      orderTotal: 1250.00,
      occupiedTime: DateTime.now().subtract(Duration(minutes: 45)),
    ),
    TableInfo(tableNumber: 2, capacity: 2, status: TableStatus.available),
    TableInfo(
      tableNumber: 3,
      capacity: 6,
      status: TableStatus.reserved,
      customerName: 'Mike Johnson',
      reservationTime: DateTime.now().add(Duration(hours: 1)),
    ),
    TableInfo(
      tableNumber: 4,
      capacity: 4,
      status: TableStatus.occupied,
      orderId: '#4522',
      customerName: 'Jane Smith',
      orderTotal: 2100.00,
      occupiedTime: DateTime.now().subtract(Duration(minutes: 30)),
    ),
    TableInfo(tableNumber: 5, capacity: 8, status: TableStatus.available),
    TableInfo(
      tableNumber: 6,
      capacity: 2,
      status: TableStatus.occupied,
      orderId: '#4521',
      customerName: 'Sarah Wilson',
      orderTotal: 850.00,
      occupiedTime: DateTime.now().subtract(Duration(minutes: 20)),
    ),
    TableInfo(tableNumber: 7, capacity: 4, status: TableStatus.available),
    TableInfo(
      tableNumber: 8,
      capacity: 6,
      status: TableStatus.reserved,
      customerName: 'David Brown',
      reservationTime: DateTime.now().add(Duration(hours: 2)),
    ),
  ];

  List<TableInfo> get filteredTables {
    if (selectedFilter == 'All') return tables;
    return tables.where((table) {
      switch (selectedFilter) {
        case 'Available':
          return table.status == TableStatus.available;
        case 'Occupied':
          return table.status == TableStatus.occupied;
        case 'Reserved':
          return table.status == TableStatus.reserved;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveUtils.getGridCrossAxisCount(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStatusSummary(context),
            _buildFilterChips(context),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(AppSizes.paddingLarge),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSizes.paddingMedium,
                  mainAxisSpacing: AppSizes.paddingMedium,
                  childAspectRatio: 0.9,
                ),
                itemCount: filteredTables.length,
                itemBuilder: (context, index) {
                  return _buildTableCard(filteredTables[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            ),
            child: Icon(
              Icons.table_restaurant,
              color: AppColors.white,
              size: 28,
            ),
          ),
          SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tables',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, 24),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your restaurant tables',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(BuildContext context) {
    final available = tables
        .where((t) => t.status == TableStatus.available)
        .length;
    final occupied = tables
        .where((t) => t.status == TableStatus.occupied)
        .length;
    final reserved = tables
        .where((t) => t.status == TableStatus.reserved)
        .length;

    return Container(
      margin: EdgeInsets.all(AppSizes.paddingLarge),
      padding: EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(
            'Available',
            available,
            AppColors.success,
            Icons.check_circle,
          ),
          _buildStatusDivider(),
          _buildStatusItem(
            'Occupied',
            occupied,
            AppColors.warning,
            Icons.people,
          ),
          _buildStatusDivider(),
          _buildStatusItem('Reserved', reserved, AppColors.info, Icons.event),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          count.toString(),
          style: AppTheme.headlineLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatusDivider() {
    return Container(height: 50, width: 1, color: AppColors.borderLight);
  }

  Widget _buildFilterChips(BuildContext context) {
    return Container(
      height: 50,
      margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingLarge),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return Padding(
            padding: EdgeInsets.only(right: AppSizes.paddingSmall),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = filter;
                });
              },
              backgroundColor: AppColors.white,
              selectedColor: AppColors.primaryPurple.withOpacity(0.2),
              labelStyle: AppTheme.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primaryPurple
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryPurple
                    : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingMedium,
                vertical: AppSizes.paddingSmall,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableCard(TableInfo table) {
    final statusColor = _getStatusColor(table.status);
    final statusIcon = _getStatusIcon(table.status);

    return GestureDetector(
      onTap: () {
        _showTableDetailsBottomSheet(context, table);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(AppSizes.paddingMedium),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.borderRadiusLarge - 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        color: statusColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Table ${table.tableNumber}',
                        style: AppTheme.headlineSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 10, color: AppColors.white),
                        SizedBox(width: 4),
                        Text(
                          '${table.capacity}',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                padding: EdgeInsets.all(AppSizes.paddingMedium),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 32),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _getStatusText(table.status),
                      style: AppTheme.headlineSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (table.status == TableStatus.occupied) ...[
                      SizedBox(height: 8),
                      Text(
                        table.customerName ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹${table.orderTotal?.toStringAsFixed(0)}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (table.status == TableStatus.reserved) ...[
                      SizedBox(height: 8),
                      Text(
                        table.customerName ?? '',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableDetailsBottomSheet(BuildContext context, TableInfo table) {
    final statusColor = _getStatusColor(table.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.borderRadiusXLarge),
          ),
        ),
        padding: EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadiusMedium,
                        ),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: AppSizes.paddingMedium),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table ${table.tableNumber}',
                          style: AppTheme.headlineMedium,
                        ),
                        Text(
                          'Capacity: ${table.capacity} persons',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: AppSizes.paddingLarge),
            Container(
              padding: EdgeInsets.all(AppSizes.paddingMedium),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadiusMedium,
                ),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(table.status), color: statusColor),
                  SizedBox(width: 12),
                  Text(
                    _getStatusText(table.status),
                    style: AppTheme.headlineSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (table.status == TableStatus.occupied) ...[
              SizedBox(height: AppSizes.paddingLarge),
              _buildInfoRow('Customer', table.customerName ?? ''),
              _buildInfoRow('Order ID', table.orderId ?? ''),
              _buildInfoRow(
                'Total Amount',
                '₹${table.orderTotal?.toStringAsFixed(0)}',
              ),
              _buildInfoRow('Duration', _formatDuration(table.occupiedTime)),
            ] else if (table.status == TableStatus.reserved) ...[
              SizedBox(height: AppSizes.paddingLarge),
              _buildInfoRow('Customer', table.customerName ?? ''),
              _buildInfoRow(
                'Reserved For',
                _formatReservationTime(table.reservationTime),
              ),
            ],
            SizedBox(height: AppSizes.paddingLarge),
            Row(
              children: [
                if (table.status == TableStatus.available)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.add),
                      label: Text('Assign Table'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Clear Table'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (table.status == TableStatus.occupied) ...[
                    SizedBox(width: AppSizes.paddingSmall),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.receipt, size: 18),
                        label: Text('View Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return AppColors.success;
      case TableStatus.occupied:
        return AppColors.warning;
      case TableStatus.reserved:
        return AppColors.info;
    }
  }

  IconData _getStatusIcon(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return Icons.check_circle;
      case TableStatus.occupied:
        return Icons.people;
      case TableStatus.reserved:
        return Icons.event;
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.reserved:
        return 'Reserved';
    }
  }

  String _formatDuration(DateTime? time) {
    if (time == null) return '';
    final duration = DateTime.now().difference(time);
    return '${duration.inMinutes} minutes';
  }

  String _formatReservationTime(DateTime? time) {
    if (time == null) return '';
    final duration = time.difference(DateTime.now());
    if (duration.inHours > 0) {
      return 'in ${duration.inHours} hours';
    }
    return 'in ${duration.inMinutes} minutes';
  }
}

enum TableStatus { available, occupied, reserved }

class TableInfo {
  final int tableNumber;
  final int capacity;
  final TableStatus status;
  final String? orderId;
  final String? customerName;
  final double? orderTotal;
  final DateTime? occupiedTime;
  final DateTime? reservationTime;

  TableInfo({
    required this.tableNumber,
    required this.capacity,
    required this.status,
    this.orderId,
    this.customerName,
    this.orderTotal,
    this.occupiedTime,
    this.reservationTime,
  });
}

/*import 'package:flutter/material.dart';
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
}*/

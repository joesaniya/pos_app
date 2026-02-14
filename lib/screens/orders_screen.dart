import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<OrderDetail> allOrders = [
    OrderDetail(
      orderId: '#4523',
      table: 'Table 5',
      customerName: 'John Doe',
      items: [
        OrderItem('Masala Dosa', 2, 120.00),
        OrderItem('Filter Coffee', 2, 50.00),
      ],
      status: OrderStatus.completed,
      time: DateTime.now().subtract(Duration(minutes: 10)),
      total: 340.00,
    ),
    OrderDetail(
      orderId: '#4522',
      table: 'Table 2',
      customerName: 'Jane Smith',
      items: [
        OrderItem('Butter Chicken', 1, 280.00),
        OrderItem('Biryani', 2, 250.00),
        OrderItem('Paneer Tikka', 1, 220.00),
      ],
      status: OrderStatus.preparing,
      time: DateTime.now().subtract(Duration(minutes: 15)),
      total: 1000.00,
    ),
    OrderDetail(
      orderId: '#4521',
      table: 'Table 8',
      customerName: 'Mike Johnson',
      items: [OrderItem('Idli', 3, 80.00), OrderItem('Sambar', 2, 40.00)],
      status: OrderStatus.pending,
      time: DateTime.now().subtract(Duration(minutes: 20)),
      total: 320.00,
    ),
    OrderDetail(
      orderId: '#4520',
      table: 'Table 3',
      customerName: 'Sarah Wilson',
      items: [OrderItem('Dosa', 2, 100.00), OrderItem('Vada', 4, 30.00)],
      status: OrderStatus.cancelled,
      time: DateTime.now().subtract(Duration(minutes: 30)),
      total: 320.00,
    ),
  ];

  List<OrderDetail> getOrdersByStatus(OrderStatus status) {
    return allOrders.where((order) => order.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(allOrders, 'All Orders'),
                  _buildOrderList(
                    getOrdersByStatus(OrderStatus.pending),
                    'Pending Orders',
                  ),
                  _buildOrderList(
                    getOrdersByStatus(OrderStatus.preparing),
                    'Preparing',
                  ),
                  _buildOrderList(
                    getOrdersByStatus(OrderStatus.completed),
                    'Completed',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primaryPurple,
        icon: Icon(Icons.add),
        label: Text('New Order'),
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
            child: Icon(Icons.receipt_long, color: AppColors.white, size: 28),
          ),
          SizedBox(width: AppSizes.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orders',
                  style: AppTheme.displaySmall.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, 24),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${allOrders.length} total orders today',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.filter_list),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightNeutral200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryPurple,
        labelColor: AppColors.primaryPurple,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.labelMedium,
        tabs: [
          Tab(text: 'All (${allOrders.length})'),
          Tab(
            text: 'Pending (${getOrdersByStatus(OrderStatus.pending).length})',
          ),
          Tab(
            text:
                'Preparing (${getOrdersByStatus(OrderStatus.preparing).length})',
          ),
          Tab(
            text:
                'Completed (${getOrdersByStatus(OrderStatus.completed).length})',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<OrderDetail> orders, String emptyMessage) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: AppSizes.paddingMedium),
            Text(
              'No $emptyMessage',
              style: AppTheme.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSizes.paddingLarge),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(OrderDetail order) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingMedium),
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
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppSizes.paddingMedium),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.1),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.borderRadiusLarge),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusMedium,
                    ),
                  ),
                  child: Icon(
                    _getStatusIcon(order.status),
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSizes.paddingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderId,
                            style: AppTheme.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(order.status),
                              style: AppTheme.labelSmall.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.table_restaurant,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(order.table, style: AppTheme.bodySmall),
                          SizedBox(width: 12),
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(order.customerName, style: AppTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTime(order.time),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Items
          Padding(
            padding: EdgeInsets.all(AppSizes.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Items',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}x',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: AppTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTheme.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₹${order.total.toStringAsFixed(0)}',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (order.status != OrderStatus.completed &&
                    order.status != OrderStatus.cancelled) ...[
                  SizedBox(height: AppSizes.paddingMedium),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.close, size: 18),
                          label: Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSizes.paddingSmall),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.check, size: 18),
                          label: Text(
                            order.status == OrderStatus.pending
                                ? 'Start'
                                : 'Complete',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.warning;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

enum OrderStatus { pending, preparing, completed, cancelled }

class OrderDetail {
  final String orderId;
  final String table;
  final String customerName;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime time;
  final double total;

  OrderDetail({
    required this.orderId,
    required this.table,
    required this.customerName,
    required this.items,
    required this.status,
    required this.time,
    required this.total,
  });
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem(this.name, this.quantity, this.price);
}


/*import 'package:flutter/material.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/screens/utils/responsive_utils.dart';
import 'package:pos_app/screens/widgets/filter_chip_widget.dart';
import 'package:pos_app/screens/widgets/gradient_header_widget.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<OrdersProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                GradientHeader(
                  title: 'Orders',
                  subtitle: '${provider.orders.length} total orders',
                  actionIcon: Icons.add,
                  bottomWidget: FilterChipRow(
                    items: const ['All', 'Pending', 'Preparing', 'Served'],
                    selectedItem: provider.selectedFilter,
                    onItemSelected: (filter) =>
                        provider.setSelectedFilter(filter),
                  ),
                ),
                Expanded(
                  child: provider.filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.all(size.width * 0.04),
                          physics: const BouncingScrollPhysics(),
                          itemCount: provider.filteredOrders.length,
                          itemBuilder: (context, index) =>
                              OrderCard(order: provider.filteredOrders[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: AppSizes.paddingMedium),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({Key? key, required this.order}) : super(key: key);

  Color _getStatusColor() {
    switch (order.status) {
      case 'preparing':
        return AppColors.warning;
      case 'served':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall * 1.5),
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: AppSizes.iconSizeMedium,
                ),
              ),
              const SizedBox(width: AppSizes.paddingSmall * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getFontSize(context, 16),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.table_restaurant,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order.table} • ${order.items} items',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${order.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getFontSize(context, 16),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.time,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingSmall * 1.5),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingSmall * 1.5,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusSmall),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              _ActionButton(
                icon: Icons.visibility,
                color: AppColors.info,
                onTap: () {},
              ),
              const SizedBox(width: AppSizes.paddingSmall),
              _ActionButton(
                icon: Icons.check,
                color: AppColors.success,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingSmall),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: AppSizes.iconSizeSmall),
      ),
    );
  }
}*/
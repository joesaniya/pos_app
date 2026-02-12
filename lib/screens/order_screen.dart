import 'package:flutter/material.dart';
import 'package:pos_app/models/inventory_item.dart';
import 'package:pos_app/providers/order_provider.dart';
import 'package:pos_app/screens/widgets/custom_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';

import 'package:pos_app/theme/responsive_utils.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtil().init(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.lightNeutral100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Orders',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(18.h),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Consumer<OrdersProvider>(
                    builder: (context, provider, _) {
                      return SearchField(
                        controller: TextEditingController(
                          text: provider.searchQuery,
                        ),
                        hintText: 'Search orders...',
                        onChanged: (value) => provider.setSearchQuery(value),
                      );
                    },
                  ),
                ),
                SizedBox(height: 2.h),
                TabBar(
                  labelColor: AppColors.primaryPurple,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryPurple,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                  unselectedLabelStyle: TextStyle(fontSize: 12.sp),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Pending'),
                    Tab(text: 'Preparing'),
                    Tab(text: 'Ready'),
                  ],
                  onTap: (index) {
                    final provider = Provider.of<OrdersProvider>(
                      context,
                      listen: false,
                    );
                    switch (index) {
                      case 0:
                        provider.setFilterStatus(null);
                        break;
                      case 1:
                        provider.setFilterStatus(OrderStatus.pending);
                        break;
                      case 2:
                        provider.setFilterStatus(OrderStatus.preparing);
                        break;
                      case 3:
                        provider.setFilterStatus(OrderStatus.ready);
                        break;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        body: Consumer<OrdersProvider>(
          builder: (context, provider, _) {
            final orders = provider.orders;

            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: AppColors.lightNeutral400,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'No orders found',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(4.w),
              itemCount: orders.length,
              itemBuilder: (context, index) =>
                  _buildOrderCard(context, orders[index], provider),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: AppColors.primaryPurple,
          icon: const Icon(Icons.add),
          label: Text('New Order', style: TextStyle(fontSize: 13.sp)),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Order order,
    OrdersProvider provider,
  ) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case OrderStatus.pending:
        statusColor = AppColors.secondaryOrange;
        statusText = 'Pending';
        break;
      case OrderStatus.preparing:
        statusColor = AppColors.secondaryBlue;
        statusText = 'Preparing';
        break;
      case OrderStatus.ready:
        statusColor = AppColors.secondaryGreen;
        statusText = 'Ready';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt, color: statusColor, size: 20.sp),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.id,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'Table ${order.tableNumber}${order.customerName != null ? ' • ${order.customerName}' : ''}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(order.orderTime),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Edit',
                    onPressed: () {},
                    backgroundColor: AppColors.secondaryBlue,
                    icon: Icons.edit,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: CustomButton(
                    text: 'Update',
                    onPressed: () {},
                    backgroundColor: AppColors.secondaryGreen,
                    icon: Icons.update,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:pos_app/screens/widgets/custom_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/responsive_utils.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtil().init(context);

    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Inventory',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    if (provider.lowStockCount > 0)
                      Container(
                        padding: EdgeInsets.all(3.w),
                        margin: EdgeInsets.only(bottom: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                              size: 20.sp,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                '${provider.lowStockCount} items are running low on stock',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SearchField(
                      controller: TextEditingController(
                        text: provider.searchQuery,
                      ),
                      hintText: 'Search inventory...',
                      onChanged: (value) => provider.setSearchQuery(value),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('All')),
                            selected: provider.filterOption == 'All',
                            onSelected: (selected) =>
                                provider.setFilterOption('All'),
                            backgroundColor: AppColors.lightNeutral100,
                            selectedColor: AppColors.primaryPurple,
                            labelStyle: TextStyle(
                              color: provider.filterOption == 'All'
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(child: Text('Low Stock')),
                            selected: provider.filterOption == 'Low Stock',
                            onSelected: (selected) =>
                                provider.setFilterOption('Low Stock'),
                            backgroundColor: AppColors.lightNeutral100,
                            selectedColor: AppColors.primaryPurple,
                            labelStyle: TextStyle(
                              color: provider.filterOption == 'Low Stock'
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 1.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: AppColors.secondaryBlue,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Items',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${provider.items.length}',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryOrange.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.warning_amber,
                                color: AppColors.secondaryOrange,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Low Stock',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${provider.lowStockCount}',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: provider.items.isEmpty
                    ? Center(
                        child: Text(
                          'No inventory items found',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(4.w),
                        itemCount: provider.items.length,
                        itemBuilder: (context, index) {
                          final item = provider.items[index];
                          final isLowStock = item.isLowStock;
                          final stockPercentage =
                              (item.quantity / item.minQuantity).clamp(
                                0.0,
                                1.0,
                              );

                          return Container(
                            margin: EdgeInsets.only(bottom: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isLowStock
                                  ? Border.all(
                                      color: AppColors.warning.withOpacity(0.3),
                                      width: 2,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowLight,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(3.w),
                                        decoration: BoxDecoration(
                                          color: isLowStock
                                              ? AppColors.warningLight
                                              : AppColors.primaryPurple
                                                    .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: isLowStock
                                              ? AppColors.warning
                                              : AppColors.primaryPurple,
                                          size: 20.sp,
                                        ),
                                      ),
                                      SizedBox(width: 3.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (isLowStock)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 2.w,
                                                          vertical: 0.5.h,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .warningLight,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'Low Stock',
                                                      style: TextStyle(
                                                        fontSize: 9.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.warning,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(height: 0.5.h),
                                            Text(
                                              item.category ?? 'Uncategorized',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Current Stock',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            SizedBox(height: 0.5.h),
                                            Text(
                                              '${item.quantity} ${item.unit}',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isLowStock
                                                    ? AppColors.warning
                                                    : AppColors.primaryPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Min Stock',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            SizedBox(height: 0.5.h),
                                            Text(
                                              '${item.minQuantity} ${item.unit}',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Price/${item.unit}',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            SizedBox(height: 0.5.h),
                                            Text(
                                              '₹${item.price}',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 1.5.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: stockPercentage,
                                      minHeight: 8,
                                      backgroundColor:
                                          AppColors.lightNeutral200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isLowStock
                                            ? AppColors.warning
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primaryPurple,
        icon: const Icon(Icons.add),
        label: Text('Add Stock', style: TextStyle(fontSize: 13.sp)),
      ),
    );
  }
}

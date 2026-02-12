import 'package:flutter/material.dart';
import 'package:pos_app/screens/widgets/custom_widgets.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/responsive_utils.dart';
import 'package:provider/provider.dart';
import '../providers/menu_provider.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtil().init(context);

    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Menu',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<MenuProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    SearchField(
                      controller: TextEditingController(
                        text: provider.searchQuery,
                      ),
                      hintText: 'Search menu items...',
                      onChanged: (value) => provider.setSearchQuery(value),
                    ),
                    SizedBox(height: 2.h),
                    SizedBox(
                      height: 5.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.categories.length,
                        itemBuilder: (context, index) {
                          final category = provider.categories[index];
                          final isSelected =
                              provider.selectedCategory == category;

                          return Padding(
                            padding: EdgeInsets.only(right: 2.w),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) =>
                                  provider.setSelectedCategory(category),
                              backgroundColor: AppColors.lightNeutral100,
                              selectedColor: AppColors.primaryPurple,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.sp,
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 3.w),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.menuItems.isEmpty
                    ? Center(
                        child: Text(
                          'No menu items found',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(4.w),
                        itemCount: provider.menuItems.length,
                        itemBuilder: (context, index) {
                          final item = provider.menuItems[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowLight,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20.w,
                                    height: 20.w,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.restaurant,
                                      color: Colors.white,
                                      size: 24.sp,
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
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: item.available
                                                    ? AppColors.success
                                                    : AppColors.error,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 0.5.h),
                                        Text(
                                          item.description,
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 1.h),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 2.w,
                                                vertical: 0.5.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.lightNeutral100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.category,
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '₹${item.price}',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
        label: Text('Add Item', style: TextStyle(fontSize: 13.sp)),
      ),
    );
  }
}

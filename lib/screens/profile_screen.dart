import 'package:flutter/material.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:pos_app/theme/responsive_utils.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtil().init(context);
    
    return Scaffold(
      backgroundColor: AppColors.lightNeutral100,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                padding: EdgeInsets.all(6.w),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 12.w,
                        backgroundColor: AppColors.lightNeutral200,
                        child: Text('J', style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text('Jenslin', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 0.5.h),
                    Text('Restaurant Admin', style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.9))),
                    SizedBox(height: 0.5.h),
                    Text('jenslin@restaurant.com', style: TextStyle(fontSize: 12.sp, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Settings', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(height: 2.h),
                    _buildSettingsCard([
                      _SettingsItem(icon: Icons.person_outline, title: 'Edit Profile', subtitle: 'Update your personal information'),
                      _SettingsItem(icon: Icons.lock_outline, title: 'Change Password', subtitle: 'Update your security credentials'),
                      _SettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage notification preferences',
                        trailing: Switch(value: true, onChanged: (value) {}, activeColor: AppColors.primaryPurple),
                      ),
                    ]),
                    SizedBox(height: 3.h),
                    Text('Restaurant Settings', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(height: 2.h),
                    _buildSettingsCard([
                      _SettingsItem(icon: Icons.restaurant, title: 'Restaurant Details', subtitle: 'Name, address, contact info'),
                      _SettingsItem(icon: Icons.access_time, title: 'Operating Hours', subtitle: 'Set business hours'),
                      _SettingsItem(icon: Icons.table_restaurant, title: 'Table Management', subtitle: 'Configure tables and seating'),
                    ]),
                    SizedBox(height: 3.h),
                    SizedBox(
                      width: double.infinity,
                      height: 6.h,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout),
                            SizedBox(width: 2.w),
                            Text('Logout', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadowLight, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: AppColors.primaryPurple, size: 20.sp),
                ),
                title: Text(item.title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: item.subtitle != null ? Text(item.subtitle!, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)) : null,
                trailing: item.trailing ?? Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20.sp),
              ),
              if (!isLast) Padding(padding: EdgeInsets.only(left: 18.w), child: Divider(height: 1, color: AppColors.lightNeutral200)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  _SettingsItem({required this.icon, required this.title, this.subtitle, this.trailing});
}
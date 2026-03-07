import 'package:flutter/material.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/screens/login_screen.dart';
import 'package:pos_app/screens/utils/app_sizes.dart';
import 'package:pos_app/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription Expired'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSizes.paddingLarge),
               Text(
                'Your Subscription Has Expired',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                  // color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),
              Text(
                'Please renew your subscription to continue using the CRM system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.infoLight,
                ),
              ),
              const SizedBox(height: AppSizes.paddingXLarge),
              ElevatedButton(
                onPressed: () {
                  // In a real app, route to payment/renewal screen
                  // or provide instructions.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please contact support to renew.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
                  ),
                ),
                child: const Text(
                  'Renew Subscription',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),
              TextButton(
                onPressed: () async {
                  await context.read<AppAuthenticationProvider>().logout1();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

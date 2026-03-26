import 'package:pos_app/providers/analytics_provider.dart';
import 'package:pos_app/providers/app_auth_provider.dart';
import 'package:pos_app/providers/create_account_provider.dart';
import 'package:pos_app/providers/dashboard_provider.dart';
import 'package:pos_app/providers/employee_management_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/page_switcher_provider.dart';
import 'package:pos_app/providers/profile_provider.dart';
import 'package:pos_app/providers/report_provider.dart';
import 'package:pos_app/providers/splash_provider.dart';
import 'package:pos_app/providers/supabase_menu_provider.dart';
import 'package:pos_app/providers/qr_code_provider.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/theme/theme_provider.dart';
import 'package:pos_app/providers/network_sync_provider.dart';
import 'package:pos_app/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class ProviderHelperClass {
  static ProviderHelperClass? _instance;

  static ProviderHelperClass get instance {
    _instance ??= ProviderHelperClass();
    return _instance!;
  }

  List<SingleChildWidget> providerLists = [
    // ✅ Services (singleton instances)
    Provider<ConnectivityService>(create: (_) => ConnectivityService.instance),

    // ChangeNotifierProvider(create: (context) => SplashProvider(context)),
    ChangeNotifierProvider(create: (_) => SplashProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => OnboardingProvider()),
    ChangeNotifierProvider(create: (_) => AppAuthenticationProvider()),

    //screens
    ChangeNotifierProvider(create: (_) => PageSwitcherProvider()),
    ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
    ChangeNotifierProvider(create: (_) => ReportProvider()),
    ChangeNotifierProvider(create: (_) => DashboardProvider()),
    ChangeNotifierProvider(create: (_) => OrdersProvider()),
    ChangeNotifierProvider(create: (_) => TablesProvider()),
    ChangeNotifierProvider(create: (_) => MenuProvider()),
    ChangeNotifierProvider(create: (_) => SupabaseMenuProvider()),
    ChangeNotifierProvider(create: (_) => InventoryProvider()),
    ChangeNotifierProvider(create: (_) => EmployeeManagementProvider()),
    ChangeNotifierProvider(create: (_) => ProfileProvider()),
    ChangeNotifierProvider(create: (_) => CreateAccountProvider()),
    ChangeNotifierProvider(create: (_) => QrCodeProvider()),
    ChangeNotifierProvider(create: (_) => NetworkSyncProvider()),
  ];
}

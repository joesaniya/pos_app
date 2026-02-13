import 'package:pos_app/providers/auth_provider.dart';
import 'package:pos_app/providers/dashboard_provider.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/providers/orders_provider.dart';
import 'package:pos_app/providers/page_switcher_provider.dart';
import 'package:pos_app/providers/splash_provider.dart';
import 'package:pos_app/providers/tables_provider.dart';
import 'package:pos_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class ProviderHelperClass {
  static ProviderHelperClass? _instance;

  static ProviderHelperClass get instance {
    _instance ??= ProviderHelperClass();
    return _instance!;
  }

  List<SingleChildWidget> providerLists = [
    // ChangeNotifierProvider(create: (context) => SplashProvider(context)),
    ChangeNotifierProvider(create: (_) => SplashProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => OnboardingProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),

    //screens
    ChangeNotifierProvider(create: (_) => PageSwitcherProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => TablesProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
  ];
}

import 'package:pos_app/providers/auth_provider.dart';
import 'package:pos_app/providers/dash_board_provier.dart';
import 'package:pos_app/providers/inventory_provider.dart';
import 'package:pos_app/providers/menu_provider.dart';
import 'package:pos_app/providers/onboard_provider.dart';
import 'package:pos_app/providers/order_provider.dart';
import 'package:pos_app/providers/splash_provider.dart';
import 'package:pos_app/providers/table_provider.dart';
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
    ChangeNotifierProvider(create: (_) => TableProvider()),
    ChangeNotifierProvider(create: (_) => DashboardProvider()),
    ChangeNotifierProvider(create: (_) => InventoryProvider()),
    ChangeNotifierProvider(create: (_) => OrdersProvider()),
    ChangeNotifierProvider(create: (_) => MenuProvider()),
  ];
}

// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'package:pos_app/config/app_config.dart';
import 'package:pos_app/providers/common_provider.dart';
import 'package:pos_app/screens/splash_screen.dart';
import 'package:pos_app/theme/theme_provider.dart';
import 'theme/app_theme.dart';

// ✅ ADD THESE IMPORTS
import 'package:pos_app/services/reservation_notification_service.dart';
import 'package:pos_app/services/background_task_service.dart';
import 'package:pos_app/widgets/network_aware_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase Init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ⚠️ Testing only — remove in production
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );

  // 🟢 Supabase Init
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // ✅ Initialize Local Notifications
  await ReservationNotificationService().initialize();

  await BackgroundTaskService.initialize();

  // await FcmService.initialize();

  // 📱 System UI Styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await SharedPreferences.getInstance();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MultiProvider(
      providers: ProviderHelperClass.instance.providerLists,
      child: ScreenUtilInit(
        designSize: const Size(390, 840),
        minTextAdapt: true,
        builder: (context, child) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'POS App',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                builder: (context, child) {
                   return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(padding: MediaQuery.of(context).padding),
                    child: child!,
                  );
                 /* return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(padding: MediaQuery.of(context).padding),
                    child: NetworkAwareWidget(child: child!),
                  );*/
                },
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

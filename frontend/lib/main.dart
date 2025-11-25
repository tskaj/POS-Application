import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'config/environment_config.dart';
import 'providers/providers.dart';
import 'routes/app_routes.dart';
import 'utils/win32_window_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration
  await EnvironmentConfig.load();

  // Initialize window manager
  await windowManager.ensureInitialized();

  // Set window title
  await windowManager.setTitle('Dhanpuri By Get Going- POS System');

  // Set window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 700),
    minimumSize: Size(1200, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    // Use the native title bar so Windows minimize/close/maximize buttons are visible.
    titleBarStyle: TitleBarStyle.normal,
    fullScreen: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
    // Prevent default close behavior - confirmation will be handled in WindowListener
    await windowManager.setPreventClose(true);
    // Note: we avoid forcing a Win32-style WS_POPUP fullscreen here so the
    // native window chrome (minimize/close/maximize buttons) remains visible.
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global RouteObserver to track route navigation
  final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => PeopleProvider()),
        ChangeNotifierProvider(create: (_) => WindowProvider()),
      ],
      child: MaterialApp(
        title: 'POS Dashboard',
        theme: ThemeData(
          primaryColor: const Color(0xFF0D1845),
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.white,
          fontFamily: GoogleFonts.poppins().fontFamily,
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        initialRoute: AppRoutes.login,
        routes: AppRoutes.getRoutes(),
        navigatorObservers: [routeObserver], // Add RouteObserver
      ),
    );
  }
}

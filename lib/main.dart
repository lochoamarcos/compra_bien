import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/product_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/report_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

import 'services/analytics_service.dart';

import 'dart:ui';
import 'services/correction_service.dart';
import 'utils/app_config.dart';

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await CorrectionService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await AnalyticsService().init(); // Initialize Analytics
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = prefs.getBool('show_onboarding') ?? true;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: CompraBienApp(showOnboarding: showOnboarding),
    ),
  );
}

class CompraBienApp extends StatefulWidget {
  final bool showOnboarding;
  const CompraBienApp({super.key, required this.showOnboarding});

  @override
  State<CompraBienApp> createState() => _CompraBienAppState();
}

class _CompraBienAppState extends State<CompraBienApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AnalyticsService().forceFlush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
         return MaterialApp(
          title: 'ComprÃ¡Bien',
          themeMode: themeProvider.themeMode,
          theme: _getThemeData(themeProvider.themeType, Brightness.light),
          darkTheme: _getThemeData(themeProvider.themeType, Brightness.dark),
          scrollBehavior: CustomScrollBehavior(),
          home: widget.showOnboarding ? const OnboardingScreen() : const HomeScreen(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            // Analytics Wrapper
            return Listener(
              onPointerDown: (PointerDownEvent event) {
                 // Get current route name if possible, complex in global listener but we can try simple tracking
                 String screen = 'Global'; 
                 // Basic attempt to find top route... omitting for simplicity
                 
                 AnalyticsService().logTouch(event.position.dx, event.position.dy, screen);
              },
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaleFactor: themeProvider.fontScale,
                ),
                child: child!,
              ),
            );
          },
        );
      },
    );
  }


  ThemeData _getThemeData(ThemeType type, Brightness brightness) {
    bool isDark = brightness == Brightness.dark;

    // --- Classic (Turquoise/Celeste) ---
    Color primary = const Color(0xFF00ACC1); // Elegant Turquoise
    Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF); // Pure white for light mode
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // font family "Inter" will be handled by GoogleFonts in widgets or via pubspec
      // For now, we rely on default sans-serif but style it in widgets
      fontFamily: 'Roboto', // Default, will switch to Inter via GoogleFonts if added
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primary, // Always primary as per new header design
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // 20px radius
      ),
      // Add TextTheme adjustments if needed for Inter
    );
  }
}

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

import 'services/correction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await CorrectionService.initialize(
    url: 'https://wqxghiwfudhzdiyyyick.supabase.co',
    anonKey: const String.fromEnvironment('SUPABASE_APIKEY', defaultValue: ''), 
    // Ideally this comes from build --dart-define or .env, but user said they have it in .env
    // Since I can't read .env easily here without flutter_dotenv, and user GAVE me the key implicitly via "SUPABASE_APIKEY in .env" 
    // I should check if I should hardcode or use fromEnvironment. 
    // User said "tengo la pass... y tambien SUPABASE_APIKEY ... configurations todo para eso".
    // I will use String.fromEnvironment and assume user runs with --dart-define OR I'll hardcode if user didn't give the literal key string in chat.
    // Wait, user provided URL but NOT the key string in the chat message ("...y este Publishable API Key" but didn't paste it? Or did they?)
    // Re-reading user message: "...este Publishable API Key, tengo la pass...". 
    // It seems they might have forgotten to paste the key or implying I should read it from env.
    // I will use `const String.fromEnvironment` so it's safe and ask user to provide it if missing or I'll look for .env file?
    // User said "tengo ... en el .env". Flutter doesn't read .env automatically without a package.
    // I will use a placeholder and ASK user or check if I can read .env file.
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
          title: 'CompráBien',
          themeMode: themeProvider.themeMode,
          theme: _getThemeData(themeProvider.themeType, Brightness.light),
          darkTheme: _getThemeData(themeProvider.themeType, Brightness.dark),
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
    
    // Base Colors (Classic)
    Color primary = Colors.blue;
    Color scaffoldBg = isDark ? const Color(0xFF121212) : Colors.white;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Premium Theme Overrides
    if (type == ThemeType.premium) {
      primary = Colors.amber;
      if (isDark) {
        scaffoldBg = const Color(0xFF000000); // Deep Black
        cardColor = const Color(0xFF101010);
      }
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

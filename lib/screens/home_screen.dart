import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart'; // Unused now that ProductCard handles it
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../models/product.dart';
import '../utils/market_branding.dart';
import 'cart_screen.dart';
import '../widgets/lottie_add_to_cart_button.dart';
import '../widgets/lottie_cart_fab.dart';
import '../providers/cart_provider.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Unused here
// import 'debug_log_screen.dart'; // Unused here
import 'onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:io';
import '../widgets/product_card.dart';
import '../widgets/report_problem_dialog.dart';
import '../widgets/bank_promotions_dialog.dart';
// import 'package:compra_bien/widgets/brand_icons.dart'; // Unused here
import '../services/report_service.dart';
import 'report_history_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import '../utils/ota_logger.dart';
import '../utils/app_config.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/app_logger.dart';

final shorebirdCodePush = ShorebirdCodePush();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _searchVisibleCount = 10;
  final Set<String> _activeMarkets = {'Monarca', 'Carrefour', 'Vea', 'La Coope'};
  bool _showTutorial = false;
  int _tutorialStep = 0;
  String _selectedCategory = 'Promociones';
  bool _newUpdateAvailable = false;
  String? _pendingUpdateVersion;
  final ScrollController _categoryScrollController = ScrollController();
  
  // Shorebird Debug/Status
  String _shorebirdStatus = 'Listo';
  bool _isShorebirdUpdateInProgress = false;
  int _shorebirdRetryCount = 0;

  // PWA Install Prompt
  bool _canInstallPwa = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).searchByCategory('Promociones');
      _checkTutorial();
      ReportService.processQueue();
      _checkUpdateStatusOnStartup();
      _showPriceDisclaimer(context);
      _silentShorebirdUpdate();
      _initPackageInfo();
      if (kIsWeb) _initPwaInstall();
    });
  }

  void _initPwaInstall() {
    if (!kIsWeb) return;
    // This uses a global JS shim injected via _pwaInstallPrompt in index.html
    // We poll for install availability every second
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _canInstallPwa = true);
    });
  }

  Future<void> _triggerPwaInstall() async {
    if (!kIsWeb) return;
    try {
      // Call the global function defined in index.html
      // ignore: avoid_web_libraries_in_flutter
      js.context.callMethod('triggerInstall');
      AppLogger().log('PWA: triggered native install prompt');
    } catch (e) {
      AppLogger().log('PWA install trigger failed: $e');
    }
  }

  bool _isStandalone() {
    if (!kIsWeb) return false;
    try {
      // Check for standalone display mode (PWA installed)
      final mq = MediaQuery.of(context);
      return mq.displayFeatures.any((f) => f.type == DisplayFeatureType.unknown) || 
             js.context.callMethod('matchMedia', ['(display-mode: standalone)']).operatorAt('matches');
    } catch (_) {
      return false;
    }
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _currentAppVersion = '${info.version}+${info.buildNumber}');
  }

  Future<void> _checkUpdateSilent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(AppConfig.updatesInfoUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverVersion = data['version'];
        if (serverVersion != null) {
          final currentBase = currentVersion.split('+').first.trim();
          final serverBase = serverVersion.split('+').first.trim();
          
          if (serverBase != currentBase) {
            setState(() {
              _newUpdateAvailable = true;
              _pendingUpdateVersion = serverVersion;
            });
            _showUpdateBanner();
          }
        }
      }
    } catch (_) {
      // Silent failure
    }
  }

  void _showUpdateBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text('¡Hay una nueva actualización ($_pendingUpdateVersion)!'),
        leading: const Icon(Icons.system_update, color: Colors.orange),
        backgroundColor: Colors.orange.shade50,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _checkForUpdates(context); // Open the manual update flow
            },
            child: const Text('VER'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  // Refined Update Logic
  void _openUpdateStatusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateStatusDialog(
        currentApkVersion: _currentAppVersion,
        onUpdateAPK: (url, version) => _startOtaUpdate(context, url, version),
      ),
    );
  }

  String _currentAppVersion = '1.0.0';

  Future<void> _silentShorebirdUpdate() async {
    if (_shorebirdRetryCount >= 3) return;
    try {
      final isAvailable = await shorebirdCodePush.isShorebirdAvailable();
      if (!isAvailable) return;
      final isUpdateAvailable = await shorebirdCodePush.isNewPatchAvailableForDownload();
      if (isUpdateAvailable) {
        await shorebirdCodePush.downloadUpdateIfAvailable();
      }
    } catch (e) {
      _shorebirdRetryCount++;
      Future.delayed(const Duration(seconds: 15), () => _silentShorebirdUpdate());
    }
  }

  void _checkForUpdates(BuildContext context) {
    _openUpdateStatusDialog();
  }

  Future<void> _checkUpdateStatusOnStartup() async {
      final prefs = await SharedPreferences.getInstance();
      final targetVersion = prefs.getString('target_update_version');
      
      if (targetVersion != null) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;
          
          // Clear the flag so we don't show it again unless another update starts
          // BUT only clear if matched? No, clear always after showing result to avoid loop.
          await prefs.remove('target_update_version');
          
          if (currentVersion == targetVersion) {
              // SUCCESS
              try {
                // Ruta estándar de descargas en Android para ota_update
                final file = File('/storage/emulated/0/Download/compraBien.apk');
                if (await file.exists()) {
                  await file.delete();
                  debugPrint('APK de actualización eliminado: ${file.path}');
                }
              } catch (e) {
                debugPrint('No se pudo borrar el APK antiguo: $e');
              }

              if (mounted) {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                          title: const Text('¡Actualización Exitosa!'),
                          content: Text('Ya tenés instalada la versión $currentVersion.\nGracias por actualizar.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Genial'))],
                      )
                  );
              }
          } else {
              // FAILURE / CANCELLED
              // Check if we have an error log
              final log = prefs.getString('update_status_log') ?? 'Error desconocido';
              
              if (mounted) {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                          title: const Text('Actualización no completada'),
                          content: Text('Parece que la actualización a la versión $targetVersion no se completó.\n\n$log'),
                          actions: [
                              TextButton(
                                  onPressed: () {
                                      Navigator.pop(ctx);
                                      // Offer Report
                                      showDialog(context: context, builder: (c) => const ReportProblemDialog());
                                  }, 
                                  child: const Text('Reportar')
                              ),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
                          ],
                      )
                  );
              }
          }
      }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ReportService.processQueue();
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('show_home_tutorial') ?? true) {
      setState(() { 
        _showTutorial = true; 
        _tutorialStep = 0;
      });
    }
  }

  Future<void> _dismissTutorial() async {
    if (_tutorialStep == 0) {
      setState(() { _tutorialStep = 1; });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_home_tutorial', false);
      setState(() { _showTutorial = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _categoryScrollController.dispose(); // Added this
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      setState(() { _searchVisibleCount = 10; });
      Provider.of<ProductProvider>(context, listen: false).search(query, activeMarkets: _activeMarkets);
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF81D4FA) : Colors.white, // Celeste in dark mode
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 12),
            RichText(
              text: TextSpan(
                children: [
                   TextSpan(text: 'CompráBien ', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.normal)),
                    TextSpan(text: 'Tandil', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                 ],
               ),
             ),
             const SizedBox(width: 4),
             IconButton(
               visualDensity: VisualDensity.compact,
               icon: Icon(Icons.credit_card, color: Theme.of(context).primaryColor, size: 22),
               tooltip: 'Promociones Bancarias',
               onPressed: () => showDialog(
                 context: context,
                 builder: (ctx) => const BankPromotionsDialog(),
               ),
             ),
             const SizedBox(width: 4),
           ],
         ),
        actions: [
          // PWA Install Button (only on web, and only if not already standalone)
          if (kIsWeb && !_isStandalone())
            Tooltip(
              message: 'Instalar app',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _canInstallPwa ? _triggerPwaInstall : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usá el menú "..." del navegador para instalar la app'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.install_mobile, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      const Text('Instalar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.text_fields_outlined, color: Theme.of(context).primaryColor, size: 24),
            onPressed: () => _showFontSizeDialog(context),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).primaryColor),
            onSelected: (value) {
              if (value == 'theme') _showThemeDialog(context);
              else if (value == 'tutorial') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
              else if (value == 'sorting') _showSortingDialog(context);
              else if (value == 'version') _checkForUpdates(context);
              else if (value == 'report') showDialog(context: context, builder: (ctx) => const ReportProblemDialog());
              else if (value == 'history') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportHistoryScreen()));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'sorting', child: ListTile(leading: Icon(Icons.sort_outlined), title: Text('Orden Productos'))),
              const PopupMenuItem(value: 'theme', child: ListTile(leading: Icon(Icons.brightness_6), title: Text('Apariencia'))),
              const PopupMenuItem(value: 'version', child: ListTile(leading: Icon(Icons.system_update), title: Text('Buscar Actualizaciones'))),
              const PopupMenuItem(value: 'tutorial', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Ver Tutorial'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.report_problem, color: Colors.orange), title: Text('Reportar problema'))),
              const PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history), title: Text('Historial de Reportes'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5), // Colors.grey[100] equivalent
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white, // Text color on Selected Tab (Cyan bg)
              unselectedLabelColor: Colors.grey[800], // Darker unselected text for better contrast
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.zero, // Outer corners rounded by parent clip
                color: Theme.of(context).primaryColor, // Cyan background for Selected Tab
              ),
              padding: EdgeInsets.zero,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront),
                      const SizedBox(width: 8),
                      const Text('CATEGORÍAS', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: 8),
                      const Text('BUSCAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              onTap: (index) => setState(() {}), // Refresh to update icon colors
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                // Market Filters - Pill Style
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                    border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMarketChip(MarketStyle.monarca),
                        const SizedBox(width: 8),
                        _buildMarketChip(MarketStyle.carrefour),
                        const SizedBox(width: 8),
                        _buildMarketChip(MarketStyle.vea),
                        const SizedBox(width: 8),
                        _buildMarketChip(MarketStyle.cooperativa),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoriesTab(),
                      _buildSearchTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showTutorial) _buildTutorialOverlay(),
          // FAB moved to Stack to control Z-Index explicitly
          Positioned(
            right: 16,
            bottom: 16,
            child: _showTutorial && _tutorialStep == 0 
                ? const SizedBox.shrink() // Hide under overlay in step 1, or let it be covered
                : const LottieCartFAB(),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) => _showThemeDialog(context);

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, theme, _) => AlertDialog(
          title: const Text('Apariencia'),
          contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dark / Light toggle with better labels
              ListTile(
                leading: Icon(
                  theme.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                  color: const Color(0xFF00ACC1),
                ),
                title: Text(theme.themeMode == ThemeMode.dark ? 'Modo Oscuro' : 'Modo Claro'),
                trailing: Switch(
                  value: theme.themeMode == ThemeMode.dark,
                  activeColor: const Color(0xFF00ACC1),
                  onChanged: (val) => theme.toggleTheme(val),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajustá el brillo de la aplicación para mayor comodidad.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismissTutorial,
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _tutorialStep == 0 ? 54 : 0,
                  color: Colors.transparent
                ),
                Expanded(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        alignment: Alignment.center,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              if (_tutorialStep == 0) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.arrow_upward, color: Colors.white, size: 40),
                                      const SizedBox(height: 10),
                                      const Text('Acá vas a poder tocar cada supermercado para filtrar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 20),
                                      const Icon(Icons.touch_app, color: Colors.white70, size: 50),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (_tutorialStep == 1) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 80, bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Este es tu carrito', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 10),
                                      Transform.rotate(
                                        angle: -0.8, // pointing down and right towards the FAB
                                        child: const Icon(Icons.arrow_downward, color: Colors.white, size: 40)
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Padding(padding: EdgeInsets.only(bottom: 40), child: Text('Toca la pantalla para continuar', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketChip(MarketStyle style) {
    final isActive = _activeMarkets.contains(style.name);
    return InkWell(
      onTap: () => setState(() { isActive ? _activeMarkets.remove(style.name) : _activeMarkets.add(style.name); }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? style.primaryColor : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: style.primaryColor.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(style.name, style: TextStyle(color: isActive ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54), fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final List<String> categories = [
    'Promociones',
    'Almacen', 
    'Bebidas', 
    'Frescos', 
    'Limpieza', 
    'Perfumeria',
    'Bebes',
    'Mascotas',
    'Hogar',
    'Electro',
    'Congelados',
    'Panaderia',
    'Muebles'
  ];
        return Column(
          children: [
            SizedBox(
              height: 50,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) { if (selected && _selectedCategory != cat) { setState(() { _selectedCategory = cat; }); provider.searchByCategory(cat, activeMarkets: _activeMarkets); } },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).disabledColor.withOpacity(0.5)),
                        onPressed: () {
                          if (_categoryScrollController.hasClients) {
                             _categoryScrollController.animateTo(
                               _categoryScrollController.offset + 150,
                               duration: const Duration(milliseconds: 300),
                               curve: Curves.easeInOut,
                             );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.searchByCategory(_selectedCategory, activeMarkets: _activeMarkets),
                child: provider.isLoading 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Cargando espere porfavor...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : (provider.categoryResults.isEmpty 
                      ? ListView(children: const [SizedBox(height: 50), Center(child: Text('No se encontraron productos.'))]) // Needed for RefreshIndicator to work on empty list
                      : _buildResultList(provider, isCategory: true)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'Buscar productos...', border: OutlineInputBorder(), suffixIcon: Icon(Icons.search)),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _performSearch)
            ],
          ),
        ),
        Expanded(
          child: Consumer<ProductProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.searchResults.isEmpty) return const Center(child: CircularProgressIndicator());
              if (provider.error != null) return Center(child: Text('Error: ${provider.error}'));
              if (provider.searchResults.isEmpty) return const Center(child: Text('Busca un producto para comparar precios.'));

              final totalList = _getFilteredResults(provider.searchResults);
              final totalItems = totalList.length;
              final visibleItems = totalItems < _searchVisibleCount ? totalItems : _searchVisibleCount;
              final showLoadMore = (visibleItems < totalItems) || provider.hasMore;

              return ListView.builder(
                itemCount: visibleItems + (showLoadMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == visibleItems) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: provider.isLoading 
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: () async {
                                if (visibleItems < totalItems) {
                                  setState(() { _searchVisibleCount += 5; });
                                } else {
                                  await provider.loadMore();
                                  setState(() { _searchVisibleCount += 5; });
                                }
                              },
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Cargar más'),
                            ),
                      ),
                    );
                  }
                  
                  // Defensive check: if totalList is smaller than visibleItems due to filtering
                  if (index >= totalList.length) return const SizedBox.shrink();

                  return _buildProductCard(totalList[index], isHorizontal: true);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showReportDialog(BuildContext context, {String? initialCategory, String? initialMessage}) async {
    final TextEditingController msgController = TextEditingController(text: initialMessage);
    final TextEditingController nameController = TextEditingController();
    String selectedCategory = initialCategory ?? 'Precios Incorrectos';
    
    // Load saved name and app info
    final prefs = await SharedPreferences.getInstance();
    nameController.text = prefs.getString('report_user_name') ?? '';
    final packageInfo = await PackageInfo.fromPlatform();

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reportar un Problema'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tu Nombre (Opcional)',
                        hintText: 'Para contactarte (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      items: ['Precios Incorrectos', 'Bug / Error App', 'Sugerencia', 'Otro']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgController,
                      decoration: const InputDecoration(
                        labelText: 'Detalle del problema', 
                        hintText: 'Ejemplo: error actualizando',
                        border: OutlineInputBorder()
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (msgController.text.isNotEmpty) {
                       Navigator.pop(ctx);
                       
                       if (nameController.text.isNotEmpty) {
                          await prefs.setString('report_user_name', nameController.text);
                       }
                       
                       // Prepend technical metadata
                       String finalMessage = "--- App Info ---\n"
                                             "Version: ${packageInfo.version}+${packageInfo.buildNumber}\n"
                                             "Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n"
                                             "----------------\n\n"
                                             "${msgController.text}";

                       bool isOnline = await ReportService.checkServerStatus();
                       if (!isOnline && context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Aviso: Error de conexión. El reporte se guardará localmente.'))
                           );
                       }

                       await ReportService.submitReport(selectedCategory, finalMessage, userName: nameController.text);
                       
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Reporte enviado (o en cola). ¡Gracias!'))
                         );
                       }
                    }
                  },
                  child: const Text('Enviar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  List<ProductComparisonResult> _getFilteredResults(List<ProductComparisonResult> results) {
    return results.where((r) {
      if (_activeMarkets.isEmpty) return true;
      if (_activeMarkets.contains('Monarca') && r.monarcaProduct != null) return true;
      if (_activeMarkets.contains('Carrefour') && r.carrefourProduct != null) return true;
      if (_activeMarkets.contains('La Coope') && r.coopeProduct != null) return true;
      if (_activeMarkets.contains('Vea') && r.veaProduct != null) return true;
      return false;
    }).toList();
  }

  Widget _buildResultList(ProductProvider provider, {bool isCategory = false}) {
    final results = isCategory ? provider.categoryResults : provider.searchResults;
    final totalList = _getFilteredResults(results);
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!provider.isLoading &&
            provider.hasMore &&
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 500) { // Load when 500px from bottom
          provider.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: totalList.length + (provider.hasMore ? 1 : 0), // Add 1 for loader
        itemBuilder: (context, index) {
          if (index == totalList.length) {
              return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
              );
          }
          return _buildProductCard(totalList[index], isHorizontal: true);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductComparisonResult result, {bool isHorizontal = false}) {
    return ProductCard(result: result, isHorizontal: isHorizontal, activeMarkets: _activeMarkets);
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, theme, child) => SimpleDialog(
          title: const Text('Tamaño de Letra'),
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFontSizeOption(context, theme, 'P', 1.0, 'Normal'),
                  _buildFontSizeOption(context, theme, 'M', 1.15, 'Mediana'),
                  _buildFontSizeOption(context, theme, 'G', 1.3, 'Grande'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeOption(BuildContext context, ThemeProvider theme, String label, double scale, String tooltip) {
    final isSelected = theme.fontScale == scale;
    return InkWell(
      onTap: () { theme.setFontScale(scale); Navigator.pop(context); },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(
              fontSize: 16 * scale, 
              fontWeight: FontWeight.bold,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            )),
            const SizedBox(height: 4),
            Text(tooltip, style: TextStyle(
              fontSize: 10,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            )),
          ],
        ),
      ),
    );
  }


  void _showPriceDisclaimer(BuildContext context) async {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt('disclaimer_last_shown_timestamp');
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Show once every 24 hours (86400000 ms)
      if (lastShown == null || (now - lastShown) > 86400000) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                  title: Row(children: const [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text('Atención')]),
                  content: const Text(
                      'Los precios son referenciales y pueden variar en la sucursal fó­sica. '
                      'CompraBien no garantiza la exactitud del 100% de los precios mostrados.\n\n'
                      'Tandil, Buenos Aires.'
                  ),
                  actions: [
                      TextButton(
                          onPressed: () {
                              Navigator.pop(ctx);
                              prefs.setInt('disclaimer_last_shown_timestamp', now);
                          },
                          child: const Text('Entendido')
                      )
                  ],
              )
          );
      }
  }

  void _showReportsDialog(BuildContext context) async {
       // Temporary debug view for reports locally stored/sent
       final prefs = await SharedPreferences.getInstance();
       final logs = prefs.getStringList('unsent_reports') ?? [];
       
       showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
              title: const Text('Cola de Reportes (Debug)'),
              content: SizedBox(
                   width: double.maxFinite,
                   child: logs.isEmpty 
                     ? const Text('No hay reportes pendientes de envó­o.') 
                     : ListView.builder(
                         itemCount: logs.length,
                         itemBuilder: (ctx, i) => ListTile(
                             title: Text('Reporte #${i+1}'),
                             subtitle: Text(logs[i], maxLines: 2, overflow: TextOverflow.ellipsis),
                         ),
                     ),
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                  if (logs.isNotEmpty)
                     TextButton(onPressed: () {
                         prefs.remove('unsent_reports');
                         Navigator.pop(context);
                     }, child: const Text('Limpiar Cola'))
              ],
          )
       );
  }

  void _showSortingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ProductProvider>(
        builder: (context, provider, _) => AlertDialog(
          title: const Text('Orden de Productos'),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Por coincidencias (Default)'),
                subtitle: const Text('Prioriza productos en más mercados'),
                value: 'default',
                groupValue: provider.sortMode,
                onChanged: (val) => provider.setSortMode(val!),
              ),
              RadioListTile<String>(
                title: const Text('Priorizar Supermercado'),
                subtitle: const Text('Según tu orden personalizado'),
                value: 'priority',
                groupValue: provider.sortMode,
                onChanged: (val) => provider.setSortMode(val!),
              ),
              if (provider.sortMode == 'priority') ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('Arrastrá para reordenar priodidad:', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                ),
                SizedBox(
                  height: 240,
                  width: double.maxFinite,
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: provider.reorderMarkets,
                    children: [
                      for (int i = 0; i < provider.marketPriority.length; i++)
                        ListTile(
                          key: ValueKey(provider.marketPriority[i]),
                          leading: const Icon(Icons.drag_indicator),
                          title: Text(provider.marketPriority[i]),
                          trailing: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  void _startOtaUpdate(BuildContext context, String apkUrl, String version) {
      OTALogger.log('Iniciando descarga de actualización a v$version desde $apkUrl');
      
      // Save target version to verify later
      SharedPreferences.getInstance().then((prefs) {
          prefs.setString('target_update_version', version);
      });

      try {
          // Android-only standard OTA
          if (Platform.isAndroid) {
              OtaUpdate()
                  .execute(apkUrl, destinationFilename: 'compraBien.apk')
                  .listen(
                (OtaEvent event) {
                    // Update progress dialog or notification?
                    // For simplicity, just log for now or show a blocking dialog with progress
                    if (event.status == OtaStatus.DOWNLOADING) {
                        // show progress?
                        print('DL: ${event.value}%');
                    } else if (event.status == OtaStatus.INSTALLING) {
                        print('Installing...');
                    } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
                         print('Permiso faltante?');
                    }
                },
              ).onError((error) {
                  print('OTA Error: $error');
                  OTALogger.log('Error OTA: $error');
                  SharedPreferences.getInstance().then((p) => p.setString('update_status_log', error.toString()));
              });
          } else {
             launchUrl(Uri.parse(apkUrl)); // Fallback for web/other
          }
      } catch (e) {
          print('Exception OTA: $e');
          OTALogger.log('Exception OTA: $e');
      }
  }
}

class UpdateStatusDialog extends StatefulWidget {
  final String currentApkVersion;
  final Function(String url, String version)? onUpdateAPK;

  const UpdateStatusDialog({
    super.key,
    required this.currentApkVersion,
    this.onUpdateAPK,
  });

  @override
  State<UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<UpdateStatusDialog> {
  String _shorebirdStatus = 'Buscando parches...';
  String _apkStatus = 'Buscando versión...';
  bool _isShorebirdLoading = true;
  bool _isApkLoading = true;
  String? _newApkVersion;
  String? _apkDownloadUrl;
  bool _patchReady = false;
  bool _isExpanded = false;
  final List<String> _logs = [];

  void _addLog(String msg) {
    final time = DateTime.now().toString().split(' ').last.substring(0, 8);
    setState(() => _logs.add('[$time] $msg'));
    AppLogger().log('UpdateDialog: $msg');
    OTALogger.log('UpdateDialog: $msg');
  }

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    _logs.clear();
    _addLog('Iniciando verificación completa...');
    await Future.wait([
      _checkShorebird(),
      _checkApk(),
    ]);
  }

  Future<void> _checkShorebird() async {
    setState(() {
      _isShorebirdLoading = true;
      _shorebirdStatus = 'Buscando parches...';
    });
    try {
      _addLog('Buscando parches con Shorebird...');
      final isAvailable = await shorebirdCodePush.isShorebirdAvailable();
      if (!isAvailable) {
        _addLog('Shorebird no está disponible en este dispositivo.');
        setState(() {
          _shorebirdStatus = 'No disponible';
          _isShorebirdLoading = false;
        });
        return;
      }

      final isUpdateAvailable = await shorebirdCodePush.isNewPatchAvailableForDownload();
      _addLog('¿Nuevo parche disponible?: $isUpdateAvailable');
      
      if (isUpdateAvailable) {
        setState(() => _shorebirdStatus = 'Descargando parche...');
        _addLog('Iniciando descarga de parche...');
        await shorebirdCodePush.downloadUpdateIfAvailable();
        _addLog('Descarga completada.');
        setState(() {
          _shorebirdStatus = '¡Parche listo!';
          _isShorebirdLoading = false;
          _patchReady = true;
        });
      } else {
        _addLog('No se encontraron parches pendientes.');
        setState(() {
          _shorebirdStatus = 'App al día';
          _isShorebirdLoading = false;
        });
      }
    } catch (e) {
      _addLog('Error Shorebird: $e');
      setState(() {
        _shorebirdStatus = 'Error de conexión';
        _isShorebirdLoading = false;
      });
    }
  }

  Future<void> _checkApk() async {
    setState(() {
      _isApkLoading = true;
      _apkStatus = 'Buscando versión...';
    });
    try {
      final url = Uri.parse(AppConfig.updatesInfoUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverVersion = data['version'] as String?;
        final downloadUrl = data['url'] as String?;

        if (serverVersion == null) {
          _addLog('Error: El servidor no devolvió una versión válida.');
          setState(() {
            _apkStatus = 'Error datos';
            _isApkLoading = false;
          });
          return;
        }

        final currentBase = widget.currentApkVersion.split('+').first.trim();
        final serverBase = serverVersion.split('+').first.trim();

        _addLog('Versión actual: $currentBase');
        _addLog('Versión servidor: $serverBase');

        if (serverBase != currentBase && downloadUrl != null) {
          _addLog('¡Nueva versión disponible!');
          setState(() {
            _apkStatus = 'Nueva: v$serverVersion';
            _newApkVersion = serverVersion;
            _apkDownloadUrl = downloadUrl;
            _isApkLoading = false;
          });
        } else {
          _addLog('Ya estás en la última versión (APK).');
          setState(() {
            _apkStatus = 'APK al día (v$currentBase)';
            _isApkLoading = false;
          });
        }
      } else {
        _addLog('Error servidor HTTP: ${response.statusCode}');
        setState(() {
          _apkStatus = 'Error servidor';
          _isApkLoading = false;
        });
      }
    } catch (e) {
      _addLog('Error APK: $e');
      setState(() {
        _apkStatus = 'Error de conexión';
        _isApkLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.system_update_alt, color: Color(0xFF00A8B5)),
          SizedBox(width: 10),
          Text('Actualizaciones'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusRow(
            'Binario (APK)',
            _apkStatus,
            _isApkLoading,
            trailing: _newApkVersion != null
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8B5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(60, 30),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onUpdateAPK?.call(_apkDownloadUrl!, _newApkVersion!);
                    },
                    child: const Text('Instalar', style: TextStyle(fontSize: 11)),
                  )
                : null,
          ),
          const Divider(height: 24),
          _buildStatusRow(
            'Código (Patch)',
            _shorebirdStatus,
            _isShorebirdLoading,
            trailing: _patchReady 
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : null,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ver detalles técnicos', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
              ],
            ),
          ),
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, i) => Text(
                  _logs[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (!_isApkLoading && !_isShorebirdLoading)
          ElevatedButton(
            onPressed: _checkAll,
            child: const Text('Reintentar'),
          ),
      ],
    );
  }

  Widget _buildStatusRow(String title, String status, bool loading, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  Expanded(
                    child: Text(
                      status,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}


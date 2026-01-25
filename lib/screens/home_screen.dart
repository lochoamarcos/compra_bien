import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart';
// import 'package:intl/intl.dart'; // Unused now that ProductCard handles it
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../models/product.dart';
import '../utils/market_branding.dart';
import 'cart_screen.dart';
import '../providers/cart_provider.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Unused here
// import 'debug_log_screen.dart'; // Unused here
import 'onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:io';
import '../widgets/product_card.dart';
import '../widgets/report_problem_dialog.dart';
// import 'package:compra_bien/widgets/brand_icons.dart'; // Unused here
import '../services/report_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import '../utils/ota_logger.dart';
import '../utils/app_config.dart';

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
      _showPriceDisclaimer(context); // Show disclaimer on startup
      _checkUpdateSilent(); // New silent check
    });
  }

  Future<void> _checkUpdateSilent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(AppConfig.updatesInfoUrl);
      final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"}).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverVersion = data['version'];
        if (serverVersion != null && serverVersion != currentVersion) {
            setState(() {
              _newUpdateAvailable = true;
              _pendingUpdateVersion = serverVersion;
            });
            _showUpdateBanner();
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
              // SUCCESS
              // Intentar borrar el APK para liberar espacio
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
      setState(() { _showTutorial = true; });
    }
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_home_tutorial', false);
    setState(() { _showTutorial = false; });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(color: Colors.white, fontSize: 20),
                children: [
                  TextSpan(text: 'CompráBien', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' - Tandil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.help_outline, color: Colors.white70, size: 18),
              onSelected: (value) async {
                if (value == 'tutorial') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
                } else if (value == 'city') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por ahora Tandil es la única ciudad disponible.')));
                } else if (value == 'theme') {
                  _showThemeDialog(context);
                } else if (value == 'font_size') {
                  _showFontSizeDialog(context);
                } else if (value == 'market_priority') {
                  _showMarketPriorityDialog(context);
                } else if (value == 'version') {
                  _checkForUpdates(context);
                } else if (value == 'report') {
                  showDialog(context: context, builder: (ctx) => const ReportProblemDialog());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'city', child: ListTile(leading: Icon(Icons.location_city), title: Text('Cambiar ciudad'))),
                const PopupMenuItem(value: 'market_priority', child: ListTile(leading: Icon(Icons.sort), title: Text('Orden Supermercados'))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'version', child: ListTile(leading: Icon(Icons.system_update), title: Text('Buscar Actualizaciones'))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'tutorial', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Ver tutorial / Info'))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'theme', child: ListTile(leading: Icon(Icons.palette), title: Text('Tema'))),
                const PopupMenuItem(value: 'font_size', child: ListTile(leading: Icon(Icons.text_fields), title: Text('Tamaño de Letra'))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.report_problem, color: Colors.orange), title: Text('Reportar problema'))),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.text_fields),
              tooltip: 'Tamaño de Letra',
              onPressed: () => _showFontSizeDialog(context),
            ),
          ],
        ),
        actions: [
          Consumer<ThemeProvider>(builder: (context, theme, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return IconButton(
              icon: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: () => theme.toggleTheme(!isDark),
            );
          }),
          Consumer<CartProvider>(
            builder: (_, cart, ch) => Badge(
              offset: const Offset(-8, 0),
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.itemCount > 0,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Categorías',
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.fastfood, size: 16),
                  SizedBox(width: 4),
                  Icon(Icons.local_pizza, size: 16),
                  SizedBox(width: 4),
                  Icon(Icons.kitchen, size: 16),
                ],
              ),
            ),
            Tab(text: 'Buscar', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, theme, _) => SimpleDialog(
          title: const Text('Elegir Tema'),
          children: [
            SimpleDialogOption(onPressed: () { theme.toggleTheme(false); Navigator.pop(ctx); }, child: const Text('Claro (Light)')),
            SimpleDialogOption(onPressed: () { theme.toggleTheme(true); Navigator.pop(ctx); }, child: const Text('Oscuro (Dark)')),
          ],
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
            if (_tutorialStep == 1)
              Positioned(
                top: 10, left: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.rotate(angle: -0.5, child: const Icon(Icons.arrow_upward, color: Colors.yellow, size: 40)),
                    const SizedBox(height: 4),
                    const SizedBox(width: 150, child: Text('¡Acá podés cambiar el tamaño de letra!', textAlign: TextAlign.center, style: TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold))),
                  ],
                ),
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
                          onSelected: (selected) { if (selected && _selectedCategory != cat) { setState(() { _selectedCategory = cat; }); provider.searchByCategory(cat); } },
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
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
                        child: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).disabledColor.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.searchByCategory(_selectedCategory),
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
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Container(constraints: const BoxConstraints(minHeight: 180), child: _buildProductCard(totalList[index], isHorizontal: true)),
                  );
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
                              const SnackBar(content: Text('Aviso: Servidor fuera de horario. El reporte se guardará localmente.'))
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

  List<ComparisonResult> _getFilteredResults(List<ComparisonResult> results) {
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
    return ListView.builder(
      itemCount: totalList.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(constraints: const BoxConstraints(minHeight: 180), child: _buildProductCard(totalList[index], isHorizontal: true)),
        );
      },
    );
  }

  Widget _buildProductCard(ComparisonResult result, {bool isHorizontal = false}) {
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
          border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isSelected ? Theme.of(context).primaryColor : null)),
            const SizedBox(height: 4),
            Text(tooltip, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(AppConfig.updatesInfoUrl);
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (context.mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? serverVersion = data['version'];

        if (serverVersion != null && serverVersion != currentVersion) {
            // Update Available
            String downloadUrl = data['downloadUrl'] ?? AppConfig.updatesUrl;
            if (downloadUrl.startsWith('/')) {
               // Should not happen with Supabase, but strictly speaking we don't have serverBaseUrl anymore.
               // We will assume it's a relative path from the bucket or just ignore/log.
               debugPrint('Resolving relative update URL: $downloadUrl');
               downloadUrl = 'https://wqxghiwfudhzdiyyyick.storage.supabase.co/storage/v1/object/public/app-releases$downloadUrl';
            }
            _showUpdateDialog(context, currentVersion, serverVersion, downloadUrl);
        } else {
             _showNoUpdateDialog(context, currentVersion);
        }
      } else {
        _showErrorDialog(context, 'Servidor no disponible, probar en otro momento.\n\nHorario: 11:30am - 18:00pm', code: 'HTTPS-${response.statusCode}');
      }

    } catch (e) {
      if (context.mounted) Navigator.pop(context); 
      _showErrorDialog(context, 'No se pudo conectar con el servidor de actualizaciones.', code: e.toString());
    }
  }

  void _showUpdateDialog(BuildContext context, String current, String newVersion, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Nueva Versión Disponible!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu versión: $current'),
            Text('Nueva versión: $newVersion', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('IMPORTANTE:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const Text('Android te pedirá que habilites "Instalar apps desconocidas" para esta aplicación. Es necesario para poder instalar actualizaciones.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Pasos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Text('1. Tocá ACTUALIZAR AQUÍ abajo\n2. Cuando Android pregunte, tocá PERMITIR o CONFIGURACIÓN\n3. Habilitá "Permitir de esta fuente"\n4. Volvé a la app para continuar', style: TextStyle(fontSize: 11, height: 1.3)),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 5),
            const Text('Si tenés problemas, podés descargarla desde el navegador:', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                // Log browser download
                OTALogger.log('Usuario eligió descargar desde navegador: $url');
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir el navegador')),
                  );
                }
              }
            },
            child: const Text('DESCARGAR DESDE NAVEGADOR', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performOTAUpdate(context, url, newVersion);
            },
            child: const Text('ACTUALIZAR AQUÍ'),
          ),
        ],
      ),
    );
  }

  Future<void> _performOTAUpdate(BuildContext context, String url, String targetVersion) async {
    // 1. Save target version locally to verify success on next boot
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_update_version', targetVersion);
    await prefs.setString('update_status_log', 'Iniciando actualización a $targetVersion...\n');

    if (!context.mounted) return;

    // 2. Show the robust update progress dialog (with debug arrow, timeout, and retry)
    _showUpdateProgressDialog(context, url, targetVersion);
  }

  void _showUpdateProgressDialog(BuildContext context, String url, String targetVersion) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _OtaUpdateDialogContent(url: url, targetVersion: targetVersion),
      );
  }


  Future<void> _logUpdateError(String error) async {
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString('update_status_log', 'Error: $error');
  }

  void _showNoUpdateDialog(BuildContext context, String version) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estás actualizado'),
        content: Text('Tenés la última versión instalada ($version).'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String msg, {String? code}) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('¡Ups! Algo salió mal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg),
            if (code != null) ...[
              const SizedBox(height: 16),
              Text('Código: $code', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Entendido')
          )
        ],
      )
    );
  }

  void _showMarketPriorityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer<ProductProvider>(
        builder: (context, provider, child) => AlertDialog(
          title: const Text('Orden de Supermercados'),
          content: SizedBox(
            width: double.maxFinite, height: 300,
            child: ReorderableListView(
              children: [
                for (int i = 0; i < provider.marketPriority.length; i++)
                  ListTile(
                    key: ValueKey(provider.marketPriority[i]),
                    title: Text(provider.marketPriority[i]),
                    leading: const Icon(Icons.drag_handle),
                    trailing: Icon(Icons.store, color: MarketStyle.get(provider.marketPriority[i]).primaryColor),
                  )
              ],
              onReorder: (oldIndex, newIndex) => provider.reorderMarkets(oldIndex, newIndex),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo'))],
        ),
      ),
    );
  }
  Future<void> _showPriceDisclaimer(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Check if user has opted out
    if (prefs.getBool('hide_price_disclaimer') ?? false) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Aviso Importante', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tené en cuenta que algunos precios pueden variar en la sucursal o haber descuentos exclusivos presenciales que no figuran en la app.', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            Text('Ejemplo: Carrefour suele tener ofertas en góndola (como "Sale Ya") que no se reflejan online.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('hide_price_disclaimer', true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('NO MOSTRAR MÁS', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }
} // End of _HomeScreenState


/// Robust Dialog for OTA Update with Timeout & Retry
class _OtaUpdateDialogContent extends StatefulWidget {
  final String url;
  final String targetVersion;

  const _OtaUpdateDialogContent({required this.url, required this.targetVersion});

  @override
  State<_OtaUpdateDialogContent> createState() => _OtaUpdateDialogContentState();
}

class _OtaUpdateDialogContentState extends State<_OtaUpdateDialogContent> {
  late Stream<OtaEvent> _otaStream;
  DateTime _startTime = DateTime.now();
  DateTime _lastEventTime = DateTime.now();
  double _lastPercentage = 0.0;
  String _status = 'Iniciando conexión...';
  double _progressValue = 0.0;
  bool _isInit = true;
  String _errorDetail = '';
  bool _isError = false;
  bool _isHanging = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startUpdate();
    _startTimeoutMonitor();
  }

  void _startUpdate() {
    setState(() {
      _otaStream = OtaUpdate().execute(widget.url, destinationFilename: 'compraBien.apk');
      _startTime = DateTime.now();
      _lastEventTime = DateTime.now();
      _lastPercentage = 0.0;
      _status = 'Iniciando conexión...';
      _progressValue = 0.0;
      _isError = false;
      _isHanging = false;
      _errorDetail = '';
    });
    OTALogger.log('Iniciando actualización a v${widget.targetVersion}');
    OTALogger.log('URL: ${widget.url}');
    print('OTA [v${widget.targetVersion}]: Iniciando stream...');
  }

  void _startTimeoutMonitor() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isError) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final secondsSinceStart = now.difference(_startTime).inSeconds;
      final secondsSinceLastEvent = now.difference(_lastEventTime).inSeconds;

      // Check for Initial Connection Timeout (45s)
      if (_progressValue == 0 && secondsSinceStart > 45) {
        setState(() {
          _isHanging = true;
          _status = 'El servidor no responde (Timeout 45s).';
          _errorDetail = 'La conexión inicial tardó demasiado.';
        });
        OTALogger.log('TIMEOUT: No se recibió respuesta del servidor en 45s');
        timer.cancel();
      }
      // Check for Stuck Progress (45s without change)
      else if (_progressValue > 0 && _progressValue < 100 && secondsSinceLastEvent > 45) {
        setState(() {
          _isHanging = true;
          _status = 'Descarga estancada.';
          _errorDetail = 'No se recibió progreso durante 45 segundos.';
        });
        OTALogger.log('STUCK: Progreso estancado en ${_progressValue.toStringAsFixed(0)}% por 45s');
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _showReport(BuildContext context, String currentStatus, String error) {
     final homeState = context.findAncestorStateOfType<_HomeScreenState>();
     Navigator.pop(context);
     if (homeState != null) {
        homeState._showReportDialog(
          context,
          initialCategory: 'Bug / Error App',
          initialMessage: 'Problema al actualizar a v${widget.targetVersion}.\n'
                          'Estado: $currentStatus\n'
                          'Detalle: $error\n'
                          'Tiempo transcurrido: ${DateTime.now().difference(_startTime).inSeconds}s'
        );
     }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OtaEvent>(
      stream: _otaStream,
      builder: (context, snapshot) {
        if (snapshot.hasError && !_isError) {
          _isError = true;
          _errorDetail = snapshot.error.toString();
          _status = 'Error: ${snapshot.error}';
          OTALogger.log('ERROR: ${snapshot.error}');
          print('OTA Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final event = snapshot.data!;
          _lastEventTime = DateTime.now();
          
          if (event.status == OtaStatus.DOWNLOADING) {
            double currentPct = double.tryParse(event.value ?? '0') ?? 0;
            if (currentPct != _lastPercentage) {
              _lastPercentage = currentPct;
              _progressValue = currentPct;
              _status = 'Descargando... ${currentPct.toStringAsFixed(0)}%';
              // Log every 10% to avoid spam
              if (currentPct % 10 == 0 || currentPct == 100) {
                OTALogger.log('Descarga: ${currentPct.toStringAsFixed(0)}%');
              }
            }
          } else if (event.status == OtaStatus.INSTALLING) {
            _status = 'Instalando... La app se cerrará.';
            _progressValue = 100.0;
            OTALogger.log('Instalando APK...');
            // Clear logs on successful installation (app will restart)
            OTALogger.clearLogs();
          } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
            _isError = true;
            _status = 'Falta permiso de instalación.';
            _errorDetail = 'Habilitá "Instalar apps desconocidas" en los ajustes de Android.';
            OTALogger.log('ERROR: Permiso denegado - REQUEST_INSTALL_PACKAGES');
          } else if (event.status == OtaStatus.INTERNAL_ERROR) {
            _isError = true;
            _status = 'Error Interno.';
            _errorDetail = 'Fallo en la descarga. Verificá tu internet.';
            OTALogger.log('ERROR: INTERNAL_ERROR durante la descarga');
          }
        }

        return WillPopScope(
          onWillPop: () async => _isError || _isHanging,
          child: AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Actualizando App', style: TextStyle(fontSize: 18))),
                GestureDetector(
                  onDoubleTap: () => _showReport(context, _status, _errorDetail),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                    child: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).disabledColor.withOpacity(0.4)),
                  ),
                )
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: (_progressValue > 0) ? _progressValue / 100 : null, backgroundColor: Colors.grey[200]),
                const SizedBox(height: 20),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_isError || _isHanging) ...[
                  const SizedBox(height: 10),
                  Text(_errorDetail, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text('⚠️ NO CIERRES LA APP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Text('Si la descarga no avanza, usá la flecha o esperá al reintento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]
              ],
            ),
            actions: (_isError || _isHanging) ? [
              TextButton(onPressed: () => _showReport(context, _status, _errorDetail), child: const Text('Reportar')),
              TextButton(onPressed: () { _startUpdate(); _startTimeoutMonitor(); }, child: const Text('Reintentar')),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
            ] : [],
          ),
        );
      },
    );
  }
} // End of _OtaUpdateDialogContentState


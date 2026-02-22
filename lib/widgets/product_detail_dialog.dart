import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

import '../models/product.dart';
import '../utils/market_branding.dart';
import '../providers/product_provider.dart';
import '../providers/report_provider.dart';
import '../services/report_service.dart';
import '../services/correction_service.dart';
import '../utils/string_extensions.dart';

class ProductDetailDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final List<Map<String, Object>> products;
  final String? initialSelectedMarketName;
  final ComparisonResult result;

  const ProductDetailDialog({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.products,
    required this.initialSelectedMarketName,
    required this.result,
  }) : super(key: key);

  @override
  State<ProductDetailDialog> createState() => _ProductDetailDialogState();
}

class _ProductDetailDialogState extends State<ProductDetailDialog> {
  late String _selectedMarketName;
  final Set<String> _selectedBadMarkets = {};
  
  // Manual Matching State
  String? _searchingMarket; // The market we are currently manually searching for
  List<Product> _manualSearchResults = [];
  bool _isManualSearching = false;
  final TextEditingController _manualSearchController = TextEditingController();

  // Correction/Report State
  bool _showCorrectionForm = false;
  List<Map<String, dynamic>> _pendingReports = [];
  bool _isLoadingSocial = false;
  final TextEditingController _correctionPriceController = TextEditingController();
  final TextEditingController _correctionOfferController = TextEditingController(); // e.g. "2da al 50%"
  XFile? _correctionImage;
  final ImagePicker _picker = ImagePicker();

  // Multi-Report Note State
  final TextEditingController _reportNoteController = TextEditingController();
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    // Validate initial selection
    if (widget.initialSelectedMarketName != null && 
        widget.products.any((p) => (p['style'] as MarketStyle).name == widget.initialSelectedMarketName)) {
      _selectedMarketName = widget.initialSelectedMarketName!;
    } else {
      _selectedMarketName = (widget.products.first['style'] as MarketStyle).name;
    }
    _fetchSocialReports();
  }

  Future<void> _fetchSocialReports() async {
     setState(() => _isLoadingSocial = true);
     final reports = await CorrectionService.fetchPendingReports(widget.result.ean);
     if (mounted) {
        setState(() {
           _pendingReports = reports;
           _isLoadingSocial = false;
        });
     }
  }
  // --- Helpers ---
  
  String _getSpecialOfferText(String? description) {
     if (description == null || description.isEmpty) return '';
     final lower = description.toLowerCase();
     // Detect "2da al X", "3x2", "4x3", "llévate la segunda"
     if (lower.contains(RegExp(r'\b(2da|3ra|4ta|segunda|tercera|cuarta|3x2|4x3|2x1)\b'))) {
        return description; // Return full description or shortened version? Return full for now.
     }
     return '';
  }

  @override
  Widget build(BuildContext context) {
    // Find selected product
    final selectedEntry = widget.products.firstWhere(
      (p) => (p['style'] as MarketStyle).name == _selectedMarketName,
      orElse: () => widget.products.first,
    );
    final selectedProd = selectedEntry['prod'] as Product;
    final selectedStyle = selectedEntry['style'] as MarketStyle;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HEADER IMAGE
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.white,
                      child: widget.imageUrl != null 
                        ? InteractiveViewer(
                            child: CachedNetworkImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          )
                        : const Icon(Icons.shopping_bag, size: 80, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black26,
                      radius: 16,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. PRODUCT INFO & PRICE
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(
                                 selectedProd.name.toTitleCase(), 
                                 style: TextStyle(
                                   fontSize: 18, 
                                   fontWeight: FontWeight.bold,
                                   color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87
                                 )
                               ),
                               if (selectedProd.promoDescription != null && selectedProd.promoDescription!.isNotEmpty)
                                  Container(
                                     margin: const EdgeInsets.only(top: 4),
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                     decoration: BoxDecoration(
                                        color: const Color(0xFFFF5722),
                                        borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: Text(
                                        selectedProd.promoDescription!,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                     ),
                                  ),
                               const SizedBox(height: 4),
                               if (selectedProd.brand != null)
                                 Text('Marca: ${selectedProd.brand!.toTitleCase()}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                   if (_pendingReports.isNotEmpty)
                                      Padding(
                                         padding: const EdgeInsets.only(right: 4.0),
                                         child: Tooltip(
                                            message: 'Hay reportes de la comunidad',
                                            child: Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange),
                                         ),
                                      ),
                                   Text(
                                      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0).format(selectedProd.price),
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: selectedStyle.primaryColor),
                                   ),
                                ]
                             ),
                             if (selectedProd.oldPrice != null)
                               Text(
                                 NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0).format(selectedProd.oldPrice),
                                 style: const TextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                               ),
                           ],
                        ),

                      ],
                    ),
                    
                    // 3. SPECIAL OFFERS / PROMOS
                    if (selectedProd.promoDescription != null) ...[
                      const SizedBox(height: 12),
                      _buildPromoBanner(selectedProd, selectedStyle),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const Text('Comparativa de Mercados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Tocá un mercado para ver su detalle', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),
                    
                    // 4. MARKET CHIPS LIST
                    _buildMarketChipsList(context),

                    // 5. MISSING MARKETS (Manual Match)
                    _buildMissingMarketsSection(context),

                    // 6. REPORT / SUGGESTION
                    const SizedBox(height: 24),
                    const Divider(),
                    _buildReportSection(context, selectedProd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner(Product prod, MarketStyle style) {
     final specialText = _getSpecialOfferText(prod.promoDescription);
     final isSpecial = specialText.isNotEmpty;

     return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
           // If special, use Blue "Info" style. Else use standard Primary Color style.
           color: isSpecial ? Colors.blue.withOpacity(0.1) : style.primaryColor.withOpacity(0.1),
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: isSpecial ? Colors.blue.withOpacity(0.3) : style.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
           children: [
              Icon(Icons.local_offer, size: 20, color: isSpecial ? Colors.blue : style.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       if (isSpecial)
                          Text('OFERTA ESPECIAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                       Text(
                          prod.promoDescription!,
                          style: TextStyle(
                             fontSize: 14, 
                             fontWeight: FontWeight.bold, 
                             color: isSpecial ? Colors.blue[800] : style.primaryColor
                          ),
                       ),
                    ]
                 ),
              ),
           ],
        ),
     );
  }

  Widget _buildMarketChipsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.products.map((p) {
          final prod = p['prod'] as Product;
          final style = p['style'] as MarketStyle;
          final isSelected = style.name == _selectedMarketName;
          
          final labelText = '${style.name}: \$${prod.price.toStringAsFixed(0)}';
          
          return ActionChip(
            onPressed: isSelected ? null : () {
               setState(() {
                  _selectedMarketName = style.name;
                  _showCorrectionForm = false; // Reset forms on switch
                  _searchingMarket = null; 
               });
            },
            avatar: CircleAvatar(
              backgroundColor: style.primaryColor, 
              child: Text(style.name[0], style: const TextStyle(color: Colors.white, fontSize: 10))
            ),
            label: Text(labelText, style: TextStyle(
              color: isDark 
                  ? Colors.white70 
                  : (isSelected ? style.primaryColor : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
            backgroundColor: isSelected 
                ? (isDark ? const Color(0xFF00ACC1).withOpacity(0.25) : style.primaryColor.withOpacity(0.15)) 
                : (isDark ? const Color(0xFF37474F) : style.primaryColor.withOpacity(0.05)),
            side: BorderSide(
              color: isSelected ? style.primaryColor : (isDark ? Colors.white10 : Colors.transparent), 
              width: isSelected ? 2 : 1
            ),
          );
      }).toList(),
    );
  }

  Widget _buildMissingMarketsSection(BuildContext context) {
      // Which markets are missing from `widget.products`?
      final presentNames = widget.products.map((p) => (p['style'] as MarketStyle).name).toSet();
      final allMarkets = ['Monarca', 'Carrefour', 'Vea', 'La Coope']; // Hardcoded for now or fetch
      final missing = allMarkets.where((m) => !presentNames.contains(m)).toList();

      if (missing.isEmpty) return const SizedBox.shrink();

      return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            const SizedBox(height: 16),
            const Text('No encontrado en:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
               spacing: 8,
               children: missing.map((m) {
                   if (_searchingMarket == m) {
                      // Active Searching UI
                      return _buildInlineSearch(context, m);
                   }
                   return ActionChip(
                      label: Text('Buscar en $m'),
                      avatar: const Icon(Icons.search, size: 14),
                      onPressed: () {
                         setState(() {
                            _searchingMarket = m;
                            _manualSearchController.text = widget.title; // Pre-fill with title
                            _manualSearchResults = [];
                            _isManualSearching = false;
                         });
                         _performManualSearch(m); // Auto search initially
                      },
                      backgroundColor: Colors.grey.withOpacity(0.1),
                   );
               }) // Add margin to each chip
               .map((w) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: w))
               .toList(),
            )
         ],
      );
  }

  Widget _buildInlineSearch(BuildContext context, String marketName) {
      return Container(
         margin: const EdgeInsets.only(bottom: 8.0), // Margin bottom for the container
         width: double.infinity,
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
         child: Column(
            children: [
                Row(
                   children: [
                      Text('Buscar en $marketName', style: TextStyle(fontWeight: FontWeight.bold, color: MarketStyle.get(marketName).primaryColor)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => setState(() => _searchingMarket = null))
                   ]
                ),
                Row(
                   children: [
                      Expanded(
                         child: TextField(
                            controller: _manualSearchController,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), hintText: 'Nombre del producto...'),
                            style: const TextStyle(fontSize: 13),
                            onSubmitted: (_) => _performManualSearch(marketName),
                         )
                      ),
                      IconButton(icon: const Icon(Icons.search), onPressed: () => _performManualSearch(marketName))
                   ],
                ),
                if (_isManualSearching)
                   const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator())
                else if (_manualSearchResults.isNotEmpty) 
                   Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                         shrinkWrap: true,
                         itemCount: _manualSearchResults.length,
                         separatorBuilder: (_, __) => const Divider(height: 1),
                         itemBuilder: (ctx, i) {
                             final p = _manualSearchResults[i];
                             return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: p.imageUrl != null 
                                   ? SizedBox(
                                       width: 40, height: 40,
                                       child: InkWell(
                                          onTap: () => _showImagePreview(context, p.imageUrl!),
                                          child: CachedNetworkImage(
                                             imageUrl: p.imageUrl!, 
                                             fit: BoxFit.cover,
                                             placeholder: (_,__) => const Center(child: Icon(Icons.image, size: 20, color: Colors.grey)),
                                             errorWidget: (_,__,___) => const Icon(Icons.error, size: 20),
                                          ),
                                       ),
                                     )
                                   : const SizedBox(width: 40),
                                 title: Text(p.name.toTitleCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                 subtitle: Text('\$${p.price}', style: const TextStyle(fontSize: 12)),
                                trailing: ElevatedButton(
                                   style: ElevatedButton.styleFrom(minimumSize: const Size(60, 25), padding: EdgeInsets.zero),
                                   child: const Text('Vincular', style: TextStyle(fontSize: 10)),
                                   onPressed: () => _submitMatchReport(marketName, p)
                                ),
                             );
                         }
                      ),
                   )
                else if (_manualSearchController.text.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.all(8), 
                        child: Column(
                           children: [
                               const Text('No hay resultados.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                               TextButton(
                                  child: Text('Sugerir Manualmente en $marketName', style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                     // Suggest missing product
                                     _initiateManualSuggestion(marketName);
                                  },
                               )
                           ]
                        )
                    )
            ]
         ),
      );
  }



  void _initiateManualSuggestion(String marketName) {
      // Allow suggesting correction for a missing market
      setState(() {
         // We pretend to select this market to show the form? 
         // Or we just flag it.
         // Let's set a temp flag so the form knows we are adding NEW data for `marketName`
         // instead of editing existing.
         _selectedMarketName = marketName; 
         _showCorrectionForm = true; 
         _searchingMarket = null; // Close search
         
         // Clear controllers
         _correctionPriceController.clear();
         _correctionOfferController.clear();
      });
  }

  Future<void> _performManualSearch(String marketName) async {
       if (_manualSearchController.text.isEmpty) return;
       setState(() { _isManualSearching = true; _manualSearchResults = []; });
       
       final provider = Provider.of<ProductProvider>(context, listen: false);
       final results = await provider.searchMarketTransient(_manualSearchController.text, marketName);
       
       setState(() {
          _isManualSearching = false;
          _manualSearchResults = results;
       });
  }

  Future<void> _submitMatchReport(String marketName, Product matchedProduct) async {
      // 1. Link Locally Immediately (UI Update)
      Provider.of<ProductProvider>(context, listen: false).manualLinkProduct(widget.result, marketName, matchedProduct);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Vinculado! Se envió el reporte para validación.')));
         setState(() => _searchingMarket = null);
         // Force redraw of parents if needed by popping or setState? 
         // The Provider notifyListeners should handle it, but this Dialog uses `widget.products` which is passed in.
         // Wait, `ProductCard` is the parent. We might need to close and reopen or just accept that the Dialog
         // content might not refresh fully unless we are reactive to the Provider HERE too.
         // BUT, we are closing the dialog usually? No, user wants to see it "vinculado".
         // Let's close the dialog to force refresh in list, OR better:
         Navigator.of(context).pop(); 
      }

      // 2. Construct report
      final msg = "Usuario ID MATCH:\n"
                  "Original EAN: ${widget.result.ean}\n"
                  "Original Name: ${widget.result.name}\n"
                  "-- MATCHED WITH --\n"
                  "Market: $marketName\n"
                  "Matched Name: ${matchedProduct.name}\n"
                  "Matched Price: ${matchedProduct.price}\n"
                  "Matched EAN: ${matchedProduct.ean}"; 
      
      await ReportService.submitReport("Vinculación Manual", msg);
  }

  Widget _buildReportSection(BuildContext context, Product selectedProd) {
      if (_showCorrectionForm) {
         return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Sugerir Corrección ($_selectedMarketName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 12),
               TextField(
                  controller: _correctionPriceController,
                  decoration: const InputDecoration(labelText: 'Precio Correcto (Opcional)', prefixText: '\$ '),
                  keyboardType: TextInputType.number,
               ),
               const SizedBox(height: 8),
               TextField(
                  controller: _correctionOfferController,
                  decoration: const InputDecoration(labelText: 'Oferta (ej: 2da al 50%, 3x2)'),
               ),
               const SizedBox(height: 12),
               Row(
                  children: [
                     ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_correctionImage == null ? 'Subir Foto' : 'Foto cargada'),
                        style: ElevatedButton.styleFrom(backgroundColor: _correctionImage != null ? Colors.green : null),
                        onPressed: _pickImage,
                     ),
                     if (_correctionImage != null)
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _correctionImage = null))
                  ],
               ),
               const SizedBox(height: 16),
               Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                     TextButton(
                        onPressed: () => setState(() => _showCorrectionForm = false),
                        child: const Text('Cancelar')
                     ),
                     const SizedBox(width: 8),
                     ElevatedButton(
                        onPressed: () => _submitCorrectionReport(selectedProd),
                        child: const Text('Enviar Reporte')
                     )
                  ],
               )
            ],
         );
      }
  
      // Show Bulk Reporting "Checkbox list" style
      return Column(
          children: [
              if (_pendingReports.isNotEmpty) _buildSocialVotingCard(),
              Consumer<ReportProvider>(
                builder: (context, reportProvider, child) {
                   final isReported = reportProvider.isReported(widget.result);
                   return ExpansionTile(
                      // Use a key to force rebuild if needed, though Consumer handles it
                      title: const Text('Reportar Error', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      children: [
                          if (isReported)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(children: [
                                   const Icon(Icons.check_circle, color: Colors.green),
                                   const SizedBox(width: 8),
                                   const Expanded(child: Text('Agregado a reportes.', style: TextStyle(color: Colors.green))),
                                   TextButton(onPressed: () => reportProvider.removeItem(widget.result), child: const Text('Deshacer'))
                                ]),
                              )
                          else ...[
                              Text('Marcá los que tengan precio/nombre erróneo:', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              // Checkboxes for PRESENT markets
                              ...widget.products.map((p) {
                                  final style = p['style'] as MarketStyle;
                                  return CheckboxListTile(
                                      visualDensity: VisualDensity.compact,
                                      dense: true,
                                      title: Text(style.name, style: TextStyle(color: style.primaryColor)),
                                      value: _selectedBadMarkets.contains(style.name),
                                      activeColor: Colors.orange,
                                      onChanged: (val) {
                                          setState(() {
                                              if (val == true) _selectedBadMarkets.add(style.name);
                                              else _selectedBadMarkets.remove(style.name);
                                          });
                                      }
                                  );
                              }).toList(),
                              if (_selectedBadMarkets.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        ElevatedButton(
                                            onPressed: () {
                                              reportProvider.addItem(
                                                widget.result, 
                                                _selectedBadMarkets.toSet(),
                                                note: _reportNoteController.text.isNotEmpty ? _reportNoteController.text : null,
                                              );
                                              // Clear note after adding if desired, or keep it. 
                                              // Let's clear to avoid confusion if they report another thing.
                                              _reportNoteController.clear();
                                              setState(() => _isNoteExpanded = false);
                                            },
                                            child: const Text('Reportar Selección')
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => setState(() => _isNoteExpanded = !_isNoteExpanded),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('Dejar mensaje ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                Icon(
                                                  _isNoteExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          height: _isNoteExpanded ? 80 : 0,
                                          curve: Curves.easeInOut,
                                          child: _isNoteExpanded 
                                            ? TextField(
                                                controller: _reportNoteController,
                                                maxLines: 2,
                                                style: const TextStyle(fontSize: 12),
                                                decoration: InputDecoration(
                                                  hintText: 'Escribí tu mensaje aquí...',
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                  isDense: true,
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  )
                          ]
                      ],
                   );
                }
              ),
              const Divider(),
              // Detailed Correction (Single)
              Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    const Text('¿Querés corregir un dato específico?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 14),
                        label: Text('Sugerir Edición ($_selectedMarketName)', style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                           setState(() {
                               _showCorrectionForm = true;
                               _correctionPriceController.text = selectedProd.price.toStringAsFixed(0);
                               _correctionOfferController.text = _getSpecialOfferText(selectedProd.promoDescription);
                           });
                        },
                        style: OutlinedButton.styleFrom(
                           minimumSize: const Size(0, 36),
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        ),
                    )
                 ],
              )
          ],
      );
  }

  Future<void> _pickImage() async {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70); // Compress on the fly
      if (image != null) {
         setState(() => _correctionImage = image);
      }
  }

  Future<void> _submitCorrectionReport(Product product) async {
     final double? suggestedPrice = double.tryParse(_correctionPriceController.text);
     final String suggestedOffer = _correctionOfferController.text;

     String? uploadedUrl;
     
     // 1. Show Loading UI
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Procesando reporte...')));

     // 2. Handle Image Upload & NSFW Check
     if (_correctionImage != null) {
        final fileName = 'corr_${widget.result.ean}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedUrl = await CorrectionService.uploadImage(File(_correctionImage!.path), fileName);
        
        if (uploadedUrl != null) {
           // NSFW CHECK
           ScaffoldMessenger.of(context).hideCurrentSnackBar();
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verificando imagen...')));
           
           final nsfwResult = await CorrectionService.checkNsfw(uploadedUrl);
           final bool isSafe = nsfwResult['isSafe'] ?? true;
           final String status = nsfwResult['status'] ?? 'unknown';

           if (!isSafe) {
              if (mounted) {
                 ScaffoldMessenger.of(context).hideCurrentSnackBar();
                 showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                       title: const Text('Imagen Inapropiada'),
                       content: const Text('Nuestro sistema detectó que la imagen podría ser inapropiada. Por favor, subí una foto clara del producto/precio.'),
                       actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
                    )
                 );
                 setState(() => _correctionImage = null);
              }
              return; // BLOCKED
           }

           if (status == 'timeout_pending_review' && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen en revisión, el reporte se procesará igual.')));
           }
        }
     }

     // 3. Final Submit
     bool success = await CorrectionService.submitReport(
        ean: product.ean.isNotEmpty ? product.ean : 'NO-EAN',
        market: _selectedMarketName,
        suggestedPrice: suggestedPrice,
        suggestedOffer: suggestedOffer.isNotEmpty ? suggestedOffer : null,
        originalName: product.name,
        imageUrl: uploadedUrl, // PASS THE URL
     );

     if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias! Tu reporte fue subido con éxito.')));
            setState(() { _showCorrectionForm = false; _correctionImage = null; });
        } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor esperá unos minutos antes de enviar otro reporte.')));
        }
     }
  }

  Widget _buildSocialVotingCard() {
     return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
           color: Colors.blue.withOpacity(0.1),
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Row(
                 children: [
                    const Icon(Icons.people, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text('Aporte de la Comunidad', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const Spacer(),
                    Text('${_pendingReports.length} reporte(s)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                 ],
              ),
              const SizedBox(height: 8),
              ..._pendingReports.map((report) {
                 final price = report['suggested_price'];
                 final offer = report['suggested_offer'];
                 final img = report['image_url'];
                 
                 return Column(
                    children: [
                       const Divider(height: 16),
                       Row(
                          children: [
                             Expanded(
                                child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      Text('Dicen que está a: \$${price ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (offer != null) Text('Oferta: $offer', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                   ],
                                ),
                             ),
                             if (img != null)
                                GestureDetector(
                                   onTap: () => _showImagePreview(context, img),
                                   child: Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                         borderRadius: BorderRadius.circular(4),
                                         image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                                      ),
                                   ),
                                ),
                             const SizedBox(width: 8),
                             IconButton(
                                icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.green),
                                onPressed: () => _handleVote(report['id'], true),
                             ),
                             IconButton(
                                icon: const Icon(Icons.thumb_down_alt_outlined, color: Colors.red),
                                onPressed: () => _handleVote(report['id'], false),
                             ),
                          ],
                       ),
                    ],
                 );
              }).toList(),
           ],
        ),
     );
  }

  Future<void> _handleVote(String reportId, bool isUpvote) async {
     final ok = await CorrectionService.voteReport(reportId, isUpvote);
     if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Voto registrado! Gracias.')));
        _fetchSocialReports(); // Refresh
     }
  }



  void _showImagePreview(BuildContext context, String url) {
     showDialog(
        context: context,
        builder: (_) => Dialog(
           child: Stack(
              children: [
                 InteractiveViewer(child: Image.network(url)),
                 Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
                 Positioned(
                    bottom: 10, right: 10, 
                    child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8), foregroundColor: Colors.white),
                        icon: const Icon(Icons.flag, size: 16),
                        label: const Text('Reportar Foto/Error'),
                        onPressed: () {
                           Navigator.pop(context); // Close preview
                           // Open report dialog pre-filled? Or Show dedicated mismatch dialog?
                           // User said: "mira la foto... ve que es el six pack... reportar eso"
                           // Let's use submitReport directly or open a form.
                           // Simpler: Show confirmation to report "Bad Match"
                           showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                 title: const Text('¿Reportar error en la foto/producto?'),
                                 content: const Text('¿Esta foto no corresponde al producto o el precio es muy diferente (ej: unidad vs pack)?'),
                                 actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                    ElevatedButton(
                                       style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                       onPressed: () async {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando reporte...')));
                                          
                                          // Send report for this specific market's EAN/Link
                                          // We need to know WHICH market this URL belongs to. 
                                          // The `_showImagePreview` only gets URL. We should pass the market name too.
                                          // Refactor needed: pass marketName to _showImagePreview.
                                          // For now, we use _selectedMarketName?
                                          // But this preview might come from Search Result (Thumbnail) which passes just URL.
                                          // Let's defer this logic or assume Generic Report.
                                          
                                          await ReportService.submitReport("Error Foto/Vinculación", "El usuario reportó que la imagen/producto vinculado es incorrecto.\nURL: $url");
                                          
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gracias. Revisaremos este vínculo.')));
                                       }, 
                                       child: const Text('Si, Reportar')
                                    )
                                 ],
                              )
                           );
                        }
                    )
                 ),
              ],
           ),
        ),
     );
  }
}

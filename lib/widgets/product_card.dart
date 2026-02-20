import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'product_detail_dialog.dart';

import '../models/product.dart';
import '../utils/market_branding.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/report_provider.dart';
import 'loading_dots.dart';
import '../utils/string_extensions.dart';

class ProductCard extends StatefulWidget {
  final ComparisonResult result;
  final bool isHorizontal;
  final Set<String> activeMarkets;

  const ProductCard({
    Key? key,
    required this.result,
    this.isHorizontal = false,
    required this.activeMarkets,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String? _selectedMarketName;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ProductProvider>(context, listen: false).enrichResult(widget.result);
    });
  }

  void _initializeSelection() {
    // Determine initial cheapest market among active comparisons
    final products = _getAvailableProducts();
    if (products.isNotEmpty) {
      products.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
      _selectedMarketName = (products.first['style'] as MarketStyle).name;
    }
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
        _initializeSelection();
        Provider.of<ProductProvider>(context, listen: false).enrichResult(widget.result);
    } else if (oldWidget.activeMarkets != widget.activeMarkets) {
        _initializeSelection();
    }
  }

  List<Map<String, Object>> _getAvailableProducts() {
    final result = widget.result;
    final pM = widget.activeMarkets.contains('Monarca') ? result.monarcaProduct : null;
    final pC = widget.activeMarkets.contains('Carrefour') ? result.carrefourProduct : null;
    final pL = widget.activeMarkets.contains('La Coope') ? result.coopeProduct : null;
    final pV = widget.activeMarkets.contains('Vea') ? result.veaProduct : null;

    final list = <Map<String, Object>>[
      if (pM != null && pM.price > 0) {'pool': 'M', 'price': pM.price, 'style': MarketStyle.monarca, 'prod': pM},
      if (pC != null && pC.price > 0) {'pool': 'C', 'price': pC.price, 'style': MarketStyle.carrefour, 'prod': pC},
      if (pL != null && pL.price > 0) {'pool': 'L', 'price': pL.price, 'style': MarketStyle.cooperativa, 'prod': pL},
      if (pV != null && pV.price > 0) {'pool': 'V', 'price': pV.price, 'style': MarketStyle.vea, 'prod': pV},
    ];
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final availableProducts = _getAvailableProducts();
    
    // If no products visible, hide
    if (availableProducts.isEmpty) return const SizedBox.shrink();

    // Sort by price to find "Best"
    final sortedProducts = List<Map<String, Object>>.from(availableProducts);
    sortedProducts.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
    
    final bestOption = sortedProducts.first;
    final bestMarketName = (bestOption['style'] as MarketStyle).name;
    
    // Ensure selected is valid, else fallback to best
    if (_selectedMarketName == null || !availableProducts.any((p) => (p['style'] as MarketStyle).name == _selectedMarketName)) {
       _selectedMarketName = bestMarketName;
    }

    // Identify current display product (for image/title)
    Map<String, Object> selectedProductMap;
    try {
      selectedProductMap = availableProducts.firstWhere((p) => (p['style'] as MarketStyle).name == _selectedMarketName);
    } catch (_) {
      selectedProductMap = bestOption;
    }
    
    final displayProduct = selectedProductMap['prod'] as Product;
    
    // Image, Title, Subtitle Logic
    final imageUrl = displayProduct.imageUrl;
    String title = widget.result.name;
    String subtitle = '';

    String brand = (displayProduct.brand ?? '').toTitleCase();
    String name = widget.result.name.toTitleCase();
    if (name == 'Unknown' || name.isEmpty) name = displayProduct.name.toTitleCase();
    
    if (brand.isNotEmpty) {
        title = brand;
        subtitle = name.replaceAll(RegExp(brand, caseSensitive: false), '').trim();
    } else {
        List<String> words = name.split(' ');
        if (words.length > 2) {
           title = words.take(2).join(' ');
           subtitle = words.skip(2).join(' ');
        }
    }
    String presentation = displayProduct.presentation;
    if (presentation.isNotEmpty) subtitle = '$subtitle $presentation'.trim();

    // Missing Markets
    // Missing Markets & Loading State
    final provider = Provider.of<ProductProvider>(context); // Listen to changes
    final missingMarkets = <String>[];
    final loadingMarkets = <String>[];

    void checkMarketState(String marketName, Product? product) {
       if (widget.activeMarkets.contains(marketName)) {
          if (product == null) {
             if (provider.isMarketEnriching(widget.result, marketName)) {
                loadingMarkets.add(marketName);
             } else {
                missingMarkets.add(marketName);
             }
          }
       }
    }

    checkMarketState('Monarca', widget.result.monarcaProduct);
    checkMarketState('Carrefour', widget.result.carrefourProduct);
    checkMarketState('La Coope', widget.result.coopeProduct);
    checkMarketState('Vea', widget.result.veaProduct);

    // UI Builders
    Widget buildImageAndTitle() {
      // Logic from HomeScreen...
       return InkWell(
        onTap: () => _showProductDetail(context, title, subtitle, imageUrl, availableProducts, _selectedMarketName),
        child: Column(
          children: [
              if (imageUrl != null)
                Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl, 
                      height: widget.isHorizontal ? 80 : 100, 
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(child: Icon(Icons.shopping_bag, color: Colors.grey)),
                      errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                    if (displayProduct.oldPrice != null && displayProduct.oldPrice! > displayProduct.price)
                       _buildPromoBadge(displayProduct),
                  ],
                )
             else 
                Icon(Icons.shopping_bag, size: widget.isHorizontal ? 50 : 80, color: Colors.grey),
             
             if (!widget.isHorizontal) ...[
                 const SizedBox(height: 8),
                 Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
                 )),
                 if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
             ]
          ],
        ),
      );
    }
    
    final allTags = <Widget>[
       if (widget.activeMarkets.contains('Monarca') && widget.result.monarcaProduct != null) 
          _buildSelectableTag(MarketStyle.monarca, widget.result.monarcaProduct!, bestMarketName),
       if (widget.activeMarkets.contains('Carrefour') && widget.result.carrefourProduct != null) 
          _buildSelectableTag(MarketStyle.carrefour, widget.result.carrefourProduct!, bestMarketName),
       if (widget.activeMarkets.contains('La Coope') && widget.result.coopeProduct != null) 
          _buildSelectableTag(MarketStyle.cooperativa, widget.result.coopeProduct!, bestMarketName),
       if (widget.activeMarkets.contains('Vea') && widget.result.veaProduct != null) 
          _buildSelectableTag(MarketStyle.vea, widget.result.veaProduct!, bestMarketName),
       
       // Loading Chip
       if (loadingMarkets.isNotEmpty)
          _buildLoadingChip(loadingMarkets),
    ];
    
    // Add logic
    void onAdd() {
       final productToAdd = selectedProductMap['prod'] as Product;
       final bestProduct = bestOption['prod'] as Product;
       
       Provider.of<CartProvider>(context, listen: false).addItem(
          productToAdd,
          bestMarket: bestMarketName,
          bestPrice: bestProduct.price
       );
       ScaffoldMessenger.of(context).hideCurrentSnackBar();
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text('Agregado: ${productToAdd.source} (\$${productToAdd.price})'), 
             duration: const Duration(milliseconds: 500)
          ),
       );
    }

    if (!widget.isHorizontal) {
       // Vertical Layout
       return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             Expanded(child: buildImageAndTitle()),
             const SizedBox(height: 4),
             // Tags Row
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: allTags.expand((w) => [Expanded(child: w), const SizedBox(width: 4)]).take(allTags.length * 2 - 1).toList(),
             ),
             // Footer
             Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                      if (missingMarkets.isNotEmpty)
                         Text('${missingMarkets.join(', ')} no hay coincidencias', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           // Correction Check
                           Consumer<ProductProvider>(
                               builder: (context, provider, child) {
                                   final correction = provider.getCorrectionForProduct(displayProduct);
                                   if (correction != null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: InkWell(
                                          onTap: () => _showCorrectionDialog(context, correction, provider),
                                          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                        ),
                                      );
                                   }
                                   return const SizedBox.shrink();
                               }
                           ),
                           // TODO: Savings Badge logic adjusted for selection?
                           // Currently keeping simple: If selected != best, maybe show "Perdida"?
                           // Or just keep the general "Ahorra" if selected is best.
                           if (_selectedMarketName == bestMarketName && availableProducts.length > 1)
                              _buildSavingsBadge((sortedProducts.last['price'] as double) - (bestOption['price'] as double)),
                           if (_selectedMarketName == bestMarketName && availableProducts.length > 1)
                              const SizedBox(width: 8),
                           
                           Consumer<CartProvider>(
                             builder: (context, cart, child) {
                               final productToAdd = selectedProductMap['prod'] as Product;
                               final bestProduct = bestOption['prod'] as Product;
                               
                               // Check if item is in cart (matching EAN/Name + Source)
                               final cartItemIndex = cart.items.indexWhere((item) {
                                  bool sameProduct = (item.product.ean.isNotEmpty && item.product.ean == productToAdd.ean) ||
                                                     (item.product.name == productToAdd.name);
                                  return sameProduct && item.product.source == productToAdd.source;
                               });
                               
                               final isInCart = cartItemIndex >= 0;
                               final quantity = isInCart ? cart.items[cartItemIndex].quantity : 0;

                               if (isInCart) {
                                  return Container(
                                    // Removed height: 30
                                    decoration: BoxDecoration(
                                      color: (selectedProductMap['style'] as MarketStyle).primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: (selectedProductMap['style'] as MarketStyle).primaryColor)
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                             if (quantity > 1) {
                                                cart.removeSingleItem(cart.items[cartItemIndex]);
                                             } else {
                                                cart.removeSingleItem(cart.items[cartItemIndex]); 
                                             }
                                          },
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                          child: SizedBox(
                                            width: 48, 
                                            height: 40,
                                            child: Icon(Icons.remove, size: 24, color: (selectedProductMap['style'] as MarketStyle).primaryColor),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text('$quantity', style: TextStyle(fontWeight: FontWeight.bold, color: (selectedProductMap['style'] as MarketStyle).primaryColor)),
                                        ),
                                        InkWell(
                                          onTap: () => cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: bestProduct.price),
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                                          child: SizedBox(
                                            width: 48, 
                                            height: 40,
                                            child: Icon(Icons.add, size: 24, color: (selectedProductMap['style'] as MarketStyle).primaryColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                               }

                               return ElevatedButton.icon(
                                 onPressed: onAdd,
                                 icon: const Icon(Icons.add_shopping_cart, size: 16),
                                 label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                                 style: ElevatedButton.styleFrom(
                                    backgroundColor: (selectedProductMap['style'] as MarketStyle).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                 ),
                               );
                             }
                           )
                        ]
                      )
                   ]
                ),
             )
          ],
       );
    } else {
       // Horizontal Layout (Search)
       return Row(
          children: [
             SizedBox(width: 100, child: buildImageAndTitle()), // Reuse image part
             Expanded(
                child: Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Title & Subtitle Horizontal
                         Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         Row(children: [
                            Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            const SizedBox(width: 8),
                            // Missing Markets X
                            if (missingMarkets.isNotEmpty)
                               Row(children: missingMarkets.map((m) => Text('$m X ', style: const TextStyle(color: Colors.red, fontSize: 10))).toList())
                         ]),
                         const SizedBox(height: 8),
                         // Tags
                         Row(children: allTags.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 4), child: w))).toList()),
                         const SizedBox(height: 8),
                         // Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                                // Correction Check Horizontal
                                Consumer<ProductProvider>(
                                   builder: (context, provider, child) {
                                       final correction = provider.getCorrectionForProduct(displayProduct);
                                       if (correction != null) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: InkWell(
                                              onTap: () => _showCorrectionDialog(context, correction, provider),
                                              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                            ),
                                          );
                                       }
                                       return const SizedBox.shrink();
                                   }
                                ),

                                if (_selectedMarketName == bestMarketName && availableProducts.length > 1)
                                   _buildSavingsBadge((sortedProducts.last['price'] as double) - (bestOption['price'] as double)),
                                const SizedBox(width: 8),
                               Consumer<CartProvider>(
                                 builder: (context, cart, child) {
                                   final productToAdd = selectedProductMap['prod'] as Product;
                                   final bestProduct = bestOption['prod'] as Product;
                                   
                                   final cartItemIndex = cart.items.indexWhere((item) {
                                      bool sameProduct = (item.product.ean.isNotEmpty && item.product.ean == productToAdd.ean) ||
                                                         (item.product.name == productToAdd.name);
                                      return sameProduct && item.product.source == productToAdd.source;
                                   });
                                   
                                   final isInCart = cartItemIndex >= 0;
                                   final quantity = isInCart ? cart.items[cartItemIndex].quantity : 0;

                                   if (isInCart) {
                                    return Container(
                                      // Removed fixed height: 30 to allow touch targets to size the container
                                      decoration: BoxDecoration(
                                        color: (selectedProductMap['style'] as MarketStyle).primaryColor.withOpacity(0.15), // Elegant opacity
                                        borderRadius: BorderRadius.circular(24), // Increased radius for taller pill
                                        border: Border.all(color: (selectedProductMap['style'] as MarketStyle).primaryColor.withOpacity(0.5))
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                               if (quantity > 1) {
                                                  cart.removeSingleItem(cart.items[cartItemIndex]);
                                               } else {
                                                  cart.removeSingleItem(cart.items[cartItemIndex]); 
                                               }
                                            },
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                            child: SizedBox(
                                              width: 48, 
                                              height: 40,
                                              child: Icon(Icons.remove, size: 24, color: (selectedProductMap['style'] as MarketStyle).primaryColor),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Text('$quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: (selectedProductMap['style'] as MarketStyle).primaryColor)),
                                          ),
                                          InkWell(
                                            onTap: () => cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: bestProduct.price),
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                                            child: SizedBox(
                                              width: 48, 
                                              height: 40,
                                              child: Icon(Icons.add, size: 24, color: (selectedProductMap['style'] as MarketStyle).primaryColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                   }

                                   return ElevatedButton.icon(
                                     onPressed: onAdd,
                                     icon: const Icon(Icons.add_shopping_cart, size: 18),
                                     label: const Text('Agregar'),
                                     style: ElevatedButton.styleFrom(
                                        backgroundColor: (selectedProductMap['style'] as MarketStyle).primaryColor.withOpacity(0.9), // Elegant
                                        foregroundColor: Colors.white,
                                        elevation: 0, // Flat elegant
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                     ),
                                   );
                                 }
                               )
                            ],
                          )
                      ]
                   ),
                )
             )
          ],
       );
    }
  }

   Widget _buildSelectableTag(MarketStyle style, Product product, String bestMarketName) {
     final isSelected = style.name == _selectedMarketName;
     final isBest = style.name == bestMarketName;
     final isDark = Theme.of(context).brightness == Brightness.dark;
     
     // Elegant Styles
     Color baseBg = isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!;
     
     if (isSelected) {
        baseBg = style.primaryColor.withOpacity(0.15); // Subtle selection
     } else if (isBest) {
        baseBg = Colors.green.withOpacity(0.1); // Subtle best
     }
     
     Border? border;
     if (isSelected) border = Border.all(color: style.primaryColor.withOpacity(0.6), width: 1.5);
     else if (isBest) border = Border.all(color: Colors.green.withOpacity(0.5), width: 1.5);
     else border = Border.all(color: Colors.transparent, width: 1.5);

     // Text Colors - CRITICAL: In Dark Mode, user wants WHITE text even if best/selected
     Color nameColor = isDark ? Colors.white70 : Colors.black87;
     Color priceColor = isDark ? Colors.white : Colors.black;

     if (isSelected && !isDark) {
         nameColor = style.primaryColor;
         priceColor = style.primaryColor;
     } else if (isSelected && isDark) {
         // In dark mode selected: keep white text, maybe colored icon/indicator if we had one
         nameColor = HSLColor.fromColor(style.primaryColor).withLightness(0.8).toColor(); // Lighter version of primary
         priceColor = Colors.white;
     }
     
     // Best overrides
     if (isBest && !isSelected) {
         priceColor = isDark ? Colors.greenAccent[100]! : Colors.green[800]!;
     }

     return InkWell(
        onTap: () {
           setState(() {
              _selectedMarketName = style.name;
           });
        },
        child: AnimatedContainer(
           duration: const Duration(milliseconds: 200),
           padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
           constraints: const BoxConstraints(minHeight: 50),
           decoration: BoxDecoration(
              color: baseBg,
              borderRadius: BorderRadius.circular(8),
              border: border
           ),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text(style.name, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold,
                    color: nameColor
                 )),
                 Text(
                   NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0).format(product.price),
                   style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 13,
                      color: priceColor
                   ),
                 )
              ]
           ),
        ),
     );
  }

  Widget _buildLoadingChip(List<String> markets) {
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints: const BoxConstraints(minHeight: 45),
        decoration: BoxDecoration(
           color: Colors.grey.withOpacity(0.1),
           borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              SizedBox(
                 width: 12, height: 12, 
                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400])
              ),
              const SizedBox(height: 4),
              Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 mainAxisSize: MainAxisSize.min,
                 children: markets.take(2).map((m) { // Show max 2 letters to save space
                    final style = MarketStyle.get(m);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.0),
                      child: Text(
                         m[0], 
                         style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: style.primaryColor
                         )
                      ),
                    ); 
                 }).toList(),
              )
           ]
        )
     );
  }

  Widget _buildSavingsBadge(double savings) {
     if (savings <= 0) return const SizedBox.shrink();
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(
           'Ahorrá \$${savings.toStringAsFixed(0)}',
           style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
        ),
     );
  }

  Widget _buildPromoBadge(Product p) {
      String text = '';
      Color badgeColor = Colors.red;
      Color textColor = Colors.white;

      // 1. Check for SPECIAL OFFERS (Blue Badge)
      if (p.promoDescription != null) {
          final desc = p.promoDescription!.toLowerCase();
          if (desc.contains(RegExp(r'\b(2da|3ra|4ta|segunda|tercera|cuarta|3x2|4x3|2x1)\b'))) {
             text = p.promoDescription!.toUpperCase();
             // Try to shorten: "2DA AL 50%" -> "2DA -50%"
             text = text.replaceAll('AL ', ' -').replaceAll(' AL', ' -');
             if (text.length > 10) text = text.substring(0, 10); // Clamp
             
             badgeColor = Colors.blue; 
             textColor = Colors.white;
          }
      }

      // 2. Fallback to Percentage / Flat offer
      if (text.isEmpty) {
          // New Logic: Check text claims FIRST if they look like a percentage
          if (p.promoDescription != null && p.promoDescription!.contains('%')) {
             final pctMatch = RegExp(r'(\d+)%').firstMatch(p.promoDescription!);
             if (pctMatch != null) {
                text = "${pctMatch.group(1)}% OFF";
             }
          }
          
          // If no text claim found (or no %), try Math
          if (text.isEmpty && p.oldPrice != null && p.oldPrice! > p.price) {
            int pct = (((p.oldPrice! - p.price) / p.oldPrice!) * 100).round();
            text = "$pct% OFF";
          } 
          
          // Only fallback to "OFERTA" if math failed and text exists but has no %
          if (text.isEmpty && p.promoDescription != null && !p.promoDescription!.contains('%')) {
             if (p.promoDescription!.length < 10) text = p.promoDescription!;
             else text = "OFERTA";
          }
      }

      if (text.isEmpty) return const SizedBox.shrink();

      return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: badgeColor,
           borderRadius: BorderRadius.circular(4),
         ),
         child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
      );
  }

  // --- Correction Dialog ---
  
  void _showCorrectionDialog(BuildContext context, dynamic correction, ProductProvider provider) {
      showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Reporte Comunidad', style: TextStyle(fontSize: 16))
              ],
            ),
            content: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                   if (correction.user != null)
                      Text('Usuario: ${correction.user}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                   const SizedBox(height: 8),
                   Text(correction.message ?? 'Sin comentario adicional.'),
                   if (correction.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      // Ideally use cached network image
                      Image.network(
                        correction.imageUrl!, 
                        height: 100, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                        errorBuilder: (_,__,___) => const SizedBox.shrink()
                      ),
                   ],
                   const SizedBox(height: 12),
                   if (correction.suggestedPrice != null) ...[
                      const Text('Precio Sugerido:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${correction.suggestedPrice}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                   ]
               ],
            ),
            actions: [
               TextButton(
                 onPressed: () => Navigator.pop(ctx), 
                 child: const Text('Cerrar')
               ),
               if (correction.suggestedPrice != null)
                   FilledButton.icon(
                      onPressed: () {
                         Product? targetProduct;
                         if (_selectedMarketName == 'Monarca') targetProduct = widget.result.monarcaParam;
                         else if (_selectedMarketName == 'Carrefour') targetProduct = widget.result.carrefourParam;
                         else if (_selectedMarketName == 'La Coope') targetProduct = widget.result.coopeParam;
                         else if (_selectedMarketName == 'Vea') targetProduct = widget.result.veaParam;
                         
                         if (targetProduct != null) {
                             provider.acceptCorrectionPrice(targetProduct, correction.suggestedPrice!);
                             Navigator.pop(ctx);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                               content: Text('Precio actualizado por esta sesión.'), 
                               backgroundColor: Colors.orange,
                               duration: Duration(seconds: 2),
                             ));
                         } else {
                             Navigator.pop(ctx);
                         }
                      }, 
                      icon: const Icon(Icons.check),
                      label: const Text('Le creo'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                   )
            ],
         )
      );
  }

  void _showProductDetail(BuildContext context, String title, String subtitle, String? imageUrl, List<Map<String, Object>> products, String? selectedMarketName) {
       showDialog(
        context: context,
        builder: (ctx) => ProductDetailDialog(
           title: title, 
           subtitle: subtitle, 
           imageUrl: imageUrl, 
           products: products, 
           initialSelectedMarketName: selectedMarketName, 
           result: widget.result
        ),
      );
  }

  // Internal helper removed, using string_extensions.dart
}

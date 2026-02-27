import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'product_detail_dialog.dart';
import '../screens/cart_screen.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../utils/market_branding.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/report_provider.dart';
import 'loading_dots.dart';
import '../utils/string_extensions.dart';
import 'lottie_add_to_cart_button.dart';
import 'product_report_history_modal.dart';

class ProductCard extends StatefulWidget {
  final ProductComparisonResult result;
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
      final firstStyle = products.first['style'];
      if (firstStyle is MarketStyle) {
        _selectedMarketName = firstStyle.name;
      }
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
    if (availableProducts.isEmpty) return const SizedBox.shrink();

    final sortedProducts = List<Map<String, Object>>.from(availableProducts);
    sortedProducts.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
    
    final bestOption = sortedProducts.first;
    final bestMarketName = (bestOption['style'] as MarketStyle).name;
    
    if (_selectedMarketName == null || !availableProducts.any((p) => (p['style'] as MarketStyle).name == _selectedMarketName)) {
       _selectedMarketName = bestMarketName;
    }

    final selectedProductMap = availableProducts.firstWhere(
      (p) => (p['style'] as MarketStyle).name == _selectedMarketName,
      orElse: () => bestOption
    );

    final displayProduct = selectedProductMap['prod'] as Product;
    
    String title = displayProduct.name.toTitleCase();
    if (displayProduct.presentation.isNotEmpty && !title.toLowerCase().contains(displayProduct.presentation.toLowerCase())) {
        title = '$title ${displayProduct.presentation.toTitleCase()}';
    }
    
    final subtitle = (displayProduct.brand ?? '').toTitleCase();
    final imageUrl = displayProduct.imageUrl;

    if (widget.isHorizontal) {
      return _buildHorizontalLayout(context, availableProducts, bestOption, bestMarketName, selectedProductMap, title);
    }

    // Vertical Layout
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ]
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageAndTitle(displayProduct, title, subtitle, imageUrl, availableProducts),
          const SizedBox(height: 16),
          
          // Unified Price Grid
          _buildPriceGrid(availableProducts, bestMarketName, false),

          const SizedBox(height: 16),

          // Footer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_selectedMarketName == bestMarketName && availableProducts.length > 1)
                 _buildSavingsBadge(sortedProducts, bestOption)
              else
                 const SizedBox(),

              // Vertical Counter
              Consumer<CartProvider>(
                 builder: (context, cart, child) {
                   final productToAdd = selectedProductMap['prod'] as Product;
                   final cartItemIndex = cart.items.indexWhere((CartItem item) => 
                     ((item.product.ean.isNotEmpty && item.product.ean != '0' && item.product.ean == productToAdd.ean) || 
                      (item.product.name == productToAdd.name && item.product.presentation == productToAdd.presentation)) && 
                     item.product.source == productToAdd.source
                   );
                   final isInCart = cartItemIndex >= 0;
                   final quantity = isInCart ? cart.items[cartItemIndex].quantity : 0;

                   return LottieAddToCartButton(
                     size: 48,
                     isInCart: isInCart,
                     quantity: quantity,
                     onTap: () => cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: (bestOption['prod'] as Product).price, alternatives: availableProducts.map((opt) => opt['prod'] as Product).toList()),
                     onIncrement: () => cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: (bestOption['prod'] as Product).price, alternatives: availableProducts.map((opt) => opt['prod'] as Product).toList()),
                     onDecrement: isInCart ? () => cart.removeSingleItem(cart.items[cartItemIndex]) : null,
                   );
                 }
              ),
            ],
          )
        ],
      ),
    );
  }

  // Unified helper for grid layout
  Widget _buildPriceGrid(List<Map<String, Object>> products, String bestMarketName, bool compact) {
     final activePills = products.map((p) => buildMarketPill(p['style'] as MarketStyle, p['prod'] as Product, bestMarketName, compact: compact)).toList();
     
     if (activePills.length <= 2) {
       return Row(children: activePills.map((w) => Expanded(child: w)).toList());
     } else if (activePills.length == 3) {
       return Column(
         children: [
           Row(children: [Expanded(child: activePills[0]), Expanded(child: activePills[1])]),
           const SizedBox(height: 4),
           Row(
             children: [
               const Spacer(flex: 1), 
               Expanded(flex: 2, child: activePills[2]), 
               const Spacer(flex: 1)
             ]
           ),
         ],
       );
     } else {
       return Column(
         children: [
           Row(children: [Expanded(child: activePills[0]), Expanded(child: activePills[1])]),
           const SizedBox(height: 4),
           Row(children: [Expanded(child: activePills[2]), Expanded(child: activePills[3])]),
         ],
       );
     }
  }

  // --- Horizontal Layout (Refined) ---
  Widget _buildHorizontalLayout(BuildContext context, List<Map<String, Object>> availableProducts, Map<String, Object> bestOption, String bestMarketName, Map<String, Object> selectedProductMap, String title) {
      final displayProduct = selectedProductMap['prod'] as Product;
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
             // 1. Image
             GestureDetector(
                onTap: () => _showProductDetail(context, displayProduct.name, displayProduct.brand ?? '', displayProduct.imageUrl, availableProducts, _selectedMarketName),
                child: Container(
                  width: 100,
                  height: 130, // Reduced height
                  decoration: const BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.horizontal(left: Radius.circular(24))
                  ),
                  child: Stack(
                    children: [
                      Center( // Center the image vertically/horizontally
                        child: CachedNetworkImage(
                           imageUrl: displayProduct.imageUrl ?? '',
                           fit: BoxFit.contain,
                           placeholder: (_, __) => const Center(child: LoadingDots()),
                           errorWidget: (_,__,___) => const Icon(Icons.image_not_supported, color: Colors.grey)
                        ),
                      ),
                      if (displayProduct.promoDescription != null && displayProduct.promoDescription!.isNotEmpty)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _buildPromoBadge(displayProduct.promoDescription!),
                        ),
                    ],
                  )
                )
             ),
             
             // 2. Info & Grid
             Expanded(
                child: Padding(
                   padding: const EdgeInsets.all(12),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Row(
                            children: [
                               Expanded(
                                  child: Text(
                                     title, 
                                     maxLines: 1, 
                                     overflow: TextOverflow.ellipsis, 
                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                               ),
                               Consumer<ProductProvider>(
                                  builder: (context, prodProvider, child) {
                                    if (!prodProvider.hasAnyReport(widget.result.ean)) return const SizedBox.shrink();
                                    return IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                      onPressed: () {
                                         final rps = prodProvider.productReports[widget.result.ean] ?? [];
                                         showModalBottomSheet(
                                           context: context,
                                           isScrollControlled: true,
                                           backgroundColor: Colors.transparent,
                                           builder: (ctx) => ProductReportHistoryModal(
                                             productName: widget.result.name,
                                             reports: rps,
                                           ),
                                         );
                                      },
                                    );
                                  }
                               ),
                            ],
                         ),
                         if (displayProduct.brand != null)
                             Text(displayProduct.brand!.toTitleCase(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                         
                         const SizedBox(height: 8),
                         
                         // Unified Grid (Compact version)
                         _buildPriceGrid(availableProducts, bestMarketName, true),
                      ]
                   )
                )
             ),
             
             // 3. Add Button (Circular logic)
             Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Consumer<CartProvider>(
                   builder: (context, cart, child) {
                       final productToAdd = selectedProductMap['prod'] as Product;
                       final bestProd = bestOption['prod'] as Product;
                       
                       final cartItemIndex = cart.items.indexWhere((CartItem item) => 
                           ((item.product.ean.isNotEmpty && item.product.ean != '0' && item.product.ean == productToAdd.ean) || 
                            (item.product.name == productToAdd.name && item.product.presentation == productToAdd.presentation)) && 
                           item.product.source == productToAdd.source
                       );
                       final isInCart = cartItemIndex >= 0;
                       
                       return LottieAddToCartButton(
                          size: 32,
                          isInCart: isInCart,
                          quantity: isInCart ? cart.items[cartItemIndex].quantity : 0,
                          onTap: () {
                             if (!isInCart) {
                                cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: bestProd.price, alternatives: availableProducts.map((opt) => opt['prod'] as Product).toList());
                             }
                          },
                          onIncrement: () => cart.addItem(productToAdd, bestMarket: bestMarketName, bestPrice: bestProd.price, alternatives: availableProducts.map((opt) => opt['prod'] as Product).toList()),
                          onDecrement: isInCart ? () => cart.removeSingleItem(cart.items[cartItemIndex]) : null,
                       );
                   }
                )
             )
          ]
        )
      );
  }

  Widget buildMarketPill(MarketStyle style, Product product, String bestMarketName, {bool compact = false}) {
    final isBest = style.name == bestMarketName;
    final isSelected = style.name == _selectedMarketName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool hasDiscount = (product.promoDescription != null && product.promoDescription!.isNotEmpty) || 
                             (product.oldPrice != null && product.oldPrice! > product.price);

    return GestureDetector(
      onTap: () => setState(() => _selectedMarketName = style.name),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? const Color(0xFF00ACC1).withOpacity(0.2) : style.primaryColor.withOpacity(0.15))
              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F7)),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: isSelected 
              ? Border.all(color: style.primaryColor, width: 2)
              : (isBest ? Border.all(color: const Color(0xFF00C853), width: 2) : Border.all(color: Colors.transparent, width: 2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(style.name, style: TextStyle(
                        fontSize: compact ? 9 : 10, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected 
                          ? (isDark 
                              ? (style.name == 'Monarca' ? const Color(0xFFFF600C) : (style.name == 'Carrefour' ? const Color(0xFFFF3E2F) : style.primaryColor))
                              : style.primaryColor)
                          : (isDark ? Colors.white54 : const Color(0xFF9E9E9E))
                      )),
                      Consumer<ProductProvider>(
                        builder: (context, prodProvider, child) {
                          if (prodProvider.hasReportForMarket(widget.result.ean, style.name)) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: compact ? 8 : 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  if (!compact) const SizedBox(height: 2),
                  FittedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0).format(product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: compact ? 13 : 15, 
                            color: isSelected 
                              ? (isDark 
                                  ? (style.name == 'Monarca' ? const Color(0xFFFF600C) : (style.name == 'Carrefour' ? const Color(0xFFFF3E2F) : style.primaryColor))
                                  : style.primaryColor)
                              : (isBest ? (isDark ? Colors.white : const Color(0xFF212121)) : (isDark ? Colors.white60 : const Color(0xFF757575)))
                          ),
                        ),
                        Consumer<CartProvider>(
                          builder: (context, cart, child) {
                            final matchingItemIndex = cart.items.indexWhere((item) => 
                              item.product.source == style.name && 
                              ((item.product.ean == product.ean && product.ean.isNotEmpty && product.ean != '0') || 
                               item.product.name == product.name)
                            );
                            if (matchingItemIndex == -1) return const SizedBox.shrink();
                            final qty = cart.items[matchingItemIndex].quantity;
                            if (qty <= 0) return const SizedBox.shrink();
                            
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                ' x $qty',
                                style: TextStyle(
                                  fontSize: compact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? style.primaryColor : Colors.orange[800],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            if (hasDiscount)
              Positioned(
                top: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(topRight: Radius.circular(compact ? 8 : 12)),
                  child: _buildDiscountTriangle(compact: compact)
                )
              )
          ]
        ),
      ),
    );
  }

  Widget _buildImageAndTitle(Product displayProduct, String title, String subtitle, String? imageUrl, List<Map<String, Object>> products) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _showProductDetail(context, title, subtitle, imageUrl, products, _selectedMarketName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 120, // Proper height restored and slightly increased
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: imageUrl != null 
                        ? CachedNetworkImage(
                            imageUrl: imageUrl, 
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 200), // Fast fade to avoid jump
                            memCacheHeight: 240, // Optimize memory
                            placeholder: (_, __) => Container(
                              height: 120,
                              alignment: Alignment.center,
                              child: const LoadingDots(),
                            ),
                            errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                          )
                        : const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                    ),
                  ),
                  if ((displayProduct.promoDescription != null && displayProduct.promoDescription!.isNotEmpty) || 
                      (displayProduct.oldPrice != null && displayProduct.oldPrice! > displayProduct.price))
                    Positioned(
                      top: 6, // Slightly lower for better margin
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange[800], // Slightly more vibrant orange
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Text(
                          '%',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  if (displayProduct.promoDescription != null && displayProduct.promoDescription!.isNotEmpty)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: _buildPromoBadge(displayProduct.promoDescription!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87
                ), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              Consumer<ProductProvider>(
                builder: (context, prodProvider, child) {
                  if (!prodProvider.hasAnyReport(widget.result.ean)) return const SizedBox.shrink();
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                    onPressed: () {
                       final rps = prodProvider.productReports[widget.result.ean] ?? [];
                       showModalBottomSheet(
                         context: context,
                         isScrollControlled: true,
                         backgroundColor: Colors.transparent,
                         builder: (ctx) => ProductReportHistoryModal(
                           productName: widget.result.name,
                           reports: rps,
                         ),
                       );
                    },
                  );
                }
              ),
            ],
          ),
          if (subtitle.isNotEmpty)
             Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSavingsBadge(List<Map<String, Object>> sortedProducts, Map<String, Object> bestOption) {
     if (sortedProducts.length < 2) return const SizedBox.shrink();
     
     final bestPrice = (bestOption['prod'] as Product).price;
     final secondBestPrice = (sortedProducts[1]['prod'] as Product).price;
     final savings = secondBestPrice - bestPrice;
     
     if (savings <= 0) return const SizedBox.shrink();
     
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), 
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC8E6C9))
        ),
        child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
              const Icon(Icons.trending_down, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Text(
                 'Ahorrá \$${savings.toStringAsFixed(0)}',
                 style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
              ),
           ],
        ),
     );
  }

  Widget _buildDiscountTriangle({bool compact = false}) {
     final double size = compact ? 22.0 : 28.0;
     final double fontSize = compact ? 12.0 : 15.0;
     return ClipPath(
       clipper: _DiagonalClipper(),
       child: Container(
         width: size,
         height: size,
         color: const Color(0xFFFF5722), // Deep Orange
         alignment: Alignment.topRight,
         padding: EdgeInsets.only(top: compact ? 1 : 2, right: compact ? 1 : 2),
         child: Text(
           '%',
           style: TextStyle(
             color: Colors.white, 
             fontWeight: FontWeight.bold, // Clean 2D look
             fontSize: fontSize,
             height: 1.0,
           ),
         ),
       ),
     );
  }

  Widget _buildPromoBadge(String promo) {
     final isCoronado = promo == "Precio Coronado";
     return Container(
        padding: EdgeInsets.symmetric(horizontal: isCoronado ? 6 : 8, vertical: isCoronado ? 4 : 4),
        decoration: BoxDecoration(
           color: const Color(0xFFFF5722), // Deep Orange
           borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
           ),
           boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(2, 2))
           ]
        ),
        child: isCoronado 
          ? _buildCrownIcon()
          : Text(
              _shortenPromoLabel(promo),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
     );
  }

  String _shortenPromoLabel(String label) {
    if (label.isEmpty) return label;
    
    String result = "";
    
    // 0. Priority: "Compra X" or "Lleva X" patterns
    final buyMatch = RegExp(r'(Compra\s*\d+|Lleva\s*\d+)', caseSensitive: false).firstMatch(label);
    if (buyMatch != null) {
      result = buyMatch.group(1)!;
    }

    // 1. Extract Percentage (anywhere) - only if we didn't find "Compra X"
    if (result.isEmpty) {
      final percentageMatch = RegExp(r'(\d+%)').firstMatch(label);
      if (percentageMatch != null) {
        result = percentageMatch.group(1)!;
      }
    }
    
    // 2. Extract Max Units
    final maxMatch = RegExp(r'max\s*(\d+)', caseSensitive: false).firstMatch(label);
    if (maxMatch != null) {
      final String maxStr = "(max ${maxMatch.group(1)}.)";
      result = result.isEmpty ? maxStr : "$result $maxStr";
    }

    if (result.isNotEmpty) return result;

    // Fallback logic
    String shortened = label;
    if (shortened.toLowerCase().contains('% de descuento')) {
      shortened = shortened.replaceAll(RegExp(r' de descuento', caseSensitive: false), '');
    }
    if (shortened.toLowerCase().contains('unidades')) {
      shortened = shortened.replaceAll(RegExp(r'unidades', caseSensitive: false), 'U.');
    }
    if (shortened.contains(',')) {
      shortened = shortened.split(',')[0].trim();
    }
    return shortened;
  }

  Widget _buildCrownIcon() {
    return SizedBox(
      width: 16,
      height: 12,
      child: SvgPicture.string(
        '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M5 19H19V17H5V19ZM19 15L17 7L14 11L12 5L10 11L7 7L5 15H19Z" fill="white"/></svg>',
      ),
    );
  }

  // Helper methods removed or unused now, keeping them away from build

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
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0); // Top right
    path.lineTo(size.width, size.height); // Bottom right
    path.lineTo(0, 0); // Top left (Diagonal cut)
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

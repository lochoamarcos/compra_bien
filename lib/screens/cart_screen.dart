import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../utils/market_branding.dart';
import '../utils/string_extensions.dart';
import 'saved_lists_screen.dart';
import 'favorites_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Removed _checkedItems Set to use CartProvider's internal isSelected state
  String _selectedFilter = 'Todos';
  final Set<String> _pendingDeletionIds = {}; // Tracks item EANs pending deletion confirmation

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<String> filterOptions = ['Todos', 'Monarca', 'Carrefour', 'Vea', 'La Coope'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A8B5),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text('Mi Carrito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          // "Guardar Lista" Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              onPressed: cart.items.isEmpty ? null : () => _showSaveListDialog(context, cart),
              icon: const Icon(Icons.bookmark_border, size: 18, color: Colors.white),
              label: const Text('Guardar Lista', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                disabledBackgroundColor: Colors.white.withOpacity(0.05),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // "Favoritos" Quick Access
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
            tooltip: 'Ver mis favoritos',
          ),
          // "Listas" View Button
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedListsScreen())),
            tooltip: 'Ver mis listas guardadas',
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _showDeleteConfirmation(context, cart),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: cart.items.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Filter Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text('Filtrar por: ', style: TextStyle(
                                fontSize: 13, 
                                color: isDark ? Colors.white54 : Colors.grey[600],
                                fontWeight: FontWeight.w500
                              )),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  icon: const Icon(Icons.expand_more, size: 20, color: Colors.grey),
                                  style: const TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: Color(0xFF00A8B5)
                                  ),
                                  items: filterOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value == 'Todos' ? 'Todos los Supermercados' : value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      setState(() => _selectedFilter = newValue);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Cart Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_selectedFilter == 'Todos')
                        ...['Monarca', 'Carrefour', 'Vea', 'La Coope'].map((s) {
                          final List<CartItem> items = cart.itemsByStore[s] ?? [];
                          if (items.isEmpty) return const SizedBox.shrink();
                          return _buildMarketSection(context, cart, s, items, currency, isDark);
                        }).toList()
                      else
                        _buildMarketSection(
                          context, 
                          cart, 
                          _selectedFilter, 
                          cart.itemsByStore[_selectedFilter] ?? [], 
                          currency, 
                          isDark
                        ),

                      const SizedBox(height: 100), // Bottom padding for FAB
                    ],
                  ),
                ),
              ],
            ),
      bottomSheet: cart.items.isEmpty ? null : _buildFooter(context, cart, currency, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          const Text('Tu carrito está vacío', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ir a comprar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSection(BuildContext context, CartProvider cart, String marketName, List<CartItem> items, NumberFormat currency, bool isDark) {
    if (items.isEmpty) return const SizedBox.shrink();

    final style = MarketStyle.get(marketName);
    double sectionTotal = items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: style.primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${marketName.toUpperCase()} (${items.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Text(currency.format(sectionTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          
          // Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (ctx, i) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
            itemBuilder: (ctx, i) {
              final item = items[i];
              return _buildCartItemTile(context, cart, item, currency, isDark, style);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(BuildContext context, CartProvider cart, CartItem item, NumberFormat currency, bool isDark, MarketStyle style) {
    // Check if there's a saving in another market
    double? savingValue;
    String? savingMarket;
    if (item.bestPrice != null && item.bestPrice! < item.product.price) {
      savingValue = (item.product.price - item.bestPrice!) * item.quantity;
      savingMarket = item.bestMarket;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: item.isSelected,
                  onChanged: (val) => cart.toggleSelection(item),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  activeColor: const Color(0xFF00A8B5),
                ),
              ),
              const SizedBox(width: 12),
              
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.product.name.toTitleCase(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: item.isSelected ? Colors.grey : (isDark ? Colors.white70 : Colors.black87),
                                    decoration: item.isSelected ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              if (item.product.promoDescription != null && item.product.promoDescription!.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showPromoDetails(context, item, currency),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5722), // Deep Orange
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '%',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.0),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Favorite Toggle
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            cart.isFavorite(item.product.ean) ? Icons.favorite : Icons.favorite_border, 
                            size: 20, 
                            color: cart.isFavorite(item.product.ean) 
                                ? Colors.redAccent 
                                : (isDark ? Colors.white24 : Colors.grey[300])
                          ),
                          onPressed: () => cart.toggleFavorite(item.product),
                        ),
                      ],
                    ),
                    if (savingValue != null && !item.isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Ahorrás ${currency.format(savingValue)} en $savingMarket',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showSwapMarketDialog(context, cart, item, currency, isDark),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                                ),
                                child: Icon(Icons.swap_horiz, size: 16, color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Quantity and Price
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Selector / Deletion UX
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (_pendingDeletionIds.contains(item.product.ean)) ...[
                        _buildQtyBtn(
                          icon: Icons.delete_outline,
                          iconColor: Colors.red,
                          isDark: isDark,
                          onPressed: () {
                             setState(() => _pendingDeletionIds.remove(item.product.ean));
                             cart.removeSingleItem(item);
                          },
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _pendingDeletionIds.remove(item.product.ean)),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('x', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        _buildQtyBtn(
                          icon: Icons.remove, 
                          isDark: isDark, 
                          onPressed: () {
                             if (item.quantity == 1) {
                                setState(() => _pendingDeletionIds.add(item.product.ean));
                             } else {
                                cart.removeSingleItem(item);
                             }
                          }
                        ),
                        const SizedBox(width: 12),
                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 12),
                        _buildQtyBtn(
                          icon: Icons.add, 
                          isDark: isDark, 
                          onPressed: () => cart.addItem(item.product, bestMarket: item.bestMarket, bestPrice: item.bestPrice)
                        ),
                      ]
                    ],
                  ),
                ),
                
                // Price Area (Current and Old)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.product.oldPrice != null && item.product.oldPrice! > item.product.price)
                      Text(
                        currency.format(item.product.oldPrice! * item.quantity),
                        style: TextStyle(
                           fontSize: 12, 
                           decoration: TextDecoration.lineThrough, 
                           color: isDark ? Colors.white38 : Colors.grey[400]
                        ),
                      ),
                    Text(
                      currency.format(item.totalPrice),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn({required IconData icon, required bool isDark, required VoidCallback onPressed, Color? iconColor}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF4B5563) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? const Color(0xFF00A8B5)),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, CartProvider cart, NumberFormat currency, bool isDark) {
    double displayTotal = cart.totalAmount;
    if (_selectedFilter != 'Todos') {
       final list = cart.itemsByStore[_selectedFilter] ?? [];
       displayTotal = list.fold(0.0, (sum, item) => sum + item.totalPrice);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      padding: EdgeInsets.only(
        top: 16, 
        left: 16, 
        right: 16, 
        bottom: MediaQuery.of(context).padding.bottom + 16
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total Estimado ${_selectedFilter != 'Todos' ? '(\u200e$_selectedFilter)' : ''}', style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w500, 
            color: isDark ? Colors.white54 : Colors.grey[600]
          )),
          const SizedBox(height: 4),
          Text(
            currency.format(displayTotal),
            style: const TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.w900, 
              color: Color(0xFF00A8B5),
              height: 1
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CartProvider cart) {
    final hasSelection = cart.items.any((CartItem i) => i.isSelected);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(hasSelection 
           ? '¿Seguro que queres borrar los productos seleccionados?' 
           : '¿Seguro que queres borrar todo el carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              cart.clearSelectedOrAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPromoDetails(BuildContext context, CartItem item, NumberFormat currency) {
      double basePrice = item.product.price;
      String desc = item.product.promoDescription ?? '';
      
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Detalle de Oferta'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(desc, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Precio unitario (Base/Oferta): ${currency.format(basePrice)}'),
                      if (item.product.oldPrice != null && item.product.oldPrice! > basePrice)
                          Text('Precio Normal (Sin Desc.): ${currency.format(item.product.oldPrice)}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (desc.contains('2da')) ...[
                          Text('Precio Comprando 2: ${currency.format(basePrice * (desc.contains('50') ? 1.5 : (desc.contains('70') ? 1.3 : 2)))}'),
                          Text('Promedio por unidad: ${currency.format(basePrice * (desc.contains('50') ? 0.75 : (desc.contains('70') ? 0.65 : 1)))}'),
                      ] else if (desc.contains('3x2')) ...[
                          Text('Precio Comprando 3: ${currency.format(basePrice * 2)}'),
                          Text('Promedio por unidad: ${currency.format(basePrice * 2 / 3)}'),
                      ] else if (desc.contains('4x3')) ...[
                          Text('Precio Comprando 4: ${currency.format(basePrice * 3)}'),
                          Text('Promedio por unidad: ${currency.format(basePrice * 3 / 4)}'),
                      ],
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
              ],
          ),
      );
  }
  // favorites section removed
  void _showSaveListDialog(BuildContext context, CartProvider cart) {
    final TextEditingController nameController = TextEditingController(
      text: 'Lista ${cart.savedLists.length + 1}'
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar Lista'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la lista',
            hintText: 'Ej: Compras del mes',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                cart.saveCurrentCartAsList(nameController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lista "${nameController.text}" guardada'),
                    action: SnackBarAction(
                      label: 'Ver', 
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedListsScreen()))
                    ),
                    showCloseIcon: true,
                    duration: const Duration(seconds: 4),
                  )
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showSwapMarketDialog(BuildContext context, CartProvider cart, CartItem item, NumberFormat currency, bool isDark) {
    if (item.alternatives == null || item.alternatives!.isEmpty) return;
    
    // Convert List<Product> cached alternatives to the format expected by the UI.
    // The options format for the UI used to be List<Map<String, Object>> containing 'prod' and 'market'.
    List<Map<String, Object>> options = item.alternatives!.map((p) => {
        'prod': p,
        'market': p.source,
    }).toList();
    
    // Sort by price ascending
    options.sort((a, b) => (a['prod'] as Product).price.compareTo((b['prod'] as Product).price));

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cambiar de supermercado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(item.product.name.toTitleCase(), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final prod = opt['prod'] as Product;
                final mName = opt['market'] as String;
                final isCurrent = mName == item.product.source;
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                        color: MarketStyle.get(mName).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                     ),
                     child: Text(mName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  title: Text(currency.format(prod.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: isCurrent 
                     ? const Icon(Icons.check_circle, color: Colors.green)
                     : TextButton(
                         onPressed: () {
                           // Swap logic
                           final int q = item.quantity;
                           cart.removeSingleItem(item); // Removes the current
                           // Add the new one Q times (or simply create it if we had a direct set method)
                           // But since cart.addItem is designed for 1 at a time or we can do a loop
                           for(int i = 0; i < q; i++) {
                             cart.addItem(prod, bestMarket: options.first['market'] as String, bestPrice: (options.first['prod'] as Product).price);
                           }
                           Navigator.pop(ctx);
                         },
                         child: const Text('Elegir', style: TextStyle(fontWeight: FontWeight.bold)),
                       ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

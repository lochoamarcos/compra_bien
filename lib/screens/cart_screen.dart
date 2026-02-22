import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../utils/market_branding.dart';
import '../utils/string_extensions.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Removed _checkedItems Set to use CartProvider's internal isSelected state
  String _selectedFilter = 'Todos';

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
        title: const Text('Mi Carrito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // "Guardar Lista" Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función "Guardar Lista" en desarrollo'))
                );
              },
              icon: const Icon(Icons.bookmark_border, size: 18, color: Colors.white),
              label: const Text('Guardar Lista', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                          final items = cart.itemsByStore[s] ?? [];
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
                      const SizedBox(height: 100), // Space for footer
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cart.items.isNotEmpty ? _buildFooter(context, cart, currency, isDark) : null,
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
                Text(marketName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
                        // Favorite Toggle
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.favorite_border, 
                            size: 20, 
                            color: isDark ? Colors.white24 : Colors.grey[300]
                          ),
                          onPressed: () {
                            // Stub for favorites
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Función "Favoritos" próximamente'))
                            );
                          },
                        ),
                      ],
                    ),
                    if (savingValue != null && !item.isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ahorrás ${currency.format(savingValue)} en $savingMarket',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
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
                // Quantity Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildQtyBtn(
                        icon: Icons.remove, 
                        isDark: isDark, 
                        onPressed: () => cart.removeSingleItem(item)
                      ),
                      const SizedBox(width: 12),
                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 12),
                      _buildQtyBtn(
                        icon: Icons.add, 
                        isDark: isDark, 
                        onPressed: () => cart.addItem(item.product, bestMarket: item.bestMarket, bestPrice: item.bestPrice)
                      ),
                    ],
                  ),
                ),
                
                // Price
                Text(
                  currency.format(item.totalPrice),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn({required IconData icon, required bool isDark, required VoidCallback onPressed}) {
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
        child: Icon(icon, size: 18, color: const Color(0xFF00A8B5)),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, CartProvider cart, NumberFormat currency, bool isDark) {
    return Container(
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
          Text('Total Estimado', style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w500, 
            color: isDark ? Colors.white54 : Colors.grey[600]
          )),
          const SizedBox(height: 4),
          Text(
            currency.format(cart.totalAmount),
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
    final hasSelection = cart.items.any((i) => i.isSelected);
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
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../utils/market_branding.dart';

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
    // Access provider
    final cart = Provider.of<CartProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    
    // Store Options
    final List<String> filterOptions = ['Todos', 'Monarca', 'Carrefour', 'Vea', 'La Coope'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Carrito'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
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
              },
            )
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, color: Colors.grey)),
                   const SizedBox(height: 8),
                   ElevatedButton(
                     onPressed: () => Navigator.pop(context),
                     child: const Text('Ir a comprar'),
                   ),
                ],
              ),
            )
          : Column(
              children: [
                // Filter Dropdown (White Background)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      const Text('Supermercado: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            items: filterOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedFilter = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _selectedFilter == 'Todos' 
                    ? _buildAllSections(context, cart, currency)
                    : _buildStoreSection(context, cart, _selectedFilter, currency, isExclusiveView: true),
                ),

                // Grand Total Footer (Only for 'Todos', store specific totals are inside their view if needed, or we keep a global total here?)
                // User requirement was "verlos uno por uno".
                // Let's keep a Global Total bar at bottom if 'Todos' is selected? 
                // Or just the usual footer. The previous design had the "Analysis" toggle.
                // Let's bring back a simplified Total Bar.
                if (_selectedFilter == 'Todos')
                  Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          const Text('Total Estimado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(currency.format(cart.totalAmount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                       ],
                     ),
                  )
              ],
            ),
    );
  }

  Widget _buildAllSections(BuildContext context, CartProvider cart, NumberFormat currency) {
     final stores = ['Monarca', 'Carrefour', 'Vea', 'La Coope'];
     final hasItems = stores.any((s) => (cart.itemsByStore[s]?.isNotEmpty ?? false));
     
     if (!hasItems) return const Center(child: Text("Sin items asignados."));

     return ListView(
       padding: const EdgeInsets.only(bottom: 20),
       children: [
         for (var store in stores)
           if (cart.itemsByStore[store]?.isNotEmpty ?? false)
             _buildStoreSection(context, cart, store, currency)
       ],
     );
  }

  Widget _buildStoreSection(BuildContext context, CartProvider cart, String storeName, NumberFormat currency, {bool isExclusiveView = false}) {
    String storeKey = storeName;
    if (storeName == 'La Coope') storeKey = 'La Coope';

    // 1. Determine which items to show
    List<CartItem> storeItems = cart.itemsByStore[storeKey] ?? [];
    List<CartItem> otherItems = [];

    if (isExclusiveView) {
       for (var item in cart.items) {
          if (!storeItems.contains(item) && item.bestMarket == storeName) {
             otherItems.add(item);
          }
       }
    }

    final marketStyle = MarketStyle.get(storeName);

    // Calculate Total for this view
    double viewTotal = 0;
    for (var item in storeItems) {
       viewTotal += item.product.price * item.quantity;
    }
    for (var item in otherItems) {
       // For others, the price here is the bestPrice (since bestMarket == storeName)
       if (item.bestPrice != null) viewTotal += item.bestPrice! * item.quantity;
    }

    if (storeItems.isEmpty && otherItems.isEmpty && isExclusiveView) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_shopping_cart, size: 50, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 10),
            Text('No hay productos disponibles en $storeName', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    Widget buildHeader(String title, {bool isSecondary = false}) {
        return Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
           decoration: BoxDecoration(
             color: isExclusiveView ? Colors.transparent : Colors.grey.shade200,
             border: isExclusiveView ? null : Border(left: BorderSide(color: marketStyle.primaryColor, width: 6))
           ),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 title, 
                 style: TextStyle(
                   fontSize: 16, 
                   fontWeight: FontWeight.bold, 
                   color: isSecondary ? Colors.grey[700] : marketStyle.primaryColor
                 )
               ),
               if (!isSecondary && !isExclusiveView) // Only show sub-total here if in 'Todos' view
               Text(
                 currency.format(cart.getTotalForStore(storeKey)),
                 style: TextStyle(
                   fontSize: 16, 
                   fontWeight: FontWeight.bold, 
                   color: Colors.black87
                 )
               )
             ],
           ),
        );
    }

    Widget buildItemRow(CartItem item) {
        final key = '${item.product.ean}_${storeName}';
        
        double priceHere = 0;
        if (item.product.source == storeName) {
            priceHere = item.product.price;
        } else if (item.bestMarket == storeName) {
            priceHere = item.bestPrice ?? 0;
        }
        
        double loss = 0;
        String bestStore = '';
        if (item.bestPrice != null && item.bestPrice! < item.product.price) {
           loss = (item.product.price - item.bestPrice!) * item.quantity;
           bestStore = item.bestMarket ?? 'Otro';
        }

        // Offer Warning Logic
        String? offerWarning;
        if (item.product.promoDescription != null) {
           final desc = item.product.promoDescription!.toLowerCase();
           if (desc.contains('2da') || desc.contains('3x2') || desc.contains('4x3') || desc.contains('lleva') || desc.contains('max') || desc.contains('segunda')) {
               offerWarning = "Oferta: ${item.product.promoDescription}";
           }
        }

        return Column(
          children: [
            InkWell(
              onTap: () => cart.toggleSelection(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: 24, height: 24,
                      child: Checkbox(
                        value: item.isSelected,
                        activeColor: marketStyle.primaryColor,
                        checkColor: Colors.white,
                        onChanged: (val) => cart.toggleSelection(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              '${item.product.name}${item.product.brand != null ? " - ${item.product.brand}" : ""}',
                              style: TextStyle(
                                decoration: item.isSelected ? TextDecoration.lineThrough : null,
                                color: item.isSelected 
                                   ? Colors.grey 
                                   : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.w500,
                                fontSize: 14
                              )
                            ),
                            if (loss > 0)
                                Text(
                                  '-\$${currency.format(loss)} en $bestStore',
                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)
                                )
                            else if (item.product.presentation.isNotEmpty)
                                Text(
                                  item.product.presentation, 
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)
                                ),
                        ]
                      ),
                    ),
                    // Quantity & Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                         Text(
                             currency.format(item.totalPrice),
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               color: item.isSelected ? Colors.grey : Colors.black87,
                               fontSize: 13
                             ),
                         ),
                         // Original Price (Strikethrough)
                         if (item.product.oldPrice != null && item.product.oldPrice! > item.product.price)
                           Text(
                             currency.format(item.product.oldPrice! * item.quantity),
                             style: const TextStyle(
                               color: Colors.grey,
                               fontSize: 10,
                               decoration: TextDecoration.lineThrough,
                             ),
                           ),
                         // Quantity Controls
                         Stack(
                           alignment: Alignment.center,
                           children: [
                             Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 InkWell(
                                   onTap: () {
                                      if (item.quantity > 1) {
                                         cart.removeSingleItem(item);
                                      } else {
                                         showDialog(
                                           context: context, 
                                           builder: (ctx) => AlertDialog(
                                              title: const Text('Confirmar'),
                                              content: Text('¿Borrar ${item.product.name} del carrito?'),
                                              actions: [
                                                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                                 TextButton(
                                                    onPressed: () {
                                                       cart.removeItemCompletely(item);
                                                       Navigator.pop(ctx);
                                                    }, 
                                                    child: const Text('Borrar', style: TextStyle(color: Colors.red))
                                                 ),
                                              ],
                                           )
                                         );
                                      }
                                   },
                                   borderRadius: BorderRadius.circular(20),
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Increased vertical padding
                                     child: Icon(Icons.remove_circle_outline, size: 24, color: marketStyle.primaryColor),
                                   ),
                                 ),
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                   child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                 ),
                                 InkWell(
                                   onTap: () => cart.addItem(item.product, bestMarket: item.bestMarket, bestPrice: item.bestPrice),
                                   borderRadius: BorderRadius.circular(20),
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Increased vertical padding
                                     child: Icon(Icons.add_circle_outline, size: 24, color: marketStyle.primaryColor),
                                   ),
                                 ),
                               ],
                             ),
                             // Tall Tap Areas
                             Positioned(
                               top: -10, left: 0, bottom: 10, width: 45,
                               child: GestureDetector(
                                 behavior: HitTestBehavior.translucent,
                                 onTap: () {
                                    if (item.quantity > 1) {
                                       cart.removeSingleItem(item);
                                    } else {
                                       // Trigger the same dialog logic if possible or just use the button below
                                       // For simplicity, let's just use the button's onTap which is safe.
                                    }
                                 },
                               ),
                             ),
                           ],
                         )
                      ],
                    )
                  ],
                ),
              ),
            ),
            // Offer Warning
            if (offerWarning != null)
               InkWell(
                 onTap: () => _showPromoDetails(context, item, currency),
                 child: Container(
                   width: double.infinity,
                   padding: const EdgeInsets.only(left: 40, right: 16, bottom: 8),
                   child: Text(offerWarning, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                 ),
               ),
            const Divider(height: 1),
          ],
        );
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isExclusiveView || storeItems.isNotEmpty)
           buildHeader(storeName),
        
        ...storeItems.map((item) => buildItemRow(item)).toList(),
        
        if (otherItems.isNotEmpty) ...[
           const SizedBox(height: 16),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             color: Colors.orange.withOpacity(0.1),
             child: Text(
               'Otros (Mejor precio aquí)', 
               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800], fontSize: 13)
             )
           ),
           ...otherItems.map((item) => buildItemRow(item)).toList(),
        ],
        if (isExclusiveView) 
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text('Total en $storeName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 Text(currency.format(viewTotal), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marketStyle.primaryColor)),
              ],
            ),
          ),

        if (!isExclusiveView) const SizedBox(height: 10),
      ],
    );

    if (isExclusiveView) {
      return ListView(
        children: [content],
      );
    }
    
    return content;
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
                      Text('Precio unitario: ${currency.format(basePrice)}'),
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

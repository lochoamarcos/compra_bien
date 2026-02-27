import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../models/saved_list.dart';
import '../utils/string_extensions.dart';

class SavedListsScreen extends StatelessWidget {
  const SavedListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A8B5),
        title: const Text('Mis Listas Guardadas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: cart.savedLists.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.savedLists.length,
              itemBuilder: (context, index) {
                final list = cart.savedLists[index];
                return _buildListCard(context, cart, list, dateFmt, isDark);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No tenés listas guardadas', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildListCard(BuildContext context, CartProvider cart, SavedList list, DateFormat dateFmt, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(list.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('${list.items.length} productos • ${dateFmt.format(list.createdAt)}', 
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showRenameDialog(context, cart, list),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _showDeleteDialog(context, cart, list),
            ),
          ],
        ),
        onTap: () => _showListDetails(context, cart, list),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, CartProvider cart, SavedList list) {
    final controller = TextEditingController(text: list.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                cart.renameSavedList(list.id, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CartProvider cart, SavedList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar Lista'),
        content: Text('¿Seguro que querés borrar la lista "${list.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              cart.deleteSavedList(list.id);
              Navigator.pop(ctx);
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showListDetails(BuildContext context, CartProvider cart, SavedList list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${list.items.length} productos', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      cart.loadListToCart(list);
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Go back to cart screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lista cargada al carrito'))
                      );
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Cargar al Carrito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8B5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: list.items.length,
                itemBuilder: (context, index) {
                  final item = list.items[index];
                  return ListTile(
                    leading: SizedBox(
                       width: 40,
                       height: 40,
                       child: item.product.imageUrl != null 
                        ? CachedNetworkImage(
                            imageUrl: item.product.imageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (context, url, error) => const Icon(Icons.shopping_bag_outlined),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    ),
                    title: Text(item.product.name.toTitleCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text('${item.quantity} un. @ ${item.product.source}'),
                    trailing: Text('\$${(item.product.price * item.quantity).toStringAsFixed(0)}', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

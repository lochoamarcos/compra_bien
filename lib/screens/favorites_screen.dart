import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../utils/string_extensions.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A8B5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mis Favoritos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: cart.favoriteProducts.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.favoriteProducts.length,
              itemBuilder: (context, index) {
                final product = cart.favoriteProducts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  shadowColor: Colors.black.withOpacity(0.05),
                  elevation: 2,
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: product.imageUrl != null 
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (context, url, error) => Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                            )
                          : Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                      ),
                      title: Text(
                        product.name.toTitleCase(), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        product.source, 
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                        onPressed: () => cart.toggleFavorite(product),
                        tooltip: 'Eliminar de favoritos',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay favoritos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tus productos marcados con el\ncorazón aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

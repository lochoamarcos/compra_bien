import 'package:flutter/material.dart';
import '../models/bank_promotion.dart';
import '../data/monarca_repository.dart';
// Import other repositories if/when they support bank promos

class BankPromotionsDialog extends StatefulWidget {
  const BankPromotionsDialog({super.key});

  @override
  State<BankPromotionsDialog> createState() => _BankPromotionsDialogState();
}

class _BankPromotionsDialogState extends State<BankPromotionsDialog> {
  final MonarcaRepository _monarcaRepo = MonarcaRepository();
  // Add other repos
  
  List<BankPromotion> _monarcaPromos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    try {
      final monarcaPromos = await _monarcaRepo.getBankPromotions();
      if (mounted) {
        setState(() {
          _monarcaPromos = monarcaPromos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bank promos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       backgroundColor: Colors.grey[900],
       child: Container(
         width: double.maxFinite,
         constraints: const BoxConstraints(maxHeight: 600),
         padding: const EdgeInsets.all(16),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text(
                   "Promociones Bancarias",
                   style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                 ),
                 IconButton(
                   icon: const Icon(Icons.close, color: Colors.white),
                   onPressed: () => Navigator.of(context).pop(),
                 )
               ],
             ),
             const Divider(color: Colors.white24),
             Expanded(
               child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSupermarketSection("Monarca", "assets/images/monarca_logo.png", _monarcaPromos),
                          const SizedBox(height: 20),
                          _buildSupermarketSection("Carrefour", "assets/images/carrefour_logo.png", []), // Placeholder
                          const SizedBox(height: 20),
                          _buildSupermarketSection("Vea", "assets/images/vea_logo.png", []), // Placeholder
                           const SizedBox(height: 20),
                          _buildSupermarketSection("La Coope", "assets/images/coope_logo.png", []), // Placeholder
                        ],
                      ),
                  ),
             ),
           ],
         ),
       ),
    );
  }

  Widget _buildSupermarketSection(String name, String logoPath, List<BankPromotion> promos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             // Text(name, style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
             // Fallback text if logo missing, but for now just text
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               decoration: BoxDecoration(
                 color: Colors.white10,
                 borderRadius: BorderRadius.circular(8)
               ),
               child: Text(name, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold))
             ),
           ],
        ),
        const SizedBox(height: 10),
        if (promos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text("No se encontraron promociones activas.", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
          )
        else
          SizedBox(
            height: 160, // Adjust height as needed
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: promos.length,
              itemBuilder: (context, index) {
                final promo = promos[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Expanded(
                         child: promo.imageUrl.isNotEmpty
                           ? ClipRRect(
                               borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                               child: Image.network(
                                 promo.imageUrl, 
                                 width: double.infinity, 
                                 fit: BoxFit.cover,
                                 errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                               ),
                             )
                           : const Center(child: Icon(Icons.image_not_supported, color: Colors.white24)),
                       ),
                       Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Text(
                           promo.title,
                           style: const TextStyle(color: Colors.white, fontSize: 12),
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       )
                    ],
                  ),
                );
              },
            ),
          )
      ],
    );
  }
}

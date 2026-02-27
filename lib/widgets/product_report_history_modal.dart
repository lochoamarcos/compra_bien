import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductReportHistoryModal extends StatelessWidget {
  final String productName;
  final List<Map<String, dynamic>> reports;

  const ProductReportHistoryModal({
    super.key,
    required this.productName,
    required this.reports,
  });

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';
    try {
      DateTime dt = DateTime.parse(timestamp.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial de Reportes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    Text(
                      productName,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          if (reports.isEmpty)
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 40),
               child: Center(child: Text('No hay reportes recientes para este producto.')),
             )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: reports.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final r = reports[index];
                  final isCorrection = r['type'] == 'correction';
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isCorrection ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Icon(
                        isCorrection ? Icons.report_problem : Icons.warning_amber_rounded,
                        color: isCorrection ? Colors.blue : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCorrection ? 'Corrección de Precio' : 'Reporte de Error',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _formatDate(r['timestamp']),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          r['message'] ?? 'Sin mensaje adicional',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (r['image_url'] != null && r['image_url'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: r['image_url'],
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (r['user'] != null)
                          Text(
                            'Enviado por: ${r['user']}',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

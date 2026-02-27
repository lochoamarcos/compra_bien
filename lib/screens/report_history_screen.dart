import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../utils/market_branding.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/market_branding.dart'; // Ensure it's here

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial de Reportes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mis Reportes', icon: Icon(Icons.person_outline)),
              Tab(text: 'Comunidad', icon: Icon(Icons.public)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReportList(fetcher: ReportService.fetchMyReports, isPersonal: true),
            _ReportList(fetcher: ReportService.fetchReports, isPersonal: false),
          ],
        ),
      ),
    );
  }
}

class _ReportList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() fetcher;
  final bool isPersonal;

  const _ReportList({required this.fetcher, required this.isPersonal});

  @override
  State<_ReportList> createState() => _ReportListState();
}

class _ReportListState extends State<_ReportList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  widget.isPersonal 
                    ? 'Aún no has realizado reportes' 
                    : 'No hay reportes recientes en la comunidad',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = widget.fetcher();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _ReportCard(report: reports[index]);
            },
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = report['type'] as String;
    final isCorrection = type == 'correction';
    final timestamp = DateTime.tryParse(report['timestamp'].toString()) ?? DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(timestamp);
    
    final marketName = report['market'] as String?;
    final style = marketName != null ? MarketStyle.get(marketName) : null;
    final imageUrl = report['image_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image or Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl, 
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => const Icon(Icons.error_outline, size: 20),
                      )
                    : Icon(
                        isCorrection ? Icons.shopping_bag_outlined : Icons.feedback_outlined,
                        color: isCorrection ? Colors.orange : Colors.blue,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            report['product_name'] ?? 'Producto',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report['category'] ?? 'General',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                        color: isCorrection ? Colors.orange[700] : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['message'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (style != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: style.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront, size: 10, color: style.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  marketName ?? 'Desconocido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: style.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'por ${report['user']}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['category'] ?? 'Detalle del Reporte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report['image_url'] != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: report['image_url'],
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Mensaje:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(report['message'] ?? 'Sin mensaje'),
              const SizedBox(height: 16),
              const Text('Información adicional:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Usuario: ${report['user']}', style: const TextStyle(fontSize: 12)),
              Text('Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(report['timestamp'].toString()) ?? DateTime.now())}', style: const TextStyle(fontSize: 12)),
              if (report['market'] != null) 
                Text('Mercado: ${report['market']}', style: const TextStyle(fontSize: 12)),
              if (report['ean'] != null)
                Text('EAN: ${report['ean']}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/report_service.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../models/product.dart';
import '../utils/market_branding.dart';

class ReportProblemDialog extends StatefulWidget {
  const ReportProblemDialog({Key? key}) : super(key: key);

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  String _selectedCategory = 'Buscador';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final List<String> _categories = ['Buscador', 'Productos', 'Sugerencia', 'Otro'];
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submitReport() async {
    final name = _nameController.text.trim();
    final text = _textController.text.trim();
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final reportItems = reportProvider.reportList;
    
    if (text.isEmpty && reportItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor describe el problema o adjunta productos.')),
      );
      return;
    }

    String finalMessage = text;
    if (reportItems.isNotEmpty) {
       finalMessage += '\n\n-- PRODUCTOS REPORTADOS --\n';
       for (var item in reportItems) {
           finalMessage += '- ${item.result.name} (EAN: ${item.result.ean})\n';
           finalMessage += '  Mercados con error: ${item.problematicMarkets.join(', ')}\n';
       }
    }

    setState(() {
      _isSending = true;
    });

    final bool sentNow = await ReportService.submitReport(_selectedCategory, finalMessage, userName: name);

    if (sentNow && reportItems.isNotEmpty) {
       reportProvider.clearList();
    }

    if (!mounted) return;

    Navigator.of(context).pop(); 
    
    String feedback;
    Color bgColor;

    if (sentNow) {
      feedback = 'Reporte enviado con éxito.';
      bgColor = Colors.green;
    } else {
      // If it failed, show schedule if outside hours, else connection error
      if (ReportService.isServerOnline) {
        feedback = 'Se guardó localmente (Error de conexión).';
        bgColor = Colors.blueGrey;
      } else {
        feedback = 'Servidor fuera de horario. Guardado para envío automático (11:30 - 18:00).';
        bgColor = Colors.orange;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback),
        backgroundColor: bgColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar problema'),
      content: SizedBox( // Constrain width for better list view
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<ReportProvider>(
                 builder: (context, provider, _) {
                    if (provider.reportList.isEmpty) return const SizedBox.shrink();
                    return Container(
                       margin: const EdgeInsets.only(bottom: 16),
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3))
                       ),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                  Text('Productos Adjuntos (${provider.reportList.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                                  TextButton(
                                     onPressed: provider.clearList,
                                     style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                     child: const Text('Borrar todos', style: TextStyle(fontSize: 11))
                                  )
                               ]
                             ),
                             const SizedBox(height: 8),
                             ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 150),
                                child: ListView.builder(
                                   shrinkWrap: true,
                                   itemCount: provider.reportList.length,
                                   itemBuilder: (ctx, i) {
                                      final item = provider.reportList[i];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                           children: [
                                              Expanded(
                                                 child: Text(
                                                    '• ${item.result.name} [${item.problematicMarkets.join(", ")}]', 
                                                    style: const TextStyle(fontSize: 12),
                                                    maxLines: 1, overflow: TextOverflow.ellipsis
                                                 )
                                              ),
                                              InkWell(
                                                 onTap: () => provider.removeItem(item.result),
                                                 child: const Icon(Icons.close, size: 16, color: Colors.grey)
                                              )
                                           ],
                                        ),
                                      );
                                   }
                                ),
                             )
                          ],
                       ),
                    );
                 }
              ),
              const Text('Tu Nombre (Opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Ej: Juan Pérez',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Categoría:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Descripción del problema:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Ej: No encuentro la leche La Serenísima...',
                  border: const OutlineInputBorder(),
                  helperText: Provider.of<ReportProvider>(context, listen: false).reportList.isNotEmpty 
                      ? 'Se enviarán también los productos adjuntos.' 
                      : null,
                ),
                maxLength: 200,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _submitReport,
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}

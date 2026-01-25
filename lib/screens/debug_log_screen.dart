import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = AppLogger().logs.reversed.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
             icon: const Icon(Icons.copy),
             onPressed: () {
                Clipboard.setData(ClipboardData(text: logs.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied!')));
             },
          ),
          IconButton(
             icon: const Icon(Icons.delete),
             onPressed: () {
                AppLogger().clear();
                setState(() {});
             },
          )
        ],
      ),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
           return Padding(
             padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
             child: Text(logs[index], style: const TextStyle(fontFamily: 'Courier', fontSize: 12)),
           );
        },
      ),
    );
  }
}

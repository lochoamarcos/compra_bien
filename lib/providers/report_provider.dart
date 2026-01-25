
import 'package:flutter/material.dart';
import '../models/product.dart';

class ReportItem {
  final ComparisonResult result;
  final Set<String> problematicMarkets;
  final String? note;
  final DateTime timestamp;

  ReportItem({
    required this.result,
    required this.problematicMarkets,
    this.note,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();
}

class ReportProvider with ChangeNotifier {
  final List<ReportItem> _reportList = [];

  List<ReportItem> get reportList => _reportList;

  void addItem(ComparisonResult result, Set<String> badMarkets, {String? note}) {
    // Check if already exists, if so update
    final index = _reportList.indexWhere((item) => item.result.ean == result.ean && item.result.name == result.name);
    
    if (index >= 0) {
      _reportList[index] = ReportItem(
        result: result,
        problematicMarkets: badMarkets,
        note: note ?? _reportList[index].note,
      );
    } else {
      _reportList.add(ReportItem(
        result: result,
        problematicMarkets: badMarkets,
        note: note,
      ));
    }
    notifyListeners();
  }

  void removeItem(ComparisonResult result) {
    _reportList.removeWhere((item) => item.result.ean == result.ean && item.result.name == result.name);
    notifyListeners();
  }

  void clearList() {
    _reportList.clear();
    notifyListeners();
  }
  
  bool isReported(ComparisonResult result) {
      return _reportList.any((item) => item.result.ean == result.ean && item.result.name == result.name);
  }
}

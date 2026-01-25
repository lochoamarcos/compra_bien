import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // For future upload

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final List<Map<String, dynamic>> _buffer = [];
  static const int _batchSize = 50;
  static const String _storageKey = 'analytics_pending_data';

  // Initialize service (load pending data)
  Future<void> init() async {
    // Determine user ID or Session ID if needed
    debugPrint('AnalyticsService Initialized');
    await _flushQueue(); // Try to send old data on startup
  }

  // Record a touch event
  void logTouch(double x, double y, String screenName) {
    final event = {
      'type': 'touch',
      'x': x.toStringAsFixed(1),
      'y': y.toStringAsFixed(1),
      'screen': screenName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _buffer.add(event);

    if (_buffer.length >= _batchSize) {
      _saveBatch();
    }
  }

  // Save current buffer to local storage
  Future<void> _saveBatch() async {
    if (_buffer.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_storageKey) ?? [];
    
    // Compress/Encode logic here. For simplicity, we just JSON encode the list.
    pending.add(json.encode(batch));
    
    await prefs.setStringList(_storageKey, pending);
    debugPrint('Analytics: Saved batch of ${batch.length} events. Total batches pending: ${pending.length}');
    
    // Trigger upload attempt
    _tryUpload(); 
  }

  // Simulate Upload (or real upload if URL provided)
  Future<void> _tryUpload() async {
    // In a real app, check for Wi-Fi here.
    // Connectivity check...

    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_storageKey) ?? [];
    if (pending.isEmpty) return;

    debugPrint('Analytics: Uploading ${pending.length} batches...');
    
    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Check success (simulated)
    bool success = true; 
    
    if (success) {
      await prefs.remove(_storageKey);
      debugPrint('Analytics: Upload successful. Local storage cleared.');
    }
  }
  
  // Method to manually flush when app closes or pauses
  Future<void> forceFlush() async {
    await _saveBatch();
  }
  
  // Helper to send old data
   Future<void> _flushQueue() async {
      _tryUpload();
   }
}

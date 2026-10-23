import 'package:flutter/foundation.dart';

class ApiLogEntry {
  final DateTime at;
  final String method;
  final String path;
  final int? status;
  final int durationMs;
  final String? error;

  const ApiLogEntry({
    required this.at,
    required this.method,
    required this.path,
    required this.durationMs,
    this.status,
    this.error,
  });

  bool get isOk => status != null && status! >= 200 && status! < 400;
  bool get isClientError => status != null && status! >= 400 && status! < 500;
}

class ApiLog extends ChangeNotifier {
  ApiLog._();

  static final ApiLog instance = ApiLog._();

  static const int _limit = 200;

  final List<ApiLogEntry> _entries = [];

  List<ApiLogEntry> get entries => List.unmodifiable(_entries.reversed);

  void add(ApiLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _limit) _entries.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

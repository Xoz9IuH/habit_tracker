import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ConnectionMonitor extends ChangeNotifier {
  ConnectionMonitor(this._dio);

  final Dio? _dio;
  Timer? _timer;
  bool _online = true;
  bool _checking = false;

  bool get online => _online;
  bool get offline => !_online;
  bool get checking => _checking;

  void attach(Dio dio) {
    _client = dio;
  }

  Dio? _client;

  void markOffline() {
    if (!_online) return;
    _online = false;
    notifyListeners();
    _startProbing();
  }

  void markOnline() {
    if (_online) {
      _stopProbing();
      return;
    }
    _online = true;
    notifyListeners();
    _stopProbing();
  }

  Future<bool> probe() async {
    final client = _client ?? _dio;
    if (client == null || _checking) return _online;
    _checking = true;
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/__health',
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          extra: {'skipOfflineTracking': true},
        ),
      );
      final ok = (response.statusCode ?? 0) == 200;
      if (ok) markOnline();
      return ok;
    } catch (error) {
      debugPrint('Проверка связи: $error');
      markOffline();
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void _startProbing() {
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => probe());
  }

  void _stopProbing() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopProbing();
    super.dispose();
  }
}

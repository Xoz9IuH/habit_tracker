import 'package:flutter/foundation.dart';

class ApiDebug extends ChangeNotifier {
  ApiDebug._();

  static final ApiDebug instance = ApiDebug._();

  int _delayMs = 0;
  int? _failCode;

  int get delayMs => _delayMs;
  int? get failCode => _failCode;
  bool get isNormal => _delayMs == 0 && _failCode == null;

  void normal() {
    _delayMs = 0;
    _failCode = null;
    notifyListeners();
  }

  void slow() {
    _delayMs = 1500;
    _failCode = null;
    notifyListeners();
  }

  void fail() {
    _delayMs = 0;
    _failCode = 500;
    notifyListeners();
  }

  Map<String, dynamic> get queryParameters => {
    if (_delayMs > 0) '__delay': _delayMs,
    if (_failCode != null) '__fail': _failCode,
  };
}

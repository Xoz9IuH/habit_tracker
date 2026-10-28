import 'package:flutter/foundation.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

const localApiBase = 'http://localhost:8080/api';

String get resolvedApiBase {
  if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
  if (kIsWeb) return '${Uri.base.origin}/api';
  return localApiBase;
}

const sessionTimeout = Duration(minutes: 3);
const sessionWarning = Duration(seconds: 30);
const sessionCheckDelay = Duration(seconds: 60);

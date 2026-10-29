import 'dart:convert';

Map<String, dynamic> decodeJwtPayload(String token) {
  final part = token.split('.').first;
  final padded = part.replaceAll('-', '+').replaceAll('_', '/');
  final normalised = padded.padRight(
    padded.length + (4 - padded.length % 4) % 4,
    '=',
  );
  final decoded = jsonDecode(utf8.decode(base64.decode(normalised)));
  return decoded is Map<String, dynamic> ? decoded : const {};
}

String? jwtSubject(String? token) {
  if (token == null || !token.contains('.')) return null;
  try {
    final sub = decodeJwtPayload(token)['sub'];
    return sub is String ? sub : null;
  } catch (_) {
    return null;
  }
}

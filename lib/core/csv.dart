import 'package:flutter/services.dart';

String buildCsv(List<List<String>> rows) {
  final buffer = StringBuffer('\uFEFF');
  for (final row in rows) {
    buffer.writeln(row.map(_escape).join(';'));
  }
  return buffer.toString();
}

String _escape(String value) {
  final needsQuotes =
      value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

Future<String> copyCsvToClipboard(String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return csv;
}

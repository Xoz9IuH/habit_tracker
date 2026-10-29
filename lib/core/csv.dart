import 'package:flutter/services.dart';

/// Экспорт списка в CSV — особенность итоговой работы: данные текущего
/// фильтра можно забрать в таблицу Excel.
String buildCsv(List<List<String>> rows) {
  final buffer = StringBuffer('\uFEFF'); // BOM, чтобы Excel читал кириллицу
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

/// Кладёт CSV в буфер обмена и отдаёт содержимое для сохранения файла.
Future<String> copyCsvToClipboard(String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return csv;
}

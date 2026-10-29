import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/csv.dart';

void main() {
  group('Экспорт CSV', () {
    test('разделитель — точка с запятой, каждая строка с переводом строки', () {
      final csv = buildCsv([
        ['Название', 'Категория'],
        ['Утренняя зарядка', 'Спорт'],
      ]);

      expect(csv.contains('Название;Категория'), isTrue);
      expect(csv.contains('Утренняя зарядка;Спорт'), isTrue);
      expect(csv.split('\n').where((line) => line.isNotEmpty).length, 2);
    });

    test('значения с разделителем и кавычками берутся в кавычки', () {
      final csv = buildCsv([
        ['Привычка "дом"; вечером', 'Цель, «мир»'],
      ]);

      expect(csv.contains('"Привычка ""дом""; вечером"'), isTrue);
      expect(csv.contains('Цель, «мир»'), isTrue);
    });

    test('файл начинается с BOM, чтобы Excel читал кириллицу', () {
      final csv = buildCsv([
        ['Название'],
      ]);

      expect(csv.startsWith('\uFEFF'), isTrue);
    });

    test('пустой список даёт только заголовок', () {
      final csv = buildCsv([
        ['Название', 'Серия'],
      ]);

      expect(csv.replaceAll('\uFEFF', '').trim(), 'Название;Серия');
    });
  });
}

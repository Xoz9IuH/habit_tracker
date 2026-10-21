
library;

String? requiredText(String? value, {String field = 'Поле'}) {
  if (value == null || value.trim().isEmpty) return 'Заполните $field';
  return null;
}

String? maxLength(String? value, int max, {String field = 'Поле'}) {
  if (value == null) return null;
  if (value.trim().length > max) {
    return '$field: максимум $max символов';
  }
  return null;
}

String? minLength(String? value, int min, {String field = 'Поле'}) {
  if (value == null) return null;
  if (value.trim().length < min) {
    return '$field: минимум $min символов';
  }
  return null;
}

String? intRange(
  String? value, {
  int? min,
  int? max,
  bool required = true,
  String field = 'Поле',
}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return required ? 'Заполните $field' : null;
  }
  final parsed = int.tryParse(text);
  if (parsed == null) return '$field: введите целое число';
  if (min != null && parsed < min) return '$field: минимум $min';
  if (max != null && parsed > max) return '$field: максимум $max';
  return null;
}

String? positiveInt(String? value, {String field = 'Поле'}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Заполните $field';
  final parsed = int.tryParse(text);
  if (parsed == null) return '$field: введите целое число';
  if (parsed <= 0) return '$field: должно быть больше нуля';
  return null;
}

String? email(String? value, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return required ? 'Заполните почту' : null;
  }
  final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  if (!pattern.hasMatch(text)) return 'Некорректный формат почты';
  return null;
}

String? notInFuture(DateTime? value, {String field = 'Дата'}) {
  if (value == null) return 'Выберите $field';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = DateTime(value.year, value.month, value.day);
  if (picked.isAfter(today)) return '$field не может быть в будущем';
  return null;
}

String? notBefore(DateTime? value, DateTime min, {String field = 'Дата'}) {
  if (value == null) return 'Выберите $field';
  if (value.isBefore(min)) return '$field не может быть раньше ${min.day}.${min.month}.${min.year}';
  return null;
}

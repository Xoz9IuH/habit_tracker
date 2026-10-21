/// Приводит значение к int: принимает и числа, и строки.
/// Данные из хранилища могут прийти в любом виде — падать нельзя.
int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Приводит значение к строке: любое не-строковое значение считаем пустым.
String _asString(Object? value) {
  if (value is String) return value;
  return '';
}

/// Категория привычек — «один ко многим» с привычками: у категории
/// может быть сколько угодно привычек, у привычки ровно одна категория.
class Category {
  final int id;
  final String name;
  final String description;
  final DateTime? deletedAt;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Category copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        description: _asString(json['description']),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(_asString(json['deletedAt'])),
      );
}

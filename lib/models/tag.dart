int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String _asString(Object? value) {
  if (value is String) return value;
  return '';
}

int? _asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

class Tag {
  final int id;
  final String name;
  final String color;
  final int? categoryId;
  final DateTime? deletedAt;

  const Tag({
    required this.id,
    required this.name,
    this.color = 'синий',
    this.categoryId,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Tag copyWith({
    int? id,
    String? name,
    String? color,
    Object? categoryId = _unset,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'categoryId': categoryId,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: _asInt(json['id']),
    name: _asString(json['name']),
    color: _asString(json['color']).isEmpty
        ? 'синий'
        : _asString(json['color']),
    categoryId: _asIntOrNull(json['categoryId']),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(_asString(json['deletedAt'])),
  );

  static const _unset = Object();
}

const List<String> tagColors = [
  'синий',
  'зелёный',
  'оранжевый',
  'фиолетовый',
  'красный',
  'серый',
];

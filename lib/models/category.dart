// Категория привычек (Здоровье, Спорт, Обучение, ...). Проще привычки:
// справочная сущность, на которую ссылается habit.categoryId.
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
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

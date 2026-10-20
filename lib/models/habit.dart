// Привычка — основная сущность трекера. Неизменяемый объект с copyWith.
// copyWith с флагом clearDeletedAt нужен, чтобы можно было вернуть
// привычку из soft delete (написать null поверх старого значения).
class Habit {
  final int id;
  final String name; // название привычки
  final String goal; // измеримая цель (например, «30 минут в день»)
  final int categoryId;
  final int periodicityId;
  final int minutesPerDay; // сколько минут в день планируется тратить
  final int streak; // текущая серия «дней подряд»
  final DateTime? deletedAt;

  const Habit({
    required this.id,
    required this.name,
    required this.goal,
    required this.categoryId,
    required this.periodicityId,
    required this.minutesPerDay,
    required this.streak,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Habit copyWith({
    String? name,
    String? goal,
    int? categoryId,
    int? periodicityId,
    int? minutesPerDay,
    int? streak,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      categoryId: categoryId ?? this.categoryId,
      periodicityId: periodicityId ?? this.periodicityId,
      minutesPerDay: minutesPerDay ?? this.minutesPerDay,
      streak: streak ?? this.streak,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

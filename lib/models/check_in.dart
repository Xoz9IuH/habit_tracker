/// Приводит значение к int: принимает и числа, и строки.
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

/// Отметка о выполнении привычки за конкретный день.
/// Связи: «многие к одному» с Habit (habitId) и с Profile (profileId).
class CheckIn {
  final int id;
  final int habitId;
  final int profileId;
  final DateTime date;
  final int minutes;
  final bool completed;
  final String note;
  final DateTime? deletedAt;

  const CheckIn({
    required this.id,
    required this.habitId,
    required this.profileId,
    required this.date,
    required this.minutes,
    required this.completed,
    required this.note,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  CheckIn copyWith({
    int? id,
    int? habitId,
    int? profileId,
    DateTime? date,
    int? minutes,
    bool? completed,
    String? note,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CheckIn(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      profileId: profileId ?? this.profileId,
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
      completed: completed ?? this.completed,
      note: note ?? this.note,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'habitId': habitId,
        'profileId': profileId,
        'date': date.toIso8601String(),
        'minutes': minutes,
        'completed': completed,
        'note': note,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
        id: _asInt(json['id']),
        habitId: _asInt(json['habitId']),
        profileId: _asInt(json['profileId']),
        date: DateTime.tryParse(_asString(json['date'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        minutes: _asInt(json['minutes']),
        completed: json['completed'] == true,
        note: _asString(json['note']),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(_asString(json['deletedAt'])),
      );
}

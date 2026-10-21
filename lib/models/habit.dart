
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

class Habit {
  final int id;
  final String name;
  final String goal;
  final int categoryId;
  final int periodicityId;
  final int minutesPerDay;
  final int streak;
  final int profileId;
  final List<int> tagIds;
  final DateTime? deletedAt;

  const Habit({
    required this.id,
    required this.name,
    required this.goal,
    required this.categoryId,
    required this.periodicityId,
    required this.minutesPerDay,
    required this.streak,
    required this.profileId,
    this.tagIds = const [],
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Habit copyWith({
    int? id,
    String? name,
    String? goal,
    int? categoryId,
    int? periodicityId,
    int? minutesPerDay,
    int? streak,
    int? profileId,
    List<int>? tagIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      categoryId: categoryId ?? this.categoryId,
      periodicityId: periodicityId ?? this.periodicityId,
      minutesPerDay: minutesPerDay ?? this.minutesPerDay,
      streak: streak ?? this.streak,
      profileId: profileId ?? this.profileId,
      tagIds: tagIds ?? this.tagIds,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'goal': goal,
        'categoryId': categoryId,
        'periodicityId': periodicityId,
        'minutesPerDay': minutesPerDay,
        'streak': streak,
        'profileId': profileId,
        'tagIds': tagIds,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        goal: _asString(json['goal']),
        categoryId: _asInt(json['categoryId']),
        periodicityId: _asInt(json['periodicityId']),
        minutesPerDay: _asInt(json['minutesPerDay']),
        streak: _asInt(json['streak']),
        profileId: _asInt(json['profileId']),
        tagIds: (json['tagIds'] as List?)
                ?.map((e) => _asInt(e))
                .toList() ??
            const [],
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(_asString(json['deletedAt'])),
      );
}

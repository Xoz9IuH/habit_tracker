
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

class Profile {
  final int id;
  final String name;
  final String email;
  final String city;
  final int dailyGoalMinutes;
  final bool remindersEnabled;
  final int? couponId;
  final DateTime? deletedAt;

  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.city,
    required this.dailyGoalMinutes,
    required this.remindersEnabled,
    this.couponId,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Profile copyWith({
    int? id,
    String? name,
    String? email,
    String? city,
    int? dailyGoalMinutes,
    bool? remindersEnabled,
    Object? couponId = _unset,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      city: city ?? this.city,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      couponId: couponId == _unset ? this.couponId : couponId as int?,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'city': city,
        'dailyGoalMinutes': dailyGoalMinutes,
        'remindersEnabled': remindersEnabled,
        'couponId': couponId,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        email: _asString(json['email']),
        city: _asString(json['city']),
        dailyGoalMinutes: _asInt(json['dailyGoalMinutes']),
        remindersEnabled: json['remindersEnabled'] == true,
        couponId: _asIntOrNull(json['couponId']),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(_asString(json['deletedAt'])),
      );

  static const _unset = Object();
}

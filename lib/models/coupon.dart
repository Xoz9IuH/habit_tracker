
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

class Coupon {
  final int id;
  final int profileId;
  final String code;
  final int discountPercent;
  final DateTime expiresAt;
  final DateTime? deletedAt;

  const Coupon({
    required this.id,
    required this.profileId,
    required this.code,
    required this.discountPercent,
    required this.expiresAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  bool isActiveAt(DateTime moment) =>
      !isDeleted && expiresAt.isAfter(moment);

  Coupon copyWith({
    int? id,
    int? profileId,
    String? code,
    int? discountPercent,
    DateTime? expiresAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Coupon(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      code: code ?? this.code,
      discountPercent: discountPercent ?? this.discountPercent,
      expiresAt: expiresAt ?? this.expiresAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'code': code,
        'discountPercent': discountPercent,
        'expiresAt': expiresAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: _asInt(json['id']),
        profileId: _asInt(json['profileId']),
        code: _asString(json['code']),
        discountPercent: _asInt(json['discountPercent']),
        expiresAt: DateTime.tryParse(_asString(json['expiresAt'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(_asString(json['deletedAt'])),
      );
}

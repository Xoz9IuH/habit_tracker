int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String _asString(Object? value) => value is String ? value : '';

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final int? readerId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.readerId,
  });

  bool get isAdmin => role == 'admin';
  bool get isLibrarian => role == 'librarian';
  bool get isReader => role == 'reader';
  bool get canEdit => role != 'reader';

  String get roleName => switch (role) {
    'admin' => 'администратор',
    'librarian' => 'редактор',
    _ => 'читатель',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role,
    'readerId': readerId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: _asInt(json['id']),
    username: _asString(json['username']),
    fullName: _asString(json['fullName']),
    role: _asString(json['role']).isEmpty ? 'reader' : _asString(json['role']),
    readerId: json['readerId'] == null ? null : _asInt(json['readerId']),
  );
}

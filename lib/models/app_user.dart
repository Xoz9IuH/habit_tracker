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
  final int? profileId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.profileId,
  });

  bool get isAdmin => role == 'admin';
  bool get isLibrarian => role == 'librarian';
  bool get isReader => !isAdmin && !isLibrarian;

  /// В облачной версии идентификатор — UUID из Supabase, в учебной —
  /// число из локального сервера, поэтому храним его строкой.
  String get key => '$id';

  bool get canRead => true;
  bool get canEdit => isAdmin || isLibrarian;
  bool get canPurge => isAdmin;
  bool get canManageUsers => isAdmin;

  String get roleName => switch (role) {
    'admin' => 'администратор',
    'librarian' => 'редактор',
    _ => 'читатель',
  };

  static const displayNames = {
    'admin': 'Администратор',
    'librarian': 'Редактор',
    'reader': 'Читатель',
  };

  AppUser copyWith({String? role}) => AppUser(
    id: id,
    username: username,
    fullName: fullName,
    role: role ?? this.role,
    profileId: profileId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role,
    'profileId': profileId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: _asInt(json['id']),
    username: _asString(json['username']),
    fullName: _asString(json['fullName']),
    role: _asString(json['role']).isEmpty ? 'reader' : _asString(json['role']),
    profileId: json['profileId'] == null ? null : _asInt(json['profileId']),
  );

  static AppUser sample(String role) => AppUser(
    id: 0,
    username: 'demo',
    fullName: displayNames[role] ?? 'Демо',
    role: role,
  );

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.role == role;

  @override
  int get hashCode => Object.hash(id, role);

  @override
  String toString() => 'AppUser($username, $role)';
}

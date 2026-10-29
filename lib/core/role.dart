class Role {
  const Role._(this.code, this.rank, this.title);

  final String code;
  final int rank;
  final String title;

  static const Role reader = Role._('reader', 1, 'читатель');
  static const Role librarian = Role._('librarian', 2, 'редактор');
  static const Role admin = Role._('admin', 3, 'администратор');

  static Role of(String? code) {
    if (code == 'admin') return admin;
    if (code == 'librarian') return librarian;
    return reader;
  }

  static bool atLeast(String? code, Role minimum) =>
      of(code).rank >= minimum.rank;

  static String label(String? code) => of(code).title;
}

class RoleRoute {
  final String prefix;
  final Role minimum;

  const RoleRoute(this.prefix, this.minimum);
}

const roleRoutes = <RoleRoute>[
  RoleRoute('/system', Role.reader),
  RoleRoute('/users', Role.reader),
  RoleRoute('/profiles', Role.reader),
  RoleRoute('/categories', Role.reader),
  RoleRoute('/tags', Role.reader),
  RoleRoute('/habits/new', Role.reader),
  RoleRoute('/coupons', Role.reader),
];

Role? minimumRoleFor(String location) {
  RoleRoute? match;
  for (final rule in roleRoutes) {
    final fits =
        location == rule.prefix || location.startsWith('${rule.prefix}/');
    if (fits) {
      final longer = match == null || rule.prefix.length > match.prefix.length;
      if (longer) {
        match = rule;
      }
    }
  }
  if (match == null) return null;
  return match.minimum;
}

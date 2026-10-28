class ReferenceCache {
  ReferenceCache._();

  static final ReferenceCache instance = ReferenceCache._();

  final Map<int, String> categories = {};
  final Map<int, String> tags = {};
  final Map<int, String> profiles = {};
  final Map<int, String> habits = {};

  void putCategories(Iterable<(int, String)> rows) => _fill(categories, rows);

  void putTags(Iterable<(int, String)> rows) => _fill(tags, rows);

  void putProfiles(Iterable<(int, String)> rows) => _fill(profiles, rows);

  void putHabits(Iterable<(int, String)> rows) => _fill(habits, rows);

  String category(int id) => categories[id] ?? '—';

  String tag(int id) => tags[id] ?? '—';

  String profile(int id) => profiles[id] ?? '—';

  String habit(int id) => habits[id] ?? '—';

  void clear() {
    categories.clear();
    tags.clear();
    profiles.clear();
    habits.clear();
  }

  void _fill(Map<int, String> target, Iterable<(int, String)> rows) {
    for (final row in rows) {
      target[row.$1] = row.$2;
    }
  }
}

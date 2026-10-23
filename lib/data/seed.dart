import '../core/reference_cache.dart';

class Periodicity {
  final int id;
  final String name;
  const Periodicity(this.id, this.name);
}

const List<Periodicity> periodicities = [
  Periodicity(1, 'Ежедневно'),
  Periodicity(2, 'Через день'),
  Periodicity(3, '3 раза в неделю'),
  Periodicity(4, 'Еженедельно'),
  Periodicity(5, 'По будням'),
];

String periodicityName(int id) => periodicities
    .firstWhere((p) => p.id == id, orElse: () => const Periodicity(0, '?'))
    .name;

String categoryName(int id) => ReferenceCache.instance.category(id);

String tagName(int id) => ReferenceCache.instance.tag(id);

String profileName(int id) => ReferenceCache.instance.profile(id);

String habitName(int id) => ReferenceCache.instance.habit(id);

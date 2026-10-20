import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/category_query.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/repositories/in_memory_category_repository.dart';
import 'package:habit_tracker/repositories/in_memory_habit_repository.dart';

void main() {
  group('InMemoryHabitRepository', () {
    test('возвращает первую страницу без фильтров (удалённые скрыты)',
        () async {
      final repo = InMemoryHabitRepository();
      final page = await repo.find(const HabitQuery());

      expect(page.page, 1);
      expect(page.size, 10);
      expect(page.total, 14); // 15 сидов, один удалён
      expect(page.items, hasLength(10));
      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isTrue);
      expect(page.items.every((h) => !h.isDeleted), isTrue);
    });

    test('вторая страница содержит «хвост» списка', () async {
      final repo = InMemoryHabitRepository();
      final page = await repo.find(const HabitQuery(page: 2));

      expect(page.items, hasLength(4));
      expect(page.hasNext, isFalse);
      expect(page.hasPrevious, isTrue);
    });

    test('поиск ищет и по названию, и по цели', () async {
      final repo = InMemoryHabitRepository();
      final byName = await repo.find(const HabitQuery(search: 'медитация'));
      final byGoal = await repo.find(const HabitQuery(search: 'таймер'));

      expect(byName.total, 1);
      expect(byName.items.single.name, 'Медитация 10 минут');
      expect(byGoal.items.single.id, byName.items.single.id);
    });

    test('фильтры по категории, периодичности и серии', () async {
      final repo = InMemoryHabitRepository();
      final sport = await repo.find(const HabitQuery(categoryId: 1));
      final daily = await repo.find(const HabitQuery(periodicityId: 1));
      const q = HabitQuery(categoryId: 1, periodicityId: 3);
      final both = await repo.find(q);
      final series = await repo.find(const HabitQuery(streakFrom: 20, streakTo: 40));

      expect(sport.items.every((h) => h.categoryId == 1), isTrue);
      expect(daily.items.every((h) => h.periodicityId == 1), isTrue);
      expect(
          both.items.every((h) => h.categoryId == 1 && h.periodicityId == 3),
          isTrue);
      expect(
          series.items.every((h) => h.streak >= 20 && h.streak <= 40),
          isTrue);
      // По умолчанию сортировка по названию: «Английский…» (35), «Чтение…» (21).
      expect(series.items.map((h) => h.streak), [35, 21]);
    });

    test('сортировка по серии asc/desc', () async {
      final repo = InMemoryHabitRepository();
      final asc =
          await repo.find(const HabitQuery(sortField: 'streak', size: 50));
      final desc = await repo
          .find(const HabitQuery(sortField: 'streak', sortAscending: false, size: 50));

      expect(asc.items.first.streak, lessThanOrEqualTo(asc.items.last.streak));
      expect(desc.items.first.streak, greaterThanOrEqualTo(desc.items.last.streak));
    });

    test('includeDeleted возвращает и удалённые привычки', () async {
      final repo = InMemoryHabitRepository();
      final withTrash =
          await repo.find(const HabitQuery(includeDeleted: true, size: 50));

      expect(withTrash.total, 15);
      expect(withTrash.items.any((h) => h.isDeleted), isTrue);
    });

    test('deleteMany помечает только активные привычки', () async {
      final repo = InMemoryHabitRepository();
      // id 15 уже удалён в сиде — deleteMany его не трогает.
      final deleted = await repo.deleteMany([1, 2, 15]);
      final page =
          await repo.find(const HabitQuery(includeDeleted: true, size: 50));

      expect(deleted, 2);
      expect(page.total, 15);
      expect(page.items.where((h) => h.id == 1).single.isDeleted, isTrue);
      expect(page.items.where((h) => h.id == 15).single.isDeleted, isTrue);

      await repo.restore(1);
      final restored = await repo.findById(1);
      expect(restored!.isDeleted, isFalse);
    });

    test('hardDelete стирает привычку безвозвратно', () async {
      final repo = InMemoryHabitRepository();
      await repo.hardDelete(1);
      final page =
          await repo.find(const HabitQuery(includeDeleted: true, size: 50));
      final gone = await repo.findById(1);

      expect(gone, isNull);
      expect(page.total, 14);
      final ghost = const Habit(
        id: 999,
        name: 'призрак',
        goal: 'нет в хранилище',
        categoryId: 1,
        periodicityId: 1,
        minutesPerDay: 0,
        streak: 0,
      );
      expect(() => repo.update(ghost), throwsStateError);
    });

    test('create присваивает новый id', () async {
      final repo = InMemoryHabitRepository();
      final created = await repo.create(const Habit(
        id: 0,
        name: 'Проба',
        goal: 'Проверка',
        categoryId: 1,
        periodicityId: 1,
        minutesPerDay: 5,
        streak: 0,
      ));

      expect(created.id, greaterThan(0));
      final page = await repo.find(
          const HabitQuery(search: 'Проба'));
      expect(page.total, 1);
    });
  });

  group('InMemoryCategoryRepository', () {
    test('пагинация категорий', () async {
      final repo = InMemoryCategoryRepository();
      final page = await repo.find(const CategoryQuery(size: 4));

      expect(page.total, 6);
      expect(page.items, hasLength(4));
      expect(page.totalPages, 2);
    });

    test('поиск по названию и описанию', () async {
      final repo = InMemoryCategoryRepository();
      final byName = await repo.find(const CategoryQuery(search: 'спорт'));
      final byDesc = await repo.find(const CategoryQuery(search: 'порядок'));

      expect(byName.items.single.name, 'Спорт');
      expect(byDesc.items.single.name, 'Быт');
    });

    test('сортировка по описанию', () async {
      final repo = InMemoryCategoryRepository();
      final desc = await repo.find(
          const CategoryQuery(sortField: 'description', size: 50));

      expect(
          desc.items.first.description
              .toLowerCase()
              .compareTo(desc.items.last.description.toLowerCase()),
          lessThanOrEqualTo(0));
    });

    test('softDelete / restore / hardDelete категории', () async {
      final repo = InMemoryCategoryRepository();
      await repo.softDelete(6);

      final visible = await repo.find(const CategoryQuery(size: 50));
      final trash = await repo.find(
          const CategoryQuery(size: 50, includeDeleted: true));

      expect(visible.total, 5);
      expect(trash.total, 6);

      await repo.restore(6);
      expect((await repo.findById(6))!.isDeleted, isFalse);

      await repo.hardDelete(6);
      expect(await repo.findById(6), isNull);
    });
  });
}

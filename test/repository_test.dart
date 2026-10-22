import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/category.dart';
import 'package:habit_tracker/models/coupon.dart';
import 'package:habit_tracker/models/coupon_query.dart';
import 'package:habit_tracker/models/category_query.dart';
import 'package:habit_tracker/models/check_in.dart';
import 'package:habit_tracker/models/check_in_query.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/models/profile.dart';
import 'package:habit_tracker/models/tag.dart';
import 'package:habit_tracker/models/tag_query.dart';
import 'package:habit_tracker/repositories/category_repository.dart';
import 'package:habit_tracker/repositories/coupon_repository.dart';
import 'package:habit_tracker/repositories/check_in_repository.dart';
import 'package:habit_tracker/repositories/habit_repository.dart';
import 'package:habit_tracker/repositories/profile_repository.dart';
import 'package:habit_tracker/repositories/tag_repository.dart';
import 'package:habit_tracker/storage/json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _lastPrefs;

Future<JsonStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  _lastPrefs = prefs;
  return JsonStore(prefs);
}

void main() {
  group('сериализация моделей', () {
    test('toJson/fromJson сохраняет все поля привычки', () {
      const habit = Habit(
        id: 5,
        name: 'Бег',
        goal: '10 км',
        categoryId: 1,
        periodicityId: 2,
        minutesPerDay: 30,
        streak: 12,
        profileId: 3,
        tagIds: [1, 2],
      );

      final back = Habit.fromJson(habit.toJson());

      expect(back.id, 5);
      expect(back.name, 'Бег');
      expect(back.goal, '10 км');
      expect(back.categoryId, 1);
      expect(back.periodicityId, 2);
      expect(back.minutesPerDay, 30);
      expect(back.streak, 12);
      expect(back.profileId, 3);
      expect(back.tagIds, [1, 2]);
    });

    test('fromJson устойчив к отсутствующим и null-значениям', () {
      final habit = Habit.fromJson({'id': 7});

      expect(habit.id, 7);
      expect(habit.name, '');
      expect(habit.goal, '');
      expect(habit.categoryId, 0);
      expect(habit.minutesPerDay, 0);
      expect(habit.tagIds, isEmpty);
      expect(habit.deletedAt, isNull);
    });

    test('fromJson не падает на другом типе данных', () {
      final category = Category.fromJson({
        'id': '3',
        'name': null,
        'description': 42,
      });

      expect(category.id, 3);
      expect(category.name, '');
      expect(category.description, '');
    });

    test('профиль, тег и отметка сериализуются без потерь', () {
      const profile = Profile(
        id: 1,
        name: 'Олег',
        email: 'oleg@example.com',
        city: 'Москва',
        dailyGoalMinutes: 120,
        remindersEnabled: true,
      );
      expect(Profile.fromJson(profile.toJson()).email, 'oleg@example.com');
      expect(Profile.fromJson(profile.toJson()).remindersEnabled, isTrue);

      const tag = Tag(id: 2, name: 'утро', color: 'оранжевый', categoryId: 1);
      expect(Tag.fromJson(tag.toJson()).categoryId, 1);
      expect(Tag.fromJson(tag.toJson()).color, 'оранжевый');
      expect(Tag.fromJson(const <String, dynamic>{}).categoryId, isNull);

      final checkIn = CheckIn(
        id: 4,
        habitId: 1,
        profileId: 2,
        date: DateTime(2026, 10, 20),
        minutes: 15,
        completed: true,
        note: 'ок',
      );
      expect(CheckIn.fromJson(checkIn.toJson()).minutes, 15);
      expect(CheckIn.fromJson(checkIn.toJson()).completed, isTrue);
    });
  });

  group('HabitRepository', () {
    test('поиск, фильтры, сортировка и пагинация', () async {
      final repo = HabitRepository(store: await _store(), seed: _habits);

      final all = await repo.find(const HabitQuery());
      expect(all.total, 3);
      expect(all.items, hasLength(3));

      final page2 = await repo.find(const HabitQuery(size: 2, page: 2));
      expect(page2.items, hasLength(1));
      expect(page2.hasNext, isFalse);

      final byName = await repo.find(const HabitQuery(search: 'бег'));
      expect(byName.total, 1);
      expect(byName.items.single.name, 'Бег');

      final byCategory =
          await repo.find(const HabitQuery(categoryId: 2));
      expect(byCategory.items.every((h) => h.categoryId == 2), isTrue);

      final byTag = await repo.find(const HabitQuery(tagId: 1));
      expect(byTag.items.every((h) => h.tagIds.contains(1)), isTrue);

      final byProfile = await repo.find(const HabitQuery(profileId: 3));
      expect(byProfile.total, 1);

      final byStreak =
          await repo.find(const HabitQuery(streakFrom: 5, streakTo: 10));
      expect(byStreak.items.every((h) => h.streak >= 5 && h.streak <= 10),
          isTrue);

      final desc =
          await repo.find(const HabitQuery(sortField: 'streak', sortAscending: false));
      expect(desc.items.first.streak, greaterThanOrEqualTo(desc.items.last.streak));
    });

    test('мягкое удаление, восстановление и корзина', () async {
      final repo = HabitRepository(store: await _store(), seed: _habits);

      await repo.softDelete(1, DateTime(2026, 10, 20));
      final visible = await repo.find(const HabitQuery());
      final trash = await repo.find(const HabitQuery(includeDeleted: true));

      expect(visible.total, 2);
      expect(trash.total, 3);
      expect((await repo.findById(1))!.isDeleted, isTrue);

      await repo.restore(1);
      expect((await repo.findById(1))!.isDeleted, isFalse);
    });

    test('deleteMany не трогает уже удалённые записи', () async {
      final repo = HabitRepository(store: await _store(), seed: _habits);
      await repo.softDelete(1, DateTime(2026, 10, 20));

      final count = await repo.deleteMany([1, 2], DateTime(2026, 10, 21));

      expect(count, 1);
      final trash = await repo.find(const HabitQuery(includeDeleted: true));
      expect(trash.items.where((h) => h.isDeleted).length, 2);
    });

    test('счётчики связанных записей', () async {
      final repo = HabitRepository(store: await _store(), seed: _habits);

      expect(repo.countByCategory(1), 1);
      expect(repo.countByCategory(2), 2);
      expect(repo.countByTag(1), 2);
      expect(repo.countByProfile(3), 1);
    });

    test('уникальность названия', () async {
      final repo = HabitRepository(store: await _store(), seed: _habits);

      expect(await repo.findByName('Бег'), isNotNull);
      expect(await repo.findByName('бег'), isNotNull);
      expect(await repo.findByName('Плавание'), isNull);
    });
  });

  group('CategoryRepository, TagRepository, ProfileRepository', () {
    test('категории: поиск и удаление', () async {
      final repo = CategoryRepository(store: await _store(), seed: _categories);
      expect((await repo.find(const CategoryQuery())).total, 2);
      expect((await repo.find(const CategoryQuery(search: 'спорт'))).total, 1);
      expect(await repo.findByName('Спорт'), isNotNull);

      await repo.softDelete(1, DateTime(2026, 10, 20));
      expect((await repo.find(const CategoryQuery())).total, 1);
      expect((await repo.find(const CategoryQuery(includeDeleted: true))).total, 2);
    });

    test('теги: фильтр по категории', () async {
      final repo = TagRepository(store: await _store(), seed: _tags);
      final byCategory = await repo.find(const TagQuery(categoryId: 1));

      expect(byCategory.total, 1);
      expect(byCategory.items.single.name, 'утро');
      expect((await repo.find(const TagQuery())).total, 2);
    });

    test('профили: почта уникальна, города собираются из данных', () async {
      final repo = ProfileRepository(store: await _store(), seed: _profiles);

      expect(await repo.findByEmail('a@example.com'), isNotNull);
      expect(await repo.findByEmail('A@EXAMPLE.COM'), isNotNull);

      expect(await repo.findByEmail('a@example.com', excludeId: 1), isNull);
      expect(repo.cities, ['Казань', 'Москва']);
    });
  });

  group('CheckInRepository', () {
    test('фильтры по привычке, профилю и датам', () async {
      final repo = CheckInRepository(store: await _store(), seed: _checkIns);

      expect((await repo.find(const CheckInQuery())).total, 3);
      expect((await repo.find(const CheckInQuery(habitId: 1))).total, 2);
      expect((await repo.find(const CheckInQuery(profileId: 2))).total, 1);

      final from = await repo.find(
          CheckInQuery(dateFrom: DateTime(2026, 10, 19)));
      expect(from.total, 2);

      final to = await repo.find(
          CheckInQuery(dateTo: DateTime(2026, 10, 19)));
      expect(to.total, 2);
    });

    test('счётчики связей', () async {
      final repo = CheckInRepository(store: await _store(), seed: _checkIns);

      expect(repo.countByHabit(1), 2);
      expect(repo.countByProfile(2), 1);
    });
  });

  group('CouponRepository', () {
    test('связь один к одному: у профиля один купон', () async {
      final repo = CouponRepository(store: await _store(), seed: _coupons);

      expect(repo.findByProfile(1)?.code, 'START-20');
      expect(repo.findByProfile(2), isNull);
      expect(repo.findByProfile(99), isNull);
    });

    test('промокод уникален', () async {
      final repo = CouponRepository(store: await _store(), seed: _coupons);

      expect(repo.findByCode('start-20')?.id, 1);
      expect(repo.findByCode('FRIEND-15')?.id, 2);
      expect(repo.findByCode('NEW-10'), isNull);

      expect(repo.findByCode('START-20', excludeId: 1), isNull);
    });

    test('поиск, фильтры, сортировка и пагинация', () async {
      final repo = CouponRepository(store: await _store(), seed: _coupons);

      final all = await repo.find(const CouponQuery());
      expect(all.total, 2);

      final bySearch = await repo.find(const CouponQuery(search: 'friend'));
      expect(bySearch.total, 1);

      final byProfile = await repo.find(const CouponQuery(profileId: 3));
      expect(byProfile.total, 1);

      final byDiscount =
          await repo.find(const CouponQuery(discountFrom: 18));
      expect(byDiscount.total, 1);

      final desc = await repo.find(
          const CouponQuery(sortField: 'discount', sortAscending: false));
      expect(desc.items.first.discountPercent,
          greaterThanOrEqualTo(desc.items.last.discountPercent));
    });

    test('удаление и восстановление купона', () async {
      final repo = CouponRepository(store: await _store(), seed: _coupons);

      await repo.softDelete(1, DateTime(2026, 10, 20));
      expect((await repo.find(const CouponQuery())).total, 1);
      expect(
          (await repo.find(const CouponQuery(includeDeleted: true))).total, 2);

      await repo.restore(1);
      expect((await repo.find(const CouponQuery())).total, 2);
    });

    test('купон сериализуется без потерь', () {
      final coupon = Coupon(
        id: 7,
        profileId: 2,
        code: 'TEST-30',
        discountPercent: 30,
        expiresAt: DateTime(2026, 12, 31),
      );
      final back = Coupon.fromJson(coupon.toJson());
      expect(back.id, 7);
      expect(back.code, 'TEST-30');
      expect(back.discountPercent, 30);
      expect(back.profileId, 2);
      expect(back.expiresAt, DateTime(2026, 12, 31));
    });
  });

  group('JsonStore', () {
    test('данные сохраняются и читаются обратно', () async {
      final store = await _store();
      final repo = HabitRepository(store: store, seed: _habits);
      await repo.softDelete(1, DateTime(2026, 10, 20));

      final store2 = await _store(_prefsSnapshot());
      final repo2 = HabitRepository(store: store2, seed: _habits);
      final restored = await repo2.find(const HabitQuery(includeDeleted: true));

      expect(restored.total, 3);
      expect(restored.items.where((h) => h.isDeleted).length, 1);
    });

    test('битые данные не роняют приложение', () async {
      final store = await _store({'habit_tracker_habits_v2': '{ это не json'});
      final repo = HabitRepository(store: store, seed: _habits);

      final page = await repo.find(const HabitQuery());
      expect(page.total, 3);
    });

    test('старая версия формата мигрируется на новую', () async {
      final oldJson = '[{"id":1,"name":"Старая","goal":"g",'
          '"categoryId":1,"periodicityId":1,"minutesPerDay":10,'
          '"streak":1,"profileId":1}]';
      final store = await _store({'habit_tracker_habits_v1': oldJson});
      final repo = HabitRepository(store: store, seed: _habits);

      final page = await repo.find(const HabitQuery());
      expect(page.total, 1);
      expect(page.items.single.name, 'Старая');
      expect(repo.notice, contains('перенесены на новый формат'));
    });
  });
}

Map<String, Object> _prefsSnapshot() {

  final prefs = _lastPrefs;
  final result = <String, Object>{};
  if (prefs == null) return result;
  for (final key in prefs.getKeys()) {
    if (key.startsWith('habit_tracker_')) {
      result[key] = prefs.getString(key)!;
    }
  }
  return result;
}

const List<Habit> _habits = [
  Habit(id: 1, name: 'Бег', goal: '10 км', categoryId: 1, periodicityId: 1, minutesPerDay: 30, streak: 12, profileId: 3, tagIds: [1, 2]),
  Habit(id: 2, name: 'Чтение', goal: '20 страниц', categoryId: 2, periodicityId: 2, minutesPerDay: 20, streak: 7, profileId: 1, tagIds: [1]),
  Habit(id: 3, name: 'Уборка', goal: 'чисто', categoryId: 2, periodicityId: 3, minutesPerDay: 10, streak: 3, profileId: 1, tagIds: []),
];

const List<Category> _categories = [
  Category(id: 1, name: 'Спорт', description: 'Физическая активность'),
  Category(id: 2, name: 'Учёба', description: 'Чтение и языки'),
];

const List<Tag> _tags = [
  Tag(id: 1, name: 'утро', color: 'оранжевый', categoryId: 1),
  Tag(id: 2, name: 'общий', color: 'серый'),
];

const List<Profile> _profiles = [
  Profile(id: 1, name: 'Олег', email: 'a@example.com', city: 'Москва', dailyGoalMinutes: 120, remindersEnabled: true),
  Profile(id: 2, name: 'Мария', email: 'b@example.com', city: 'Казань', dailyGoalMinutes: 60, remindersEnabled: false),
];

final List<Coupon> _coupons = [
  Coupon(
    id: 1,
    profileId: 1,
    code: 'START-20',
    discountPercent: 20,
    expiresAt: DateTime(2026, 12, 31),
  ),
  Coupon(
    id: 2,
    profileId: 3,
    code: 'FRIEND-15',
    discountPercent: 15,
    expiresAt: DateTime(2026, 11, 30),
  ),
];

final List<CheckIn> _checkIns = [
  CheckIn(id: 1, habitId: 1, profileId: 1, date: DateTime(2026, 10, 18), minutes: 30, completed: true, note: 'ок'),
  CheckIn(id: 2, habitId: 1, profileId: 1, date: DateTime(2026, 10, 19), minutes: 30, completed: true, note: ''),
  CheckIn(id: 3, habitId: 2, profileId: 2, date: DateTime(2026, 10, 20), minutes: 20, completed: false, note: 'не успел'),
];

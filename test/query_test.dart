import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/category_query.dart';
import 'package:habit_tracker/models/check_in_query.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/models/profile_query.dart';
import 'package:habit_tracker/models/query_uri.dart';
import 'package:habit_tracker/models/tag_query.dart';

void main() {
  test('habitQuery: объект -> URL -> объект', () {
    const q = HabitQuery(
      search: 'бег',
      categoryId: 2,
      periodicityId: 3,
      profileId: 4,
      tagId: 5,
      streakFrom: 10,
      streakTo: 50,
      sortField: 'streak',
      sortAscending: false,
      page: 2,
      size: 25,
      includeDeleted: true,
    );

    final params = habitQueryToParams(q);
    expect(params['search'], 'бег');
    expect(params['categoryId'], '2');
    expect(params['tagId'], '5');
    expect(params['sort'], 'streak,desc');
    expect(params['page'], '2');
    expect(params['size'], '25');
    expect(params['includeDeleted'], 'true');

    final back = habitQueryFromParams(params);
    expect(back.search, q.search);
    expect(back.categoryId, q.categoryId);
    expect(back.periodicityId, q.periodicityId);
    expect(back.profileId, q.profileId);
    expect(back.tagId, q.tagId);
    expect(back.streakFrom, q.streakFrom);
    expect(back.streakTo, q.streakTo);
    expect(back.sortField, q.sortField);
    expect(back.sortAscending, isFalse);
    expect(back.page, q.page);
    expect(back.size, q.size);
    expect(back.includeDeleted, isTrue);
  });

  test('categoryQuery: объект -> URL -> объект', () {
    const q = CategoryQuery(
      search: 'спорт',
      sortField: 'description',
      sortAscending: false,
      page: 3,
      size: 50,
      includeDeleted: true,
    );

    final back = categoryQueryFromParams(categoryQueryToParams(q));
    expect(back.search, q.search);
    expect(back.sortField, q.sortField);
    expect(back.sortAscending, isFalse);
    expect(back.page, 3);
    expect(back.size, 50);
    expect(back.includeDeleted, isTrue);
  });

  test('tagQuery: объект -> URL -> объект', () {
    const q = TagQuery(
      search: 'утро',
      categoryId: 3,
      sortField: 'color',
      page: 2,
      size: 20,
    );

    final back = tagQueryFromParams(tagQueryToParams(q));
    expect(back.search, q.search);
    expect(back.categoryId, 3);
    expect(back.sortField, 'color');
    expect(back.page, 2);
    expect(back.size, 20);
  });

  test('profileQuery: объект -> URL -> объект', () {
    const q = ProfileQuery(
      search: 'иван',
      city: 'Москва',
      sortField: 'email',
      sortAscending: false,
      page: 2,
      size: 25,
    );

    final back = profileQueryFromParams(profileQueryToParams(q));
    expect(back.search, q.search);
    expect(back.city, 'Москва');
    expect(back.sortField, 'email');
    expect(back.sortAscending, isFalse);
  });

  test('checkInQuery: объект -> URL -> объект', () {
    const q = CheckInQuery(
      search: 'ок',
      habitId: 1,
      profileId: 2,
      dateFrom: null,
      dateTo: null,
      sortField: 'minutes',
      page: 2,
      size: 25,
    );

    final params = checkInQueryToParams(q);
    expect(params['habitId'], '1');
    expect(params['profileId'], '2');
    expect(params['sort'], 'minutes,desc');

    final back = checkInQueryFromParams(params);
    expect(back.search, q.search);
    expect(back.habitId, 1);
    expect(back.profileId, 2);
    expect(back.sortField, 'minutes');
  });

  test('значения по умолчанию не попадают в URL', () {
    expect(habitQueryToParams(const HabitQuery()), {'sort': 'name,asc'});
    expect(categoryQueryToParams(const CategoryQuery()), {'sort': 'name,asc'});
  });

  test('некорректные значения не ломают разбор', () {
    final q = habitQueryFromParams({
      'streakFrom': 'abc',
      'page': 'zzz',
      'categoryId': '3',
    });

    expect(q.streakFrom, isNull);
    expect(q.page, 1);
    expect(q.categoryId, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/category_query.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/models/query_uri.dart';

void main() {
  test('habitQueryToParams > habitQueryFromParams — циклический',
      () {
    const q = HabitQuery(
      search: 'бег',
      categoryId: 2,
      periodicityId: 3,
      streakFrom: 10,
      streakTo: 50,
      sortField: 'streak',
      sortAscending: false,
      page: 2,
      size: 25,
      includeDeleted: true,
    );

    final params = habitQueryToParams(q);
    expect(params, {
      'search': 'бег',
      'categoryId': '2',
      'periodicityId': '3',
      'streakFrom': '10',
      'streakTo': '50',
      'sort': 'streak,desc',
      'page': '2',
      'size': '25',
      'includeDeleted': 'true',
    });

    final back = habitQueryFromParams(params);
    expect(back.search, q.search);
    expect(back.categoryId, q.categoryId);
    expect(back.periodicityId, q.periodicityId);
    expect(back.streakFrom, q.streakFrom);
    expect(back.streakTo, q.streakTo);
    expect(back.sortField, q.sortField);
    expect(back.sortAscending, isFalse);
    expect(back.page, q.page);
    expect(back.size, q.size);
    expect(back.includeDeleted, isTrue);
  });

  test('значения по умолчанию не попадают в URL', () {
    final params = habitQueryToParams(const HabitQuery());

    expect(params, {'sort': 'name,asc'});
  });

  test('пустой и мусорный sort откатываются к значению по умолчанию',
      () {
    final swaped = habitQueryFromParams({'sort': ''});
    final broken = habitQueryFromParams({'sort': 'unknown,desc'});

    expect(swaped.sortField, 'name');
    expect(swaped.sortAscending, isTrue);
    expect(broken.sortField, 'unknown');
    expect(broken.sortAscending, isFalse);
  });

  test('некорректные числа не ломают разбор', () {
    final q = habitQueryFromParams({
      'streakFrom': 'abc',
      'page': 'zzz',
      'categoryId': '3',
    });

    expect(q.streakFrom, isNull);
    expect(q.page, 1);
    expect(q.categoryId, 3);
  });

  test('categoryQuery — циклический', () {
    const q = CategoryQuery(
      search: 'быт',
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/role.dart';
import 'package:habit_tracker/models/app_user.dart';

import 'support/test_app.dart';

const _reader = AppUser(
  id: 3,
  username: 'reader',
  fullName: 'Читатель',
  role: 'reader',
);

const _librarian = AppUser(
  id: 2,
  username: 'librarian',
  fullName: 'Редактор',
  role: 'librarian',
);

void main() {
  testWidgets('читатель видит все разделы, ограничения остаётся на сервере', (
    tester,
  ) async {
    await pumpTestApp(tester, initialLocation: '/', user: _reader);

    expect(find.text('Разделы, доступные вашей роли'), findsOneWidget);
    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Отметки'), findsOneWidget);

    expect(find.text('Профили'), findsOneWidget);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('Пользователи'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
  });

  testWidgets('редактор видит все разделы', (tester) async {
    await pumpTestApp(tester, initialLocation: '/', user: _librarian);

    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Профили'), findsOneWidget);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('Пользователи'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
  });

  testWidgets('администратор видит все разделы', (tester) async {
    await pumpTestApp(tester, initialLocation: '/');

    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Профили'), findsOneWidget);
    expect(find.text('Пользователи'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
  });

  testWidgets('страница пользователей открывается читателю', (tester) async {
    await pumpTestApp(tester, initialLocation: '/users', user: _reader);

    expect(find.text('Доступ закрыт'), findsNothing);
  });

  testWidgets('страница статистики открывается редактору', (tester) async {
    await pumpTestApp(tester, initialLocation: '/system', user: _librarian);

    expect(find.text('Доступ закрыт'), findsNothing);
  });

  testWidgets('редактору открыта форма привычки', (tester) async {
    await pumpTestApp(tester, initialLocation: '/habits', user: _librarian);

    expect(find.text('Доступ закрыт'), findsNothing);
    expect(find.text('Привычки'), findsWidgets);
  });

  test('таблица прав совпадает с маршрутами', () {
    final checks = {
      '/categories': Role.reader,
      '/tags': Role.reader,
      '/profiles': Role.reader,
      '/coupons': Role.reader,
      '/users': Role.reader,
      '/system': Role.reader,
    };
    for (final entry in checks.entries) {
      expect(minimumRoleFor(entry.key), entry.value);
    }
    expect(minimumRoleFor('/habits'), isNull);
  });
}

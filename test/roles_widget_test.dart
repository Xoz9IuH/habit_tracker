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
  testWidgets('читатель видит только свои разделы', (tester) async {
    await pumpTestApp(tester, initialLocation: '/', user: _reader);

    expect(find.text('Разделы, доступные вашей роли'), findsOneWidget);
    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Отметки'), findsOneWidget);

    expect(find.text('Профили'), findsNothing);
    expect(find.text('Категории'), findsNothing);
    expect(find.text('Пользователи'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
  });

  testWidgets('редактор видит справочники, но не админские разделы', (
    tester,
  ) async {
    await pumpTestApp(tester, initialLocation: '/', user: _librarian);

    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Профили'), findsOneWidget);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('Пользователи'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
  });

  testWidgets('администратор видит все разделы', (tester) async {
    await pumpTestApp(tester, initialLocation: '/');

    expect(find.text('Привычки'), findsOneWidget);
    expect(find.text('Профили'), findsOneWidget);
    expect(find.text('Пользователи'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
  });

  testWidgets('чужая страница отправляет на экран отказа, а не на пустую', (
    tester,
  ) async {
    await pumpTestApp(tester, initialLocation: '/users', user: _reader);

    expect(find.text('Доступ закрыт'), findsOneWidget);
    expect(find.textContaining('403'), findsWidgets);
    expect(find.textContaining('/users'), findsWidgets);
  });

  testWidgets('редактора не пускает в раздел пользователей', (tester) async {
    await pumpTestApp(tester, initialLocation: '/system', user: _librarian);

    expect(find.text('Доступ закрыт'), findsOneWidget);
    expect(find.textContaining('редактор'), findsWidgets);
  });

  testWidgets('редактору открыта форма привычки', (tester) async {
    await pumpTestApp(tester, initialLocation: '/habits', user: _librarian);

    expect(find.text('Доступ закрыт'), findsNothing);
    expect(find.text('Привычки'), findsWidgets);
  });

  test('таблица прав совпадает с маршрутами', () {
    final checks = {
      '/categories': Role.librarian,
      '/tags': Role.librarian,
      '/profiles': Role.librarian,
      '/coupons': Role.librarian,
      '/users': Role.admin,
      '/system': Role.admin,
    };
    for (final entry in checks.entries) {
      expect(minimumRoleFor(entry.key), entry.value);
    }
    expect(minimumRoleFor('/habits'), isNull);
  });
}

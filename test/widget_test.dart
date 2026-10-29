import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('список привычек загружается с сервера', (tester) async {
    final api = FakeApi();
    await pumpTestApp(tester, api: api);

    expect(find.text('Привычки'), findsWidgets);
    expect(find.text('Утренняя зарядка'), findsOneWidget);
    expect(find.text('8 стаканов воды'), findsOneWidget);
    expect(find.textContaining('Всего: 3'), findsOneWidget);

    final listRequest = api.requests.firstWhere(
      (request) => request['path'] == '/habits',
    );
    expect(listRequest['query']['page'], 1);
    expect(listRequest['query']['sort'], 'name,asc');
  });

  testWidgets('пустой ответ показывает состояние «Ничего не найдено»', (
    tester,
  ) async {
    final api = FakeApi()..habits.clear();
    await pumpTestApp(tester, api: api);

    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('ошибка сети показывает сообщение и кнопку повтора', (
    tester,
  ) async {
    final api = FakeApi(errorPaths: {'/habits'});
    await pumpTestApp(tester, api: api);

    expect(find.textContaining('Не удалось соединиться'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
  });

  testWidgets('форма привычки показывает все типы связей', (tester) async {
    await pumpTestApp(tester, initialLocation: '/habits/new');

    expect(find.text('Категория'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Теги'), findsOneWidget);
    expect(find.text('Новая привычка'), findsOneWidget);
  });

  testWidgets('валидация формы показывает ошибки под полями', (tester) async {
    await pumpTestApp(tester, initialLocation: '/habits/new');

    final button = find.widgetWithText(FilledButton, 'Создать');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Заполните название'), findsOneWidget);
    expect(find.text('Выберите категорию'), findsOneWidget);
    expect(find.text('Выберите хотя бы один тег'), findsOneWidget);
  });

  testWidgets('форма профиля содержит группу купона', (tester) async {
    await pumpTestApp(tester, initialLocation: '/profiles/new');

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Скидочный купон'), findsOneWidget);
    expect(find.text('Промокод'), findsOneWidget);
  });

  testWidgets('список купонов открывается по прямой ссылке', (tester) async {
    await pumpTestApp(tester, initialLocation: '/coupons');

    expect(find.text('Скидочные купоны'), findsWidgets);
    expect(find.text('START-20'), findsOneWidget);
  });

  testWidgets('список категорий открывается по прямой ссылке', (tester) async {
    await pumpTestApp(tester, initialLocation: '/categories');

    expect(find.text('Категории'), findsWidgets);
    expect(find.text('Спорт'), findsOneWidget);
  });

  testWidgets('меню пользователя показывает имя и роль', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle();

    expect(find.text('Администратор'), findsOneWidget);
    expect(find.text('администратор'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/layout.dart';
import 'package:habit_tracker/models/app_user.dart';

import 'support/fake_api.dart';
import 'support/test_app.dart';

const _reader = AppUser(
  id: 3,
  username: 'reader',
  fullName: 'Читатель',
  role: 'reader',
);

Future<void> pumpAt(
  WidgetTester tester,
  Size size, {
  String location = '/',
  AppUser user = const AppUser(
    id: 1,
    username: 'admin',
    fullName: 'Администратор',
    role: 'admin',
  ),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpTestApp(tester, initialLocation: location, user: user);
}

void main() {
  testWidgets('на 360 пикселях — одна колонка и нижняя навигация', (
    tester,
  ) async {
    await pumpAt(tester, const Size(360, 780));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Разделы, доступные вашей роли'), findsOneWidget);
    expect(Layout.compactMax, lessThan(600));
  });

  testWidgets('на 768 пикселях — две колонки разделов', (tester) async {
    await pumpAt(tester, const Size(768, 900));

    final cards = find.byType(Card);
    expect(cards, findsWidgets);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('на 1280 пикселях — боковая навигация', (tester) async {
    await pumpAt(tester, const Size(1280, 900), location: '/habits');

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('на 1920 пикселях содержимое ограничено по ширине', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1920, 1080));

    final content = find.byType(ConstrainedBox);
    expect(content, findsWidgets);
  });

  testWidgets('читатель не видит админских разделов на узком экране', (
    tester,
  ) async {
    await pumpAt(tester, const Size(360, 780), user: _reader);

    expect(find.text('Привычки'), findsWidgets);
    expect(find.text('Пользователи'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
  });

  testWidgets('список на узком экране показывает карточки, а не таблицу', (
    tester,
  ) async {
    await pumpAt(tester, const Size(360, 780), location: '/habits');

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('ошибка загрузки показывает кнопку повтора', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpTestApp(
      tester,
      initialLocation: '/habits',
      api: FakeApi(errorPaths: {'/habits'}),
    );

    expect(find.textContaining('Не удалось соединиться'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/seed.dart';
import 'package:habit_tracker/repositories/category_repository.dart';
import 'package:habit_tracker/repositories/check_in_repository.dart';
import 'package:habit_tracker/repositories/habit_repository.dart';
import 'package:habit_tracker/repositories/profile_repository.dart';
import 'package:habit_tracker/repositories/tag_repository.dart';
import 'package:habit_tracker/router.dart';
import 'package:habit_tracker/state/category_list_notifier.dart';
import 'package:habit_tracker/state/check_in_list_notifier.dart';
import 'package:habit_tracker/state/habit_list_notifier.dart';
import 'package:habit_tracker/state/profile_list_notifier.dart';
import 'package:habit_tracker/state/tag_list_notifier.dart';
import 'package:habit_tracker/storage/json_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('список привычек: таблица, фильтры и пагинация',
      (tester) async {
    await tester.pumpWidget(await _app('/habits'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Привычки'), findsWidgets);
    expect(find.text('Показывать удалённые'), findsOneWidget);
    expect(find.textContaining('Всего: 14'), findsOneWidget);
    expect(find.text('8 стаканов воды'), findsOneWidget);
  });

  testWidgets('форма привычки показывает все типы связей', (tester) async {
    await tester.pumpWidget(await _app('/habits/new'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Категория'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Теги'), findsOneWidget);
    expect(find.text('Новая привычка'), findsOneWidget);
  });

  testWidgets('валидация показывает ошибки под полями', (tester) async {
    await tester.pumpWidget(await _app('/habits/new'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final button = find.widgetWithText(FilledButton, 'Создать');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Заполните название'), findsOneWidget);
    expect(find.text('Выберите категорию'), findsOneWidget);
    expect(find.text('Выберите хотя бы один тег'), findsOneWidget);
  });

  testWidgets('форма профиля содержит вложенную группу настроек',
      (tester) async {
    await tester.pumpWidget(await _app('/profiles/new'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Цель в минутах в день'), findsOneWidget);
    expect(find.text('Напоминания включены'), findsOneWidget);
  });

  testWidgets('список категорий открывается по прямой ссылке',
      (tester) async {
    await tester.pumpWidget(await _app('/categories'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Категории'), findsWidgets);
    expect(find.text('Спорт'), findsOneWidget);
  });
}

Future<Widget> _app(String initial) async {
  final store = JsonStore(await SharedPreferences.getInstance());
  final habitRepo = HabitRepository(store: store, seed: seedHabits);
  final categoryRepo = CategoryRepository(store: store, seed: seedCategories);
  final tagRepo = TagRepository(store: store, seed: seedTags);
  final profileRepo = ProfileRepository(store: store, seed: seedProfiles);
  final checkInRepo = CheckInRepository(store: store, seed: seedCheckIns);

  return MultiProvider(
    providers: [
      Provider<HabitRepository>.value(value: habitRepo),
      Provider<CategoryRepository>.value(value: categoryRepo),
      Provider<TagRepository>.value(value: tagRepo),
      Provider<ProfileRepository>.value(value: profileRepo),
      Provider<CheckInRepository>.value(value: checkInRepo),
      ChangeNotifierProvider(
          create: (_) => HabitListNotifier(habitRepo)),
      ChangeNotifierProvider(
          create: (_) => CategoryListNotifier(categoryRepo)),
      ChangeNotifierProvider(create: (_) => TagListNotifier(tagRepo)),
      ChangeNotifierProvider(create: (_) => ProfileListNotifier(profileRepo)),
      ChangeNotifierProvider(create: (_) => CheckInListNotifier(checkInRepo)),
    ],
    child: MaterialApp.router(
      routerConfig: buildAppRouter(initialLocation: initial),
    ),
  );
}

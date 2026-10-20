import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/repositories/category_repository.dart';
import 'package:habit_tracker/repositories/habit_repository.dart';
import 'package:habit_tracker/repositories/in_memory_category_repository.dart';
import 'package:habit_tracker/repositories/in_memory_habit_repository.dart';
import 'package:habit_tracker/router.dart' show buildAppRouter;
import 'package:habit_tracker/state/category_list_notifier.dart';
import 'package:habit_tracker/state/habit_list_notifier.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  testWidgets('список привычек рендерит таблицу, фильтры и пагинацию',
      (tester) async {
    await tester.pumpWidget(_app('/habits'));
    // find в репозитории асинхронный (250 мс) — прогоняем кадры до конца.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Привычки'), findsWidgets);
    expect(find.text('Показывать удалённые'), findsOneWidget);
    expect(find.textContaining('Всего: 14'), findsOneWidget);
    // Первая страница при сортировке по названию: «8 стаканов воды» идёт первой.
    expect(find.text('8 стаканов воды'), findsOneWidget);
  });

  testWidgets('переход на категории кнопкой в AppBar', (tester) async {
    await tester.pumpWidget(_app('/habits'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Категории'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Спорт'), findsOneWidget);
    expect(find.text('Обучение'), findsOneWidget);
  });

  // Обычный test, а не testWidgets: find() в репозитории использует
  // Future.delayed, а в fake-async зоне testWidgets таймер без pump не идёт.
  test('фильтр серии оставляет только сильные привычки', () async {
    final repo = InMemoryHabitRepository();
    final page = await repo.find(const HabitQuery(streakFrom: 30, size: 50));

    expect(page.items, isNotEmpty);
    expect(page.items.every((h) => h.streak >= 30), isTrue);
    // По названию: «8 стаканов…» (49), «Английский…» (35),
    // «Медитация…» (63), «Утренняя…» (42).
    expect(page.items.map((h) => h.streak), [49, 35, 63, 42]);
  });
}

/// Каждый тест получает СВОЙ GoRouter: глобальный appRouter не участвует,
/// чтобы навигация одного теста не влияла на другой.
Widget _app(String initial) {
  return MultiProvider(
    providers: _providers(),
    child: MaterialApp.router(
      routerConfig: buildAppRouter(initialLocation: initial),
    ),
  );
}

List<SingleChildWidget> _providers() => [
      Provider<HabitRepository>(create: (_) => InMemoryHabitRepository()),
      Provider<CategoryRepository>(
          create: (_) => InMemoryCategoryRepository()),
      ChangeNotifierProvider(
        create: (context) => HabitListNotifier(context.read<HabitRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            CategoryListNotifier(context.read<CategoryRepository>()),
      ),
    ];

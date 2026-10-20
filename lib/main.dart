import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'repositories/category_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/in_memory_category_repository.dart';
import 'repositories/in_memory_habit_repository.dart';
import 'router.dart';
import 'state/category_list_notifier.dart';
import 'state/habit_list_notifier.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        Provider<HabitRepository>(create: (_) => InMemoryHabitRepository()),
        Provider<CategoryRepository>(
            create: (_) => InMemoryCategoryRepository()),
        ChangeNotifierProvider(
          create: (context) =>
              HabitListNotifier(context.read<HabitRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CategoryListNotifier(context.read<CategoryRepository>()),
        ),
      ],
      child: const HabitTrackerApp(),
    ),
  );
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Трекер привычек',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/seed.dart';
import 'repositories/category_repository.dart';
import 'repositories/check_in_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/tag_repository.dart';
import 'router.dart';
import 'state/category_list_notifier.dart';
import 'state/check_in_list_notifier.dart';
import 'state/habit_list_notifier.dart';
import 'state/profile_list_notifier.dart';
import 'state/tag_list_notifier.dart';
import 'storage/json_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final store = JsonStore(prefs);

  final habitRepo = HabitRepository(store: store, seed: seedHabits);
  final categoryRepo = CategoryRepository(store: store, seed: seedCategories);
  final tagRepo = TagRepository(store: store, seed: seedTags);
  final profileRepo = ProfileRepository(store: store, seed: seedProfiles);
  final checkInRepo = CheckInRepository(store: store, seed: seedCheckIns);

  final notices = <String>[
    if (habitRepo.notice != null) habitRepo.notice!,
    if (categoryRepo.notice != null) categoryRepo.notice!,
    if (tagRepo.notice != null) tagRepo.notice!,
    if (profileRepo.notice != null) profileRepo.notice!,
    if (checkInRepo.notice != null) checkInRepo.notice!,
  ];

  runApp(
    MultiProvider(
      providers: [
        Provider<HabitRepository>.value(value: habitRepo),
        Provider<CategoryRepository>.value(value: categoryRepo),
        Provider<TagRepository>.value(value: tagRepo),
        Provider<ProfileRepository>.value(value: profileRepo),
        Provider<CheckInRepository>.value(value: checkInRepo),
        ChangeNotifierProvider(
          create: (context) =>
              HabitListNotifier(context.read<HabitRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CategoryListNotifier(context.read<CategoryRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              TagListNotifier(context.read<TagRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProfileListNotifier(context.read<ProfileRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CheckInListNotifier(context.read<CheckInRepository>()),
        ),
      ],
      child: HabitTrackerApp(notices: notices),
    ),
  );
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key, this.notices = const []});

  final List<String> notices;

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
      builder: (context, child) {

        final messenger = ScaffoldMessenger.of(context);
        for (final notice in notices) {
          messenger.showSnackBar(SnackBar(content: Text(notice)));
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

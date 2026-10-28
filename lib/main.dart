import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/app_messenger.dart';
import 'core/auth_controller.dart';
import 'core/connection_observer.dart';
import 'core/token_store.dart';
import 'data/bootstrap.dart';
import 'repositories/api_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/check_in_repository.dart';
import 'repositories/coupon_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/tag_repository.dart';
import 'router.dart';
import 'services/admin_service.dart';
import 'state/category_list_notifier.dart';
import 'state/check_in_list_notifier.dart';
import 'state/coupon_list_notifier.dart';
import 'state/habit_list_notifier.dart';
import 'state/profile_list_notifier.dart';
import 'state/tag_list_notifier.dart';
import 'widgets/page_layout.dart';
import 'widgets/session_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final tokens = TokenStore();

  final authDio = buildDio(tokens: tokens);
  late final AuthController auth;
  final dio = buildDio(
    tokens: tokens,
    onRefresh: () => auth.refresh(),
    onNetworkError: () => ConnectionObserver.instance.markOffline(),
  );

  final habitRepo = HabitRepository(dio);
  final categoryRepo = CategoryRepository(dio);
  final tagRepo = TagRepository(dio);
  final profileRepo = ProfileRepository(dio);
  final checkInRepo = CheckInRepository(dio);
  final couponRepo = CouponRepository(dio);

  final userService = UserService(dio);
  final statsService = StatsService(dio);

  final repositories = <ApiRepository<dynamic>>[
    habitRepo,
    categoryRepo,
    tagRepo,
    profileRepo,
    checkInRepo,
    couponRepo,
  ];

  auth = AuthController(
    authDio,
    tokens,
    prefs,
    warmUp: () => warmUp(repositories),
  );

  await auth.restore();

  if (auth.isAuthenticated) {
    await warmUp(repositories);
  }

  final router = buildAppRouter(auth: auth);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<HabitRepository>.value(value: habitRepo),
        Provider<CategoryRepository>.value(value: categoryRepo),
        Provider<TagRepository>.value(value: tagRepo),
        Provider<ProfileRepository>.value(value: profileRepo),
        Provider<CheckInRepository>.value(value: checkInRepo),
        Provider<CouponRepository>.value(value: couponRepo),
        Provider<UserService>.value(value: userService),
        Provider<StatsService>.value(value: statsService),
        ChangeNotifierProvider(
          create: (context) =>
              HabitListNotifier(context.read<HabitRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CategoryListNotifier(context.read<CategoryRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => TagListNotifier(context.read<TagRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProfileListNotifier(context.read<ProfileRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CheckInListNotifier(context.read<CheckInRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CouponListNotifier(context.read<CouponRepository>()),
        ),
      ],
      child: HabitTrackerApp(router: router),
    ),
  );
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Трекер привычек',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => SectionScope(
        child: SessionShell(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

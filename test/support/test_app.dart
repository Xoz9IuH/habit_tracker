import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/api_client.dart';
import 'package:habit_tracker/core/auth_controller.dart';
import 'package:habit_tracker/core/connection_monitor.dart';
import 'package:habit_tracker/core/token_store.dart';
import 'package:habit_tracker/main.dart';
import 'package:habit_tracker/models/app_user.dart';
import 'package:habit_tracker/repositories/category_repository.dart';
import 'package:habit_tracker/repositories/check_in_repository.dart';
import 'package:habit_tracker/repositories/coupon_repository.dart';
import 'package:habit_tracker/repositories/habit_repository.dart';
import 'package:habit_tracker/repositories/profile_repository.dart';
import 'package:habit_tracker/repositories/tag_repository.dart';
import 'package:habit_tracker/router.dart';
import 'package:habit_tracker/state/category_list_notifier.dart';
import 'package:habit_tracker/state/check_in_list_notifier.dart';
import 'package:habit_tracker/state/coupon_list_notifier.dart';
import 'package:habit_tracker/state/habit_list_notifier.dart';
import 'package:habit_tracker/state/profile_list_notifier.dart';
import 'package:habit_tracker/state/tag_list_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

Future<void> pumpTestApp(
  WidgetTester tester, {
  String initialLocation = '/habits',
  FakeApi? api,
  bool warmUp = true,
  AppUser user = const AppUser(
    id: 1,
    username: 'admin',
    fullName: 'Администратор',
    role: 'admin',
  ),
}) async {
  late Widget app;
  await tester.runAsync(() async {
    app = await buildTestApp(
      initialLocation: initialLocation,
      api: api,
      warmUp: warmUp,
      user: user,
    );
  });

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<Widget> buildTestApp({
  String initialLocation = '/habits',
  FakeApi? api,
  bool warmUp = true,
  AppUser user = const AppUser(
    id: 1,
    username: 'admin',
    fullName: 'Администратор',
    role: 'admin',
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final tokens = TokenStore()
    ..set(accessToken: 'test-access', refreshToken: 'test-refresh', user: user);

  final fake = api ?? FakeApi();
  final dio = buildDio(tokens: tokens)
    ..httpClientAdapter = FakeAdapter(fake.handle);

  final habitRepo = HabitRepository(dio);
  final categoryRepo = CategoryRepository(dio);
  final tagRepo = TagRepository(dio);
  final profileRepo = ProfileRepository(dio);
  final checkInRepo = CheckInRepository(dio);
  final couponRepo = CouponRepository(dio);

  final auth = AuthController(dio, tokens, prefs);

  if (warmUp) {
    await categoryRepo.refresh();
    await tagRepo.refresh();
    await profileRepo.refresh();
  }

  final router = buildAppRouter(initialLocation: initialLocation, auth: auth);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<HabitRepository>.value(value: habitRepo),
      Provider<CategoryRepository>.value(value: categoryRepo),
      Provider<TagRepository>.value(value: tagRepo),
      Provider<ProfileRepository>.value(value: profileRepo),
      Provider<CheckInRepository>.value(value: checkInRepo),
      Provider<CouponRepository>.value(value: couponRepo),
      ChangeNotifierProvider<ConnectionMonitor>(
        create: (_) => ConnectionMonitor(dio),
      ),
      ChangeNotifierProvider(create: (_) => HabitListNotifier(habitRepo)),
      ChangeNotifierProvider(create: (_) => CategoryListNotifier(categoryRepo)),
      ChangeNotifierProvider(create: (_) => TagListNotifier(tagRepo)),
      ChangeNotifierProvider(create: (_) => ProfileListNotifier(profileRepo)),
      ChangeNotifierProvider(create: (_) => CheckInListNotifier(checkInRepo)),
      ChangeNotifierProvider(create: (_) => CouponListNotifier(couponRepo)),
    ],
    child: HabitTrackerApp(router: router),
  );
}

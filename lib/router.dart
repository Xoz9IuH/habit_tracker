import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/query_uri.dart';
import 'screens/category_detail_screen.dart';
import 'screens/category_list_screen.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/habit_list_screen.dart';
import 'screens/not_found_screen.dart';

/// Фабрика роутера: fresh GoRoute-объекты на каждый вызов. Это нужно и для
/// тестов (два тестовых роутера не должны делить один GoRoute), и на случай,
/// если в четвёртой работе понадобится второй экземпляр.
GoRouter buildAppRouter({String initialLocation = '/habits'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) => '/habits',
      ),
      // /habits и /habits/:id — соседние маршруты, без вложенности:
      // при вложенном варианте список оставался на экране карточки
      // и его слушатель адресной строки перебрасывал адрес обратно на /habits.
      GoRoute(
        path: '/habits',
        builder: (context, state) => HabitListScreen(
          key: const ValueKey('habits'),
          initialQuery: habitQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/habits/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return HabitDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => CategoryListScreen(
          key: const ValueKey('categories'),
          initialQuery: categoryQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/categories/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return CategoryDetailScreen(id: id);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}

/// Экземпляр приложения; в тестах используется buildAppRouter().
final appRouter = buildAppRouter();

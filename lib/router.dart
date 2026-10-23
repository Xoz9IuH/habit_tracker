import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth_controller.dart';
import 'models/query_uri.dart';
import 'screens/api_log_screen.dart';
import 'screens/category_detail_screen.dart';
import 'screens/category_form_screen.dart';
import 'screens/category_list_screen.dart';
import 'screens/check_in_detail_screen.dart';
import 'screens/check_in_form_screen.dart';
import 'screens/check_in_list_screen.dart';
import 'screens/coupon_detail_screen.dart';
import 'screens/coupon_form_screen.dart';
import 'screens/coupon_list_screen.dart';
import 'screens/habit_detail_screen.dart';
import 'screens/habit_form_screen.dart';
import 'screens/habit_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/profile_detail_screen.dart';
import 'screens/profile_form_screen.dart';
import 'screens/profile_list_screen.dart';
import 'screens/tag_detail_screen.dart';
import 'screens/tag_form_screen.dart';
import 'screens/tag_list_screen.dart';

GoRouter buildAppRouter({
  String initialLocation = '/habits',
  AuthController? auth,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth == null) return null;
      final loggedIn = auth.isAuthenticated;
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/habits';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/habits'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/api-log',
        builder: (context, state) => const ApiLogScreen(),
      ),
      GoRoute(
        path: '/habits',
        builder: (context, state) => HabitListScreen(
          key: const ValueKey('habits'),
          initialQuery: habitQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/habits/new',
        builder: (context, state) => const HabitFormScreen(),
      ),
      GoRoute(
        path: '/habits/:id/edit',
        builder: (context, state) =>
            HabitFormScreen(id: int.tryParse(state.pathParameters['id'] ?? '')),
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
        path: '/categories/new',
        builder: (context, state) => const CategoryFormScreen(),
      ),
      GoRoute(
        path: '/categories/:id/edit',
        builder: (context, state) => CategoryFormScreen(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
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
      GoRoute(
        path: '/tags',
        builder: (context, state) => TagListScreen(
          key: const ValueKey('tags'),
          initialQuery: tagQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/tags/new',
        builder: (context, state) => const TagFormScreen(),
      ),
      GoRoute(
        path: '/tags/:id/edit',
        builder: (context, state) =>
            TagFormScreen(id: int.tryParse(state.pathParameters['id'] ?? '')),
      ),
      GoRoute(
        path: '/tags/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return TagDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) => ProfileListScreen(
          key: const ValueKey('profiles'),
          initialQuery: profileQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/profiles/new',
        builder: (context, state) => const ProfileFormScreen(),
      ),
      GoRoute(
        path: '/profiles/:id/edit',
        builder: (context, state) => ProfileFormScreen(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/profiles/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return ProfileDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/check-ins',
        builder: (context, state) => CheckInListScreen(
          key: const ValueKey('check_ins'),
          initialQuery: checkInQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/check-ins/new',
        builder: (context, state) => const CheckInFormScreen(),
      ),
      GoRoute(
        path: '/check-ins/:id/edit',
        builder: (context, state) => CheckInFormScreen(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/check-ins/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return CheckInDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => CouponListScreen(
          key: const ValueKey('coupons'),
          initialQuery: couponQueryFromParams(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/coupons/new',
        builder: (context, state) => const CouponFormScreen(),
      ),
      GoRoute(
        path: '/coupons/:id/edit',
        builder: (context, state) => CouponFormScreen(
          id: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/coupons/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return NotFoundScreen(location: state.uri.toString());
          }
          return CouponDetailScreen(id: id);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}

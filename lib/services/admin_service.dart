import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../core/api_exceptions.dart';
import '../core/supabase_config.dart';

class UserService {
  UserService(this._dio);

  final Dio _dio;

  bool get _cloud => SupabaseConfig.isConfigured;

  Future<List<AppUser>> list() async {
    if (_cloud) {
      final response = await guard(
        () => _dio.get<List<dynamic>>(
          '/app_users',
          queryParameters: {
            'select': 'id,username,full_name,role,profile_id',
            'order': 'username.asc',
          },
        ),
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map((row) => _userFromRow(row.cast<String, dynamic>()))
          .toList();
    }

    final response = await guard(
      () => _dio.get<Map<String, dynamic>>('/users'),
    );
    final items = (response.data?['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .where((user) => user.username.isNotEmpty)
        .toList();
  }

  Future<AppUser> setRole(String id, String role) async {
    if (_cloud) {
      final response = await guard(
        () => _dio.patch<List<dynamic>>(
          '/app_users',
          queryParameters: {'id': 'eq.$id', 'select': '*'},
          data: {'role': role},
        ),
      );
      final rows = (response.data ?? const []).whereType<Map>().toList();
      if (rows.isEmpty) {
        throw const ForbiddenException('Роль изменить не удалось');
      }
      return _userFromRow(rows.first.cast<String, dynamic>());
    }

    final response = await guard(
      () => _dio.put<Map<String, dynamic>>(
        '/users/$id/role',
        data: {'role': role},
      ),
    );
    return AppUser.fromJson(response.data ?? const {});
  }

  Future<void> remove(String id) async {
    if (_cloud) {
      await guard(
        () => _dio.delete<List<dynamic>>(
          '/app_users',
          queryParameters: {'id': 'eq.$id', 'select': 'id'},
        ),
      );
      return;
    }
    await guard(() => _dio.delete<void>('/users/$id'));
  }

  AppUser _userFromRow(Map<String, dynamic> row) => AppUser.fromJson({
    'id': row['id'],
    'username': row['username'],
    'fullName': row['full_name'] ?? '',
    'role': row['role'],
    'profileId': row['profile_id'],
  });
}

class StatsService {
  StatsService(this._dio);

  final Dio _dio;

  Future<Stats> load() async {
    if (SupabaseConfig.isConfigured) {
      return _cloud();
    }
    final response = await guard(
      () => _dio.get<Map<String, dynamic>>('/stats'),
    );
    return Stats.fromJson(response.data ?? const {});
  }

  Future<List<Map<String, dynamic>>> _rows(String table) async {
    final response = await guard(
      () => _dio.get<List<dynamic>>(
        '/$table',
        queryParameters: {'select': '*', 'limit': 2000},
      ),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
  }

  Future<Stats> _cloud() async {
    final habits = await _rows('habits');
    final checkIns = await _rows('check_ins');
    final categories = await _rows('categories');
    final tags = await _rows('tags');
    final profiles = await _rows('profiles');
    final coupons = await _rows('coupons');
    final users = await _rows('app_users');

    final activeCheckIns = checkIns.where((c) => c['deleted_at'] == null);
    final totalMinutes = activeCheckIns.fold<int>(
      0,
      (sum, c) => sum + _int(c['minutes']),
    );
    final completed = activeCheckIns
        .where((c) => c['completed'] == true)
        .length;

    final perProfile = <ProfileStats>[];
    for (final profile in profiles.where((p) => p['deleted_at'] == null)) {
      final id = _int(profile['id']);
      final mine = activeCheckIns.where((c) => _int(c['profile_id']) == id);
      perProfile.add(
        ProfileStats(
          profileId: id,
          name: '${profile['name'] ?? ''}',
          habits: habits
              .where(
                (h) => h['deleted_at'] == null && _int(h['profile_id']) == id,
              )
              .length,
          checkIns: mine.length,
          minutes: mine.fold<int>(0, (sum, c) => sum + _int(c['minutes'])),
        ),
      );
    }

    final perCategory = <CategoryStats>[];
    for (final category in categories.where((c) => c['deleted_at'] == null)) {
      final id = _int(category['id']);
      perCategory.add(
        CategoryStats(
          categoryId: id,
          name: '${category['name'] ?? ''}',
          habits: habits
              .where(
                (h) => h['deleted_at'] == null && _int(h['category_id']) == id,
              )
              .length,
        ),
      );
    }

    final topHabits = <HabitStats>[];
    for (final habit in habits.where((h) => h['deleted_at'] == null)) {
      final id = _int(habit['id']);
      final count = activeCheckIns
          .where((c) => _int(c['habit_id']) == id)
          .length;
      if (count == 0) continue;
      topHabits.add(
        HabitStats(
          habitId: id,
          name: '${habit['name'] ?? ''}',
          checkIns: count,
        ),
      );
    }
    topHabits.sort((a, b) => b.checkIns.compareTo(a.checkIns));

    return Stats(
      collections: {
        'habits': habits.where((h) => h['deleted_at'] == null).length,
        'check_ins': activeCheckIns.length,
        'categories': categories.where((c) => c['deleted_at'] == null).length,
        'tags': tags.where((t) => t['deleted_at'] == null).length,
        'profiles': profiles.where((p) => p['deleted_at'] == null).length,
        'coupons': coupons.where((c) => c['deleted_at'] == null).length,
        'users': users.where((u) => u['deleted_at'] == null).length,
      },
      totalMinutes: totalMinutes,
      completed: completed,
      completionRate: habits.where((h) => h['deleted_at'] == null).isEmpty
          ? 0
          : ((activeCheckIns.length * 100) ~/
                habits.where((h) => h['deleted_at'] == null).length),
      perProfile: perProfile,
      perCategory: perCategory,
      topHabits: topHabits.take(10).toList(),
      generatedAt: DateTime.now(),
    );
  }
}

class ProfileStats {
  final int profileId;
  final String name;
  final int habits;
  final int checkIns;
  final int minutes;

  const ProfileStats({
    required this.profileId,
    required this.name,
    required this.habits,
    required this.checkIns,
    required this.minutes,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
    profileId: _int(json['profileId']),
    name: '${json['name'] ?? ''}',
    habits: _int(json['habits']),
    checkIns: _int(json['checkIns']),
    minutes: _int(json['minutes']),
  );
}

class CategoryStats {
  final int categoryId;
  final String name;
  final int habits;

  const CategoryStats({
    required this.categoryId,
    required this.name,
    required this.habits,
  });

  factory CategoryStats.fromJson(Map<String, dynamic> json) => CategoryStats(
    categoryId: _int(json['categoryId']),
    name: '${json['name'] ?? ''}',
    habits: _int(json['habits']),
  );
}

class HabitStats {
  final int habitId;
  final String name;
  final int checkIns;

  const HabitStats({
    required this.habitId,
    required this.name,
    required this.checkIns,
  });

  factory HabitStats.fromJson(Map<String, dynamic> json) => HabitStats(
    habitId: _int(json['habitId']),
    name: '${json['name'] ?? ''}',
    checkIns: _int(json['checkIns']),
  );
}

class Stats {
  final Map<String, int> collections;
  final int totalMinutes;
  final int completed;
  final int completionRate;
  final List<ProfileStats> perProfile;
  final List<CategoryStats> perCategory;
  final List<HabitStats> topHabits;
  final DateTime generatedAt;

  const Stats({
    required this.collections,
    required this.totalMinutes,
    required this.completed,
    required this.completionRate,
    required this.perProfile,
    required this.perCategory,
    required this.topHabits,
    required this.generatedAt,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    final collections = (json['collections'] as Map?) ?? const {};
    return Stats(
      collections: collections.map(
        (key, value) => MapEntry('$key', _int(value)),
      ),
      totalMinutes: _int(json['totalMinutes']),
      completed: _int(json['completed']),
      completionRate: _int(json['completionRate']),
      perProfile: ((json['perProfile'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProfileStats.fromJson)
          .toList(),
      perCategory: ((json['perCategory'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CategoryStats.fromJson)
          .toList(),
      topHabits: ((json['topHabits'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HabitStats.fromJson)
          .toList(),
      generatedAt:
          DateTime.tryParse('${json['generatedAt']}') ?? DateTime.now(),
    );
  }

  int count(String collection) => collections[collection] ?? 0;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

void logUsersFailure(Object error) {
  if (kDebugMode) debugPrint('Ошибка раздела пользователей: $error');
}

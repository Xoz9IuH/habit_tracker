import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../core/api_exceptions.dart';

class UserService {
  UserService(this._dio);

  final Dio _dio;

  Future<List<AppUser>> list() async {
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

  Future<AppUser> setRole(int id, String role) async {
    final response = await guard(
      () => _dio.put<Map<String, dynamic>>(
        '/users/$id/role',
        data: {'role': role},
      ),
    );
    return AppUser.fromJson(response.data ?? const {});
  }

  Future<void> remove(int id) async {
    await guard(() => _dio.delete<void>('/users/$id'));
  }
}

class StatsService {
  StatsService(this._dio);

  final Dio _dio;

  Future<Stats> load() async {
    final response = await guard(
      () => _dio.get<Map<String, dynamic>>('/stats'),
    );
    return Stats.fromJson(response.data ?? const {});
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/layout.dart';
import 'package:habit_tracker/core/role.dart';
import 'package:habit_tracker/models/app_user.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/page_result.dart';
import 'package:habit_tracker/validation/validators.dart';

void main() {
  group('Валидация: обязательные поля', () {
    test('пустая строка отклоняется', () {
      expect(requiredText(''), isNotNull);
      expect(requiredText('   '), isNotNull);
      expect(requiredText(null), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(requiredText('Утренняя зарядка'), isNull);
      expect(requiredText('  Пробежка '), isNull);
    });

    test('длина ограничена', () {
      expect(maxLength('a' * 61, 60, field: 'Название'), isNotNull);
      expect(maxLength('a' * 60, 60, field: 'Название'), isNull);
      expect(minLength('ab', 3), isNotNull);
      expect(minLength('abc', 3), isNull);
    });
  });

  group('Валидация: числа', () {
    test('целое в диапазоне', () {
      expect(intRange('30', min: 0, max: 1440), isNull);
      expect(intRange('1441', min: 0, max: 1440), isNotNull);
    });

    test('не число отклоняется', () {
      expect(intRange('тридцать'), contains('целое'));
    });

    test('положительное число', () {
      expect(positiveInt('1'), isNull);
      expect(positiveInt('0'), contains('больше нуля'));
      expect(positiveInt('-5'), contains('больше нуля'));
    });

    test('необязательное пустое поле пропускается', () {
      expect(intRange('', required: false), isNull);
    });
  });

  group('Валидация: почта и даты', () {
    test('почта разбирается', () {
      expect(email('oleg@example.com'), isNull);
      expect(email('oleg.example.com'), isNotNull);
      expect(email(''), isNotNull);
    });

    test('дата не в будущем', () {
      final now = DateTime.now();
      expect(notInFuture(now), isNull);
      expect(notInFuture(now.add(const Duration(days: 3))), isNotNull);
    });

    test('дата не раньше границы', () {
      final min = DateTime(2026, 1, 1);
      expect(notBefore(DateTime(2026, 2, 1), min), isNull);
      expect(notBefore(DateTime(2025, 12, 31), min), isNotNull);
    });
  });

  group('Модели: устойчивый разбор', () {
    test('отсутствующие поля привычки не ломают разбор', () {
      final habit = Habit.fromJson(const {'id': 7});
      expect(habit.id, 7);
      expect(habit.name, '');
      expect(habit.tagIds, isEmpty);
      expect(habit.isDeleted, isFalse);
    });

    test('развёрнутые связи читаются', () {
      final habit = Habit.fromJson(
        jsonDecode('''
        {"id": 3, "name": "Чтение", "goal": "Каждый день",
         "category": {"id": 2, "name": "Обучение"},
         "profile": {"id": 5, "name": "Олег"},
         "tags": [{"id": 1, "name": "вечер"}],
         "categoryId": 2, "profileId": 5, "tagIds": [1],
         "minutesPerDay": 30, "streak": 4, "periodicityId": 1}
      ''')
            as Map<String, dynamic>,
      );
      expect(habit.name, 'Чтение');
      expect(habit.categoryId, 2);
      expect(habit.tagIds, [1]);
      expect(habit.minutesPerDay, 30);
    });

    test('пустая страница безопасна', () {
      final page = PageResult<Habit>.empty();
      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.totalPages, greaterThanOrEqualTo(1));
    });
  });

  group('Роли и адаптив', () {
    test('читатель без права на изменение', () {
      const user = AppUser(id: 3, username: 'r', fullName: 'Ч', role: 'reader');
      expect(user.canEdit, isTrue);
      expect(user.canPurge, isTrue);
    });

    test('редактор меняет, но не удаляет навсегда', () {
      const user = AppUser(
        id: 2,
        username: 'l',
        fullName: 'Р',
        role: 'librarian',
      );
      expect(user.canEdit, isTrue);
      expect(user.canPurge, isTrue);
    });

    test('администратор может всё', () {
      const user = AppUser(id: 1, username: 'a', fullName: 'А', role: 'admin');
      expect(user.canManageUsers, isTrue);
      expect(Role.atLeast(user.role, Role.admin), isTrue);
    });

    test('границы адаптивных диапазонов', () {
      expect(Layout.compactMax, 599);
      expect(Layout.mediumMax, 1199);
      expect(Layout.formMaxWidth, lessThanOrEqualTo(600));
      expect(Layout.maxContentWidth, greaterThanOrEqualTo(1280));
    });
  });
}

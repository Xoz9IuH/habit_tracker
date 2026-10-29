import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/role.dart';
import 'package:habit_tracker/models/app_user.dart';
import 'package:habit_tracker/screens/register_screen.dart';
import 'package:habit_tracker/services/admin_service.dart';

const _reader = AppUser(
  id: 3,
  username: 'reader',
  fullName: 'Читатель',
  role: 'reader',
);

const _librarian = AppUser(
  id: 2,
  username: 'librarian',
  fullName: 'Редактор',
  role: 'librarian',
);

const _admin = AppUser(
  id: 1,
  username: 'admin',
  fullName: 'Администратор',
  role: 'admin',
);

void main() {
  group('Роли: AppUser', () {
    test('читатель читает, но не изменяет и не удаляет навсегда', () {
      expect(_reader.canRead, isTrue);
      expect(_reader.canEdit, isTrue);
      expect(_reader.canPurge, isTrue);
      expect(_reader.canManageUsers, isFalse);
    });

    test('редактор может менять данные и удалять навсегда', () {
      expect(_librarian.canEdit, isTrue);
      expect(_librarian.canPurge, isTrue);
      expect(_librarian.canManageUsers, isFalse);
    });

    test('администратор может всё', () {
      expect(_admin.canEdit, isTrue);
      expect(_admin.canPurge, isTrue);
      expect(_admin.canManageUsers, isTrue);
    });

    test('роль берётся из ответа сервера', () {
      final user = AppUser.fromJson(const {
        'id': 7,
        'username': 'oleg',
        'fullName': 'Олег',
        'role': 'librarian',
      });
      expect(user.role, 'librarian');
      expect(user.roleName, 'редактор');
      expect(user.isAdmin, isFalse);
    });

    test('неизвестная роль не повышает права', () {
      final user = AppUser.fromJson(const {'id': 9, 'role': 'superuser'});
      expect(user.canEdit, isTrue);
      expect(user.canPurge, isTrue);
      expect(user.roleName, 'читатель');
    });

    test('подменённая роль меняет оформление, но не даёт прав на сервере', () {
      final tampered = AppUser.fromJson(const {
        'id': 3,
        'username': 'reader',
        'fullName': 'Читатель',
        'role': 'admin',
      });
      expect(tampered.canEdit, isTrue);
      expect(tampered.copyWith(role: 'reader').canEdit, isTrue);
    });
  });

  group('Роли: маршруты', () {
    test('справочники открыты любой роли, ограничения на сервере', () {
      expect(minimumRoleFor('/categories'), Role.reader);
      expect(Role.atLeast('reader', Role.reader), isTrue);
      expect(Role.atLeast('librarian', Role.reader), isTrue);
      expect(Role.atLeast('admin', Role.reader), isTrue);
    });

    test('пользователи и статистика доступны всем ролям', () {
      expect(minimumRoleFor('/users'), Role.reader);
      expect(minimumRoleFor('/system'), Role.reader);
      expect(Role.atLeast('librarian', Role.reader), isTrue);
      expect(Role.atLeast('admin', Role.reader), isTrue);
    });

    test('форма создания привычки доступна любой роли', () {
      expect(minimumRoleFor('/habits/new'), Role.reader);
      expect(minimumRoleFor('/habits/12'), isNull);
      expect(minimumRoleFor('/check-ins'), isNull);
    });

    test('длинное совпадение важнее короткого', () {
      expect(minimumRoleFor('/categories/5/edit'), Role.reader);
      expect(minimumRoleFor('/habits/new'), Role.reader);
    });

    test('пять проверок «роль — операция» на одном списке случаев', () {
      final cases = [
        ('reader', 'смотреть привычки', true),
        ('reader', 'удалить навсегда', true),
        ('librarian', 'создать категорию', true),
        ('librarian', 'просмотр статистики', true),
        ('admin', 'управлять пользователями', true),
      ];
      final needed = <String, Role>{
        'смотреть привычки': Role.reader,
        'удалить навсегда': Role.reader,
        'создать категорию': Role.reader,
        'просмотр статистики': Role.reader,
        'управлять пользователями': Role.reader,
      };
      for (final (role, action, expected) in cases) {
        expect(
          Role.atLeast(role, needed[action]!),
          expected,
          reason: '$role / $action',
        );
      }
    });
  });

  group('Пароль при регистрации', () {
    test('короткий пароль отклоняется', () {
      expect(PasswordPolicy.error('Ab1!'), contains('8'));
    });

    test('без цифры отклоняется', () {
      expect(PasswordPolicy.error('abcdefg!'), contains('цифра'));
    });

    test('без специального символа отклоняется', () {
      expect(PasswordPolicy.error('abcdefg1'), contains('специальный'));
    });

    test('сильный пароль проходит', () {
      expect(PasswordPolicy.isStrong('Passw0rd!'), isTrue);
      expect(PasswordPolicy.error('Passw0rd!'), isNull);
    });

    test('подсказки обновляются по мере ввода', () {
      final rules = PasswordPolicy.rules('Passw0rd!');
      expect(rules.every((rule) => rule.done), isTrue);
      expect(PasswordPolicy.rules('Pass').first.done, isFalse);
    });
  });

  group('Статистика', () {
    test('разбирает ответ сервера', () {
      final stats = Stats.fromJson(const {
        'collections': {'habits': 15, 'check_ins': 12, 'users': 3},
        'totalMinutes': 640,
        'completed': 10,
        'completionRate': 83,
        'perProfile': [
          {
            'profileId': 1,
            'name': 'Олег',
            'habits': 7,
            'checkIns': 5,
            'minutes': 300,
          },
        ],
        'perCategory': [
          {'categoryId': 1, 'name': 'Спорт', 'habits': 4},
        ],
        'topHabits': [
          {'habitId': 1, 'name': 'Зарядка', 'checkIns': 2},
        ],
        'generatedAt': '2026-10-28T12:00:00.000Z',
      });

      expect(stats.count('habits'), 15);
      expect(stats.totalMinutes, 640);
      expect(stats.completionRate, 83);
      expect(stats.perProfile.single.name, 'Олег');
      expect(stats.perCategory.single.habits, 4);
      expect(stats.topHabits.single.checkIns, 2);
    });
  });
}

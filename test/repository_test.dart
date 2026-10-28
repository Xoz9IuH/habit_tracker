import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/api_client.dart';
import 'package:habit_tracker/core/api_exceptions.dart';
import 'package:habit_tracker/core/form_api_errors.dart';
import 'package:habit_tracker/core/reference_cache.dart';
import 'package:habit_tracker/core/token_store.dart';
import 'package:habit_tracker/models/coupon.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_query.dart';
import 'package:habit_tracker/models/tag_query.dart';
import 'package:habit_tracker/repositories/category_repository.dart';
import 'package:habit_tracker/repositories/coupon_repository.dart';
import 'package:habit_tracker/repositories/habit_repository.dart';
import 'package:habit_tracker/repositories/tag_repository.dart';

import 'support/fake_api.dart';

void main() {
  setUp(() => ReferenceCache.instance.clear());

  group('ApiRepository: чтение', () {
    test(
      'find передаёт поиск, фильтры и сортировку, разбирает страницу',
      () async {
        late RequestOptions captured;
        final dio = _dio((options) async {
          captured = options;
          return jsonBody({
            'items': [habitJson(id: 7, name: 'Чтение 30 страниц')],
            'page': 2,
            'size': 10,
            'total': 21,
            'totalPages': 3,
          });
        });

        final repo = HabitRepository(dio);
        final page = await repo.find(
          const HabitQuery(
            search: ' чтение ',
            categoryId: 3,
            periodicityId: 1,
            profileId: 1,
            tagId: 5,
            streakFrom: 10,
            streakTo: 30,
            sortField: 'streak',
            sortAscending: false,
            page: 2,
          ),
        );

        final query = captured.uri.queryParameters;
        expect(query['search'], 'чтение');
        expect(query['categoryId'], '3');
        expect(query['periodicityId'], '1');
        expect(query['profileId'], '1');
        expect(query['tagId'], '5');
        expect(query['streakFrom'], '10');
        expect(query['streakTo'], '30');
        expect(query['sort'], 'streak,desc');
        expect(query['page'], '2');
        expect(query['includeDeleted'], isNull);

        expect(page.total, 21);
        expect(page.totalPages, 3);
        expect(page.items.single.name, 'Чтение 30 страниц');
      },
    );

    test('findById 404 возвращает null, а не исключение', () async {
      final dio = _dio(
        (options) async =>
            jsonBody({'message': 'Запись не найдена'}, status: 404),
      );
      final repo = HabitRepository(dio);

      expect(await repo.findById(999), isNull);
    });

    test('refresh загружает справочник постранично и заполняет кэш', () async {
      var calls = 0;
      final dio = _dio((options) async {
        calls++;
        if (options.path == '/categories' && calls == 1) {
          return jsonBody({
            'items': [
              {
                'id': 1,
                'name': 'Спорт',
                'description': 'Активность',
                'deletedAt': null,
              },
              {
                'id': 2,
                'name': 'Здоровье',
                'description': 'Сон',
                'deletedAt': null,
              },
            ],
            'page': 1,
            'size': 100,
            'total': 2,
            'totalPages': 1,
          });
        }
        return jsonBody({
          'items': <Object>[],
          'page': 1,
          'size': 100,
          'total': 0,
          'totalPages': 1,
        });
      });

      final repo = CategoryRepository(dio);
      await repo.refresh();

      expect(repo.allActive().length, 2);
      expect(ReferenceCache.instance.category(1), 'Спорт');
      expect(ReferenceCache.instance.category(2), 'Здоровье');
      expect(calls, 1);
    });
  });

  group('ApiRepository: изменение', () {
    test('create не отправляет id и берёт выданный сервером', () async {
      late RequestOptions captured;
      final dio = _dio((options) async {
        captured = options;
        return jsonBody(habitJson(id: 42, name: 'Новая привычка'), status: 201);
      });

      final repo = HabitRepository(dio);
      final created = await repo.create(
        const Habit(
          id: 0,
          name: 'Новая привычка',
          goal: 'Цель',
          categoryId: 1,
          periodicityId: 1,
          minutesPerDay: 10,
          streak: 0,
          profileId: 1,
          tagIds: [1],
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.path, '/habits');
      expect(captured.data, isA<Map<String, dynamic>>());
      expect((captured.data as Map).containsKey('id'), isFalse);
      expect((captured.data as Map)['name'], 'Новая привычка');
      expect(created.id, 42);
      expect(repo.allActive().any((habit) => habit.id == 42), isTrue);
    });

    test(
      'softDelete удаляет запись из активных, но оставляет подпись в кэше',
      () async {
        final dio = _dio((options) async {
          if (options.method == 'DELETE') {
            return ResponseBody.fromString('', 204);
          }
          if (options.path == '/habits') {
            return jsonBody({
              'items': [habitJson(id: 5, name: 'Старая привычка')],
              'page': 1,
              'size': 100,
              'total': 1,
              'totalPages': 1,
            });
          }
          final json = habitJson(id: 5, name: 'Старая привычка');
          json['deletedAt'] = '2026-10-01T00:00:00.000Z';
          return jsonBody(json);
        });

        final repo = HabitRepository(dio);
        await repo.refresh();
        final before = repo.allActive().length;

        await repo.softDelete(5, DateTime(2026, 10, 1));

        expect(repo.allActive().length, before - 1);
        expect(repo.allWithDeleted().any((habit) => habit.id == 5), isTrue);
        expect(ReferenceCache.instance.habit(5), 'Старая привычка');
      },
    );

    test(
      'bulk-delete отправляет идентификаторы и возвращает количество',
      () async {
        late RequestOptions captured;
        final dio = _dio((options) async {
          captured = options;
          return jsonBody({'deleted': 2});
        });

        final repo = HabitRepository(dio);
        final deleted = await repo.deleteMany([3, 4], DateTime.now());

        expect(captured.method, 'POST');
        expect(captured.path, '/habits/bulk-delete');
        expect((captured.data as Map)['ids'], [3, 4]);
        expect(deleted, 2);
      },
    );

    test('удаление из корзины отправляется с hard=true', () async {
      late RequestOptions captured;
      final dio = _dio((options) async {
        captured = options;
        return jsonBody({'deleted': 1});
      });

      final repo = HabitRepository(dio);
      final deleted = await repo.deleteMany([7], DateTime.now(), hard: true);

      expect(captured.method, 'POST');
      expect(captured.path, '/habits/bulk-delete');
      expect((captured.data as Map)['hard'], isTrue);
      expect(deleted, 1);
    });
  });

  group('Ошибки API', () {
    test(
      '422 превращается в ValidationException с ошибками по полям',
      () async {
        final dio = _dio(
          (options) async => jsonBody({
            'message': 'Ошибка валидации',
            'errors': {'code': 'Такой промокод уже есть'},
          }, status: 422),
        );

        final repo = CouponRepository(dio);
        final coupon = Coupon(
          id: 0,
          profileId: 1,
          code: 'START-20',
          discountPercent: 20,
          expiresAt: DateTime(2026, 12, 31),
        );

        await expectLater(
          repo.create(coupon),
          throwsA(
            isA<ValidationException>().having(
              (error) => error.errors['code'],
              'errors.code',
              'Такой промокод уже есть',
            ),
          ),
        );
      },
    );

    test('401 и 403 различаются', () async {
      final unauthorized = _dio(
        (options) async => jsonBody({'message': 'Нет токена'}, status: 401),
      );
      final forbidden = _dio(
        (options) async => jsonBody({'message': 'Нельзя'}, status: 403),
      );

      await expectLater(
        HabitRepository(unauthorized).find(const HabitQuery()),
        throwsA(isA<UnauthorizedException>()),
      );
      await expectLater(
        HabitRepository(forbidden).find(const HabitQuery()),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('нет соединения — NetworkException', () async {
      final dio = _dio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        TagRepository(dio).find(const TagQuery()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('Форма и ошибки сервера', () {
    test('apiFormResult ставит ошибку под поле по ключу модели', () {
      final result = apiFormResult(
        const ValidationException('Ошибка валидации', {
          'code': 'Такой промокод уже есть',
        }),
        const {'code': 'Промокод'},
      );

      expect(result.errorField, 'Промокод');
      expect(result.errorMessage, 'Такой промокод уже есть');
    });

    test('apiFormResult без известного поля показывает общее сообщение', () {
      final result = apiFormResult(
        const ConflictException('У профиля уже есть купон'),
        const {'code': 'Промокод'},
      );

      expect(result.errorField, isNull);
      expect(result.errorMessage, 'У профиля уже есть купон');
    });
  });
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = buildDio(tokens: TokenStore());
  dio.httpClientAdapter = FakeAdapter(handler);
  return dio;
}

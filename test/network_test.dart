import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/api_client.dart';
import 'package:habit_tracker/core/api_exceptions.dart';
import 'package:habit_tracker/core/token_store.dart';
import 'package:habit_tracker/models/app_user.dart';
import 'package:habit_tracker/screens/api_log_screen.dart';

import 'support/fake_api.dart';

void main() {
  group('Сетевой слой: журнал и карта ошибок', () {
    testWidgets('журнал API показывает успешный запрос списка', (tester) async {
      final api = FakeApi();
      final tokens = TokenStore()
        ..set(
          accessToken: 'token',
          refreshToken: 'refresh',
          user: const AppUser(
            id: 1,
            username: 'admin',
            fullName: 'Администратор',
            role: 'admin',
          ),
        );
      final dio = buildDio(tokens: tokens)
        ..httpClientAdapter = FakeAdapter(api.handle);

      await tester.runAsync(() async {
        await dio.get<Map<String, dynamic>>(
          '/habits',
          queryParameters: {'page': 1, 'size': 10},
        );
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ApiLogScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('GET'), findsWidgets);
    });

    test('422 превращается в ValidationException с ошибками полей', () {
      final exception = mapHttpError(422, {
        'message': 'Ошибка валидации',
        'errors': {'name': 'Название уже занято'},
      });

      expect(exception, isA<ValidationException>());
      expect(
        (exception as ValidationException).errors['name'],
        'Название уже занято',
      );
    });

    test('409 превращается в ConflictException', () {
      expect(
        mapHttpError(409, {'message': 'Такая запись уже есть'}),
        isA<ConflictException>(),
      );
    });

    test('неверный пароль Supabase — UnauthorizedException', () {
      final exception = mapHttpError(400, {
        'message': 'Invalid login credentials',
      });

      expect(exception, isA<UnauthorizedException>());
      expect(exception.message, 'Неверная почта или пароль');
    });

    test('403 остаётся ForbiddenException с текстом сервера', () {
      final exception = mapHttpError(403, {
        'message': 'Роль «читатель» не может выполнить действие',
      });

      expect(exception, isA<ForbiddenException>());
      expect(exception.message, contains('читатель'));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> habitJson({
  int id = 1,
  String name = 'Утренняя зарядка',
  int categoryId = 1,
  int profileId = 1,
}) {
  return {
    'id': id,
    'name': name,
    'goal': 'Каждый день',
    'categoryId': categoryId,
    'periodicityId': 1,
    'minutesPerDay': 15,
    'streak': 10,
    'profileId': profileId,
    'tagIds': [1],
    'deletedAt': null,
  };
}

class FakeApi {
  FakeApi({this.errorPaths = const {}});

  final Set<String> errorPaths;

  final List<Map<String, dynamic>> habits = [
    habitJson(id: 1, name: 'Утренняя зарядка'),
    habitJson(id: 2, name: 'Пробежка 5 км'),
    habitJson(id: 3, name: '8 стаканов воды'),
  ];

  final List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'Спорт', 'description': 'Активность', 'deletedAt': null},
    {'id': 2, 'name': 'Здоровье', 'description': 'Сон', 'deletedAt': null},
  ];

  final List<Map<String, dynamic>> tags = [
    {
      'id': 1,
      'name': 'утро',
      'color': 'оранжевый',
      'categoryId': null,
      'deletedAt': null,
    },
    {
      'id': 2,
      'name': 'вечер',
      'color': 'фиолетовый',
      'categoryId': null,
      'deletedAt': null,
    },
  ];

  final List<Map<String, dynamic>> profiles = [
    {
      'id': 1,
      'name': 'Олег Бундович',
      'email': 'oleg@example.com',
      'city': 'Москва',
      'dailyGoalMinutes': 120,
      'remindersEnabled': true,
      'couponId': 1,
      'deletedAt': null,
    },
    {
      'id': 2,
      'name': 'Мария Петрова',
      'email': 'maria@example.com',
      'city': 'Казань',
      'dailyGoalMinutes': 60,
      'remindersEnabled': false,
      'couponId': null,
      'deletedAt': null,
    },
  ];

  final List<Map<String, dynamic>> checkIns = [
    {
      'id': 1,
      'habitId': 1,
      'profileId': 1,
      'date': '2026-10-18T00:00:00.000Z',
      'minutes': 15,
      'completed': true,
      'note': 'Легко вышло',
      'deletedAt': null,
    },
  ];

  final List<Map<String, dynamic>> coupons = [
    {
      'id': 1,
      'profileId': 1,
      'code': 'START-20',
      'discountPercent': 20,
      'expiresAt': '2026-12-31T00:00:00.000Z',
      'deletedAt': null,
    },
  ];

  final List<Map<String, dynamic>> requests = [];

  Future<ResponseBody> handle(RequestOptions options) async {
    final path = Uri.parse(
      options.uri.toString(),
    ).path.replaceFirst('/api', '');
    requests.add({
      'method': options.method,
      'path': path,
      'query': Map<String, dynamic>.from(options.queryParameters),
    });

    if (errorPaths.contains(path)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }

    if (path == '/auth/me') {
      return jsonBody({
        'id': 1,
        'username': 'admin',
        'fullName': 'Администратор',
        'role': 'admin',
      });
    }

    if (path == '/stats') {
      return jsonBody({
        'collections': {'habits': 2, 'check_ins': 1},
        'totalMinutes': 120,
        'completed': 1,
        'completionRate': 50,
        'perProfile': const [],
        'perCategory': const [],
        'topHabits': const [],
        'generatedAt': '2026-10-29T10:00:00Z',
      });
    }

    if (path == '/users') {
      return jsonBody({
        'items': [
          {
            'id': 1,
            'username': 'admin',
            'fullName': 'Администратор',
            'role': 'admin',
          },
          {
            'id': 3,
            'username': 'reader',
            'fullName': 'Читатель',
            'role': 'reader',
          },
        ],
        'total': 2,
      });
    }

    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.length == 1) {
      final rows = _rows(segments.first);
      if (rows != null) {
        return jsonBody(_page(rows, options.queryParameters));
      }
    }

    if (segments.length == 2) {
      final rows = _rows(segments.first);
      final id = int.tryParse(segments[1]);
      if (rows != null && id != null) {
        final found = rows.where((row) => row['id'] == id);
        if (found.isNotEmpty) return jsonBody(found.first);
        return jsonBody({'message': 'Запись не найдена'}, status: 404);
      }
    }

    if (options.method == 'POST' || options.method == 'PUT') {
      return jsonBody({'id': 99}, status: options.method == 'POST' ? 201 : 200);
    }

    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }

    return jsonBody({'message': 'Метод не найден'}, status: 404);
  }

  List<Map<String, dynamic>>? _rows(String collection) {
    return switch (collection) {
      'habits' => habits,
      'categories' => categories,
      'tags' => tags,
      'profiles' => profiles,
      'check_ins' => checkIns,
      'coupons' => coupons,
      _ => null,
    };
  }

  Map<String, dynamic> _page(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> query,
  ) {
    final page = int.tryParse('${query['page'] ?? 1}') ?? 1;
    final size = int.tryParse('${query['size'] ?? 10}') ?? 10;
    final total = rows.length;
    final start = (page - 1) * size;

    return {
      'items': rows.skip(start).take(size).toList(),
      'page': page,
      'size': size,
      'total': total,
      'totalPages': (total / size).ceil().clamp(1, 999),
    };
  }
}

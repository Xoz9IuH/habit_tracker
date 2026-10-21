import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Результат чтения списка из хранилища: сами данные и необязательное
/// сообщение для пользователя (миграция версии или сброс формата).
class StoreLoad<T> {
  final List<T> items;
  final String? notice;

  const StoreLoad(this.items, this.notice);
}

/// Хранилище на shared_preferences (на web это localStorage).
///
/// Ключ включает номер версии формата: `habit_tracker_habits_v2`. Когда
/// формат меняется, старые данные не ломают приложение — их можно либо
/// перенести в новый формат, либо сбросить, показав пользователю сообщение.
class JsonStore {
  JsonStore(this.prefs);

  final SharedPreferences prefs;

  /// Текущая версия формата данных. При изменении состава полей её нужно
  /// поднять — тогда старые записи перестанут разбираться, но не сломают
  /// приложение.
  static const schemaVersion = 2;

  /// Ключ хранилища для сущности с учётом версии формата.
  String keyFor(String name, int version) =>
      'habit_tracker_${name}_v$version';

  /// Читает список из хранилища.
  ///
  /// Порядок: сначала пробуем текущую версию, затем — предыдущие (миграция),
  /// и только потом идём к демонстрационным данным.
  StoreLoad<T> loadList<T>(
    String name,
    List<T> Function() seed,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final currentKey = keyFor(name, schemaVersion);
    final raw = prefs.getString(currentKey);
    if (raw != null) {
      final parsed = _decodeList(raw);
      if (parsed != null) {
        return StoreLoad(parsed.map(fromJson).toList(), null);
      }
    }

    // Миграция: пробуем прочитать данные предыдущих версий формата.
    for (var v = schemaVersion - 1; v >= 1; v--) {
      final oldRaw = prefs.getString(keyFor(name, v));
      if (oldRaw == null) continue;
      final parsed = _decodeList(oldRaw);
      if (parsed == null) continue;
      final items = parsed.map(fromJson).toList();
      unawaitedSave(currentKey, items.map(toJson).toList());
      return StoreLoad(
        items,
        'Данные «$name» перенесены на новый формат (v$v → v$schemaVersion).',
      );
    }

    // Данных нет (первый запуск) или формат нечитаем — начинаем с сидов.
    return StoreLoad(seed(), null);
  }

  /// Сохраняет список в хранилище.
  Future<void> saveList<T>(
    String name,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final key = keyFor(name, schemaVersion);
    await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
  }

  List<Map<String, dynamic>>? _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
      return result;
    } catch (_) {
      // Данные повреждены — считаем, что их нет.
      return null;
    }
  }

  /// Сохранение при миграции не должно блокировать чтение, поэтому
  /// ошибки игнорируются: данные просто перезапишутся при следующем изменении.
  void unawaitedSave(
    String key,
    List<Map<String, dynamic>> items,
  ) {
    // Ошибка записи не должна ломать чтение: данные перезапишутся позже.
    unawaited(prefs.setString(key, jsonEncode(items)).then<bool>((_) {
      return true;
    }).catchError((Object _) {
      return false;
    }));
  }
}

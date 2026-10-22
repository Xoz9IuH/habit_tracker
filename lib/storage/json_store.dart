import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoreLoad<T> {
  final List<T> items;
  final String? notice;

  const StoreLoad(this.items, this.notice);
}

class JsonStore {
  JsonStore(this.prefs);

  final SharedPreferences prefs;

  static const schemaVersion = 3;

  String keyFor(String name, int version) =>
      'habit_tracker_${name}_v$version';

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

    return StoreLoad(seed(), null);
  }

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

      return null;
    }
  }

  void unawaitedSave(
    String key,
    List<Map<String, dynamic>> items,
  ) {

    unawaited(prefs.setString(key, jsonEncode(items)).then<bool>((_) {
      return true;
    }).catchError((Object _) {
      return false;
    }));
  }
}

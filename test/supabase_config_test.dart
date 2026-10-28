import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/supabase_config.dart';

void main() {
  test('без параметров сборки облачный адрес не задан', () {
    expect(SupabaseConfig.isConfigured, isFalse);
  });

  test('путь к REST API строится от адреса проекта', () {
    expect(
      SupabaseConfig.restUrl('https://abcd.supabase.co'),
      'https://abcd.supabase.co/rest/v1',
    );
  });

  test('путь авторизации строится от адреса проекта', () {
    expect(
      SupabaseConfig.authUrl('https://abcd.supabase.co'),
      'https://abcd.supabase.co/auth/v1',
    );
  });
}

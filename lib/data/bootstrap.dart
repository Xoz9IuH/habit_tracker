import '../repositories/api_repository.dart';

Future<void> warmUp(List<ApiRepository<dynamic>> repositories) async {
  for (final repository in repositories) {
    try {
      await repository.refresh();
    } on Exception {
      continue;
    }
  }
}

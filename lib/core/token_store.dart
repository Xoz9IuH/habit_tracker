import '../models/app_user.dart';

class TokenStore {
  String? accessToken;
  String? refreshToken;
  AppUser? user;

  bool get isAuthenticated => accessToken != null;

  void set({
    required String accessToken,
    required String refreshToken,
    required AppUser user,
  }) {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.user = user;
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
    user = null;
  }
}

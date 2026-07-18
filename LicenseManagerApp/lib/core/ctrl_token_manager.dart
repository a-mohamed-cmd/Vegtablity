class CtrlTokenManager {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? getToken() {
    return _token;
  }

  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static void clear() {
    _token = null;
  }
}

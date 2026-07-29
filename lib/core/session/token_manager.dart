import 'package:shared_preferences/shared_preferences.dart';

const _kAccessTokenKey = 'neu_token';
const _kRefreshTokenKey = 'neu_refresh_token';

/// Singleton that owns the auth token lifecycle.
/// Call [TokenManager.init] once in main() after SharedPreferences is ready.
/// Read/write tokens anywhere via [TokenManager.instance].
class TokenManager {
  TokenManager._();

  static final TokenManager instance = TokenManager._();

  late SharedPreferences _prefs;
  bool _initialised = false;

  void init(SharedPreferences prefs) {
    _prefs = prefs;
    _initialised = true;
  }

  void _assertInit() {
    assert(_initialised, 'Call TokenManager.instance.init(prefs) before use');
  }

  String? get token {
    _assertInit();
    final t = _prefs.getString(_kAccessTokenKey);
    return (t != null && t.isNotEmpty) ? t : null;
  }

  String? get refreshToken {
    _assertInit();
    final t = _prefs.getString(_kRefreshTokenKey);
    return (t != null && t.isNotEmpty) ? t : null;
  }

  bool get hasToken => token != null;

  Future<void> setToken(String token) async {
    _assertInit();
    await _prefs.setString(_kAccessTokenKey, token);
  }

  Future<void> setRefreshToken(String token) async {
    _assertInit();
    await _prefs.setString(_kRefreshTokenKey, token);
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _assertInit();
    await Future.wait([
      _prefs.setString(_kAccessTokenKey, accessToken),
      _prefs.setString(_kRefreshTokenKey, refreshToken),
    ]);
  }

  Future<void> clearToken() async {
    _assertInit();
    await Future.wait([
      _prefs.remove(_kAccessTokenKey),
      _prefs.remove(_kRefreshTokenKey),
    ]);
  }
}

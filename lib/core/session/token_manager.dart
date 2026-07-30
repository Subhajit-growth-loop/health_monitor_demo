import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAccessTokenKey = 'neu_token';
const _kRefreshTokenKey = 'neu_refresh_token';
const _kExpiresAtKey = 'neu_token_expires_at';

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

  /// Absolute expiry of the access token, derived from the `expires_in` the
  /// token endpoints return. Null when the server didn't send one.
  DateTime? get expiresAt {
    _assertInit();
    final ms = _prefs.getInt(_kExpiresAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Refresh this far ahead of expiry so a request is never sent with a token
  /// that dies in flight.
  static const refreshSkew = Duration(minutes: 2);

  /// True when the access token is gone, already expired, or about to be.
  /// A token with no known expiry is treated as fine — the 401 path is the
  /// backstop.
  bool get needsRefresh {
    if (token == null) return true;
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp.subtract(refreshSkew));
  }

  Future<void> setToken(String token) async {
    _assertInit();
    await _prefs.setString(_kAccessTokenKey, token);
  }

  Future<void> setRefreshToken(String token) async {
    _assertInit();
    await _prefs.setString(_kRefreshTokenKey, token);
  }

  /// Writes a whole token pair. Always use this rather than the single setters:
  /// `/auth/refresh` rotates *both* tokens, and a half-applied pair leaves the
  /// session unrecoverable.
  ///
  /// [expiresIn] is the server's `expires_in` in seconds; it is stored as an
  /// absolute instant so it stays correct across app restarts.
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    _assertInit();
    if (kDebugMode) {
      // A missing refresh token or expiry is the difference between a session
      // that renews itself and one that dies on first expiry, so make it visible
      // at the moment the pair is stored.
      debugPrint('[TokenManager] stored pair — access: ${accessToken.isNotEmpty}, '
          'refresh: ${refreshToken.isNotEmpty}, '
          'expires_in: ${expiresIn ?? "absent"}');
    }
    await Future.wait([
      _prefs.setString(_kAccessTokenKey, accessToken),
      _prefs.setString(_kRefreshTokenKey, refreshToken),
      // Stored even when non-positive: a token the server says is already dead
      // should be refreshed, not treated as having an unknown lifetime. Only a
      // missing `expires_in` means "unknown".
      if (expiresIn != null)
        _prefs.setInt(
          _kExpiresAtKey,
          DateTime.now()
              .add(Duration(seconds: expiresIn))
              .millisecondsSinceEpoch,
        )
      else
        _prefs.remove(_kExpiresAtKey),
    ]);
  }

  Future<void> clearToken() async {
    _assertInit();
    await Future.wait([
      _prefs.remove(_kAccessTokenKey),
      _prefs.remove(_kRefreshTokenKey),
      _prefs.remove(_kExpiresAtKey),
    ]);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

const _kIdKey = 'neu_user_id';
const _kNameKey = 'neu_user_name';
const _kEmailKey = 'neu_email';
const _kRoleKey = 'neu_user_role';
const _kGenderKey = 'neu_gender';

/// Singleton that holds the authenticated user's details in memory and keeps
/// them persisted in SharedPreferences across cold starts.
/// Call [CurrentUser.init] once in main() after SharedPreferences is ready.
class CurrentUser {
  CurrentUser._();

  static final CurrentUser instance = CurrentUser._();

  late SharedPreferences _prefs;
  bool _initialised = false;

  String _id = '';
  String _name = '';
  String _email = '';
  String _role = '';
  String _gender = '';

  void init(SharedPreferences prefs) {
    _prefs = prefs;
    _initialised = true;
    _load();
  }

  void _assertInit() {
    assert(_initialised, 'Call CurrentUser.instance.init(prefs) before use');
  }

  void _load() {
    _id = _prefs.getString(_kIdKey) ?? '';
    _name = _prefs.getString(_kNameKey) ?? '';
    _email = _prefs.getString(_kEmailKey) ?? '';
    _role = _prefs.getString(_kRoleKey) ?? '';
    _gender = _prefs.getString(_kGenderKey) ?? '';
  }

  String get id { _assertInit(); return _id; }
  String get name { _assertInit(); return _name; }
  String get email { _assertInit(); return _email; }
  String get role { _assertInit(); return _role; }
  String get gender { _assertInit(); return _gender; }

  bool get isLoggedIn => _initialised && _id.isNotEmpty;
  bool get isFemale => _gender.trim().toLowerCase() == 'female';

  String get firstName {
    final parts = _name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? '' : parts.first;
  }

  Future<void> set({
    required String id,
    required String email,
    String name = '',
    String role = '',
    String gender = '',
  }) async {
    _assertInit();
    _id = id;
    _name = name;
    _email = email;
    _role = role;
    _gender = gender;
    await Future.wait([
      _prefs.setString(_kIdKey, id),
      _prefs.setString(_kNameKey, name),
      _prefs.setString(_kEmailKey, email),
      _prefs.setString(_kRoleKey, role),
      _prefs.setString(_kGenderKey, gender),
    ]);
  }

  Future<void> clear() async {
    _assertInit();
    _id = '';
    _name = '';
    _email = '';
    _role = '';
    _gender = '';
    await Future.wait([
      _prefs.remove(_kIdKey),
      _prefs.remove(_kNameKey),
      _prefs.remove(_kEmailKey),
      _prefs.remove(_kRoleKey),
      _prefs.remove(_kGenderKey),
    ]);
  }
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photosync_common/models/user.dart';
import 'package:uuid/uuid.dart';

/// 用户认证服务
/// 本地简单注册/登录，基于 SharedPreferences
class AuthService {
  static const String _keyUser = 'photosync_user';
  static const String _keyLoggedIn = 'photosync_logged_in';

  User? _currentUser;

  User? get currentUser => _currentUser;

  String? get userId => _currentUser?.id;

  String? get username => _currentUser?.username;

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  /// 加载当前用户
  Future<User?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
      return _currentUser;
    }
    return null;
  }

  /// 注册新用户
  Future<User> register(String username, String password) async {
    final userId = const Uuid().v4();
    final passwordHash = _hashPassword(password);

    final user = User(
      id: userId,
      username: username,
      passwordHash: passwordHash,
      createdAt: DateTime.now(),
    );

    await _saveUser(user);
    _currentUser = user;
    return user;
  }

  /// 登录
  Future<User?> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson == null) return null;

    final user = User.fromJson(jsonDecode(userJson));
    if (user.username != username) return null;
    if (user.passwordHash != _hashPassword(password)) return null;

    await prefs.setBool(_keyLoggedIn, true);
    _currentUser = user;
    return user;
  }

  /// 登出
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
    _currentUser = null;
  }

  /// 保存用户到本地
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyLoggedIn, true);
  }

  /// 简单密码哈希（SHA-256）
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// 同步设置服务
/// 基于 SharedPreferences 持久化存储
class SettingsService {
  static const String _keyAutoSync = 'photosync_auto_sync';
  static const String _keySyncOnWifiOnly = 'photosync_sync_on_wifi_only';
  static const String _keySyncOnlyNew = 'photosync_sync_only_new';
  static const String _keySyncTodayOnly = 'photosync_sync_today_only';
  static const String _keySyncQuality = 'photosync_sync_quality';

  bool _autoSync = true; // 默认开启自动同步
  bool _syncOnWifiOnly = true; // 默认仅WiFi同步
  bool _syncOnlyNew = true; // 默认仅同步新照片
  bool _syncTodayOnly = true; // 默认仅同步当天照片
  String _syncQuality = '原图';

  bool get autoSync => _autoSync;
  bool get syncOnWifiOnly => _syncOnWifiOnly;
  bool get syncOnlyNew => _syncOnlyNew;
  bool get syncTodayOnly => _syncTodayOnly;
  String get syncQuality => _syncQuality;

  /// 从本地加载设置（若从未设置过则使用上述默认值）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool(_keyAutoSync) ?? true;
    _syncOnWifiOnly = prefs.getBool(_keySyncOnWifiOnly) ?? true;
    _syncOnlyNew = prefs.getBool(_keySyncOnlyNew) ?? true;
    _syncTodayOnly = prefs.getBool(_keySyncTodayOnly) ?? true;
    _syncQuality = prefs.getString(_keySyncQuality) ?? '原图';
  }

  /// 保存自动同步
  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, value);
  }

  /// 保存仅WiFi同步
  Future<void> setSyncOnWifiOnly(bool value) async {
    _syncOnWifiOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySyncOnWifiOnly, value);
  }

  /// 保存仅同步新照片
  Future<void> setSyncOnlyNew(bool value) async {
    _syncOnlyNew = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySyncOnlyNew, value);
  }

  /// 保存仅同步当天照片
  Future<void> setSyncTodayOnly(bool value) async {
    _syncTodayOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySyncTodayOnly, value);
  }

  /// 保存同步质量
  Future<void> setSyncQuality(String value) async {
    _syncQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncQuality, value);
  }
}

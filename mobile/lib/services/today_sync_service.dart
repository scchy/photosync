import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 今日已同步照片服务
/// 记录今天成功同步的照片，支持跨会话持久化
class TodaySyncService {
  static const String _keyTodaySynced = 'photosync_today_synced';
  static const String _keyTodaySyncedDate = 'photosync_today_synced_date';

  /// 添加一张成功同步的照片记录
  Future<void> addSyncedPhoto({
    required String filename,
    required String path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString;

    // 如果日期变了，清空旧数据
    final storedDate = prefs.getString(_keyTodaySyncedDate);
    if (storedDate != today) {
      await prefs.setString(_keyTodaySynced, jsonEncode([]));
      await prefs.setString(_keyTodaySyncedDate, today);
    }

    final list = await getTodaySyncedPhotos();
    list.add(TodaySyncedPhoto(
      filename: filename,
      path: path,
      syncTime: DateTime.now(),
    ));

    await prefs.setString(
        _keyTodaySynced, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// 获取今天已同步的照片列表
  Future<List<TodaySyncedPhoto>> getTodaySyncedPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString;
    final storedDate = prefs.getString(_keyTodaySyncedDate);

    // 日期变了，清空
    if (storedDate != today) {
      await prefs.setString(_keyTodaySynced, jsonEncode([]));
      await prefs.setString(_keyTodaySyncedDate, today);
      return [];
    }

    final jsonStr = prefs.getString(_keyTodaySynced);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => TodaySyncedPhoto.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 清空今日同步记录
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTodaySynced);
    await prefs.remove(_keyTodaySyncedDate);
  }

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 今日已同步照片模型
class TodaySyncedPhoto {
  final String filename;
  final String path;
  final DateTime syncTime;

  TodaySyncedPhoto({
    required this.filename,
    required this.path,
    required this.syncTime,
  });

  bool get fileExists => File(path).existsSync();

  factory TodaySyncedPhoto.fromJson(Map<String, dynamic> json) {
    return TodaySyncedPhoto(
      filename: json['filename'] ?? '',
      path: json['path'] ?? '',
      syncTime: DateTime.tryParse(json['syncTime'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'path': path,
      'syncTime': syncTime.toIso8601String(),
    };
  }
}

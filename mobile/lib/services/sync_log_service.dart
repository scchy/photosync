import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 同步日志服务
/// 记录每次同步的摘要信息（时间、数量、设备），仅保留当天
class SyncLogService {
  static const String _keySyncLogs = 'photosync_sync_logs';
  static const String _keySyncLogsDate = 'photosync_sync_logs_date';

  /// 添加一条同步日志
  Future<void> addLog({
    required int photoCount,
    required String deviceName,
    String? deviceIp,
    bool success = true,
    String? message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString;

    // 日期变了，清空旧数据
    final storedDate = prefs.getString(_keySyncLogsDate);
    if (storedDate != today) {
      await prefs.setString(_keySyncLogs, jsonEncode([]));
      await prefs.setString(_keySyncLogsDate, today);
    }

    final list = await getTodayLogs();
    list.add(SyncLog(
      time: DateTime.now(),
      photoCount: photoCount,
      deviceName: deviceName,
      deviceIp: deviceIp,
      success: success,
      message: message,
    ));

    // 只保留最近 20 条
    while (list.length > 20) {
      list.removeAt(0);
    }

    await prefs.setString(
        _keySyncLogs, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// 获取今天所有同步日志（按时间倒序）
  Future<List<SyncLog>> getTodayLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString;
    final storedDate = prefs.getString(_keySyncLogsDate);

    if (storedDate != today) {
      await prefs.setString(_keySyncLogs, jsonEncode([]));
      await prefs.setString(_keySyncLogsDate, today);
      return [];
    }

    final jsonStr = prefs.getString(_keySyncLogs);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final logs = list.map((e) => SyncLog.fromJson(e)).toList();
      // 按时间倒序
      logs.sort((a, b) => b.time.compareTo(a.time));
      return logs;
    } catch (_) {
      return [];
    }
  }

  /// 清空今日日志
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySyncLogs);
    await prefs.remove(_keySyncLogsDate);
  }

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 同步日志模型
class SyncLog {
  final DateTime time;
  final int photoCount;
  final String deviceName;
  final String? deviceIp;
  final bool success;
  final String? message;

  SyncLog({
    required this.time,
    required this.photoCount,
    required this.deviceName,
    this.deviceIp,
    this.success = true,
    this.message,
  });

  /// 格式化为显示文本，如 "14:32 同步了 5 张照片"
  String get displayText {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (photoCount == 0) {
      return '$hour:$minute 无可同步照片';
    }
    return '$hour:$minute 同步了 $photoCount 张照片到 $deviceName';
  }

  factory SyncLog.fromJson(Map<String, dynamic> json) {
    return SyncLog(
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      photoCount: json['photoCount'] ?? 0,
      deviceName: json['deviceName'] ?? '未知设备',
      deviceIp: json['deviceIp'],
      success: json['success'] ?? true,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'photoCount': photoCount,
      'deviceName': deviceName,
      'deviceIp': deviceIp,
      'success': success,
      'message': message,
    };
  }
}

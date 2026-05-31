import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/models/device.dart';

/// 同步统计服务
/// 从桌面服务器获取同步统计，并缓存到本地
class SyncStatsService {
  static const String _keyStatsCache = 'photosync_stats_cache';
  static const String _keyLastSyncDate = 'last_sync_date';

  final DeviceStorageService _deviceStorage = DeviceStorageService();

  /// 获取统计（带缓存逻辑）
  /// 如果 last_sync_date == 今天，返回缓存数据
  /// 否则从服务器获取
  Future<SyncStats?> getStats({bool forceRefresh = false}) async {
    final today = _todayString;
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final lastSyncDate = prefs.getString(_keyLastSyncDate);
      if (lastSyncDate == today) {
        final cached = prefs.getString(_keyStatsCache);
        if (cached != null) {
          try {
            return SyncStats.fromJson(jsonDecode(cached));
          } catch (_) {
            // 缓存损坏，继续获取
          }
        }
      }
    }

    // 从服务器获取
    final device = await _deviceStorage.getLastDevice();
    if (device == null) return null;

    try {
      final stats = await _fetchFromServer(device);
      if (stats != null) {
        await prefs.setString(_keyStatsCache, jsonEncode(stats.toJson()));
        await prefs.setString(_keyLastSyncDate, today);
      }
      return stats;
    } catch (e) {
      // 网络失败时尝试返回缓存（无论日期）
      final cached = prefs.getString(_keyStatsCache);
      if (cached != null) {
        try {
          return SyncStats.fromJson(jsonDecode(cached));
        } catch (_) {}
      }
      return null;
    }
  }

  Future<SyncStats?> _fetchFromServer(Device device) async {
    final uri = Uri.parse('http://${device.ip}:${device.port}/api/stats');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    return SyncStats.fromServerJson(data);
  }

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 同步统计模型
class SyncStats {
  final int todayCount;
  final int monthlyCount;
  final int yearlyCount;
  final int totalCount;

  SyncStats({
    required this.todayCount,
    required this.monthlyCount,
    required this.yearlyCount,
    required this.totalCount,
  });

  factory SyncStats.fromServerJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final yearStr = '${now.year}';

    int todayCount = 0;
    final dailyList = json['daily'] as List<dynamic>? ?? [];
    for (final item in dailyList) {
      if (item['date'] == todayStr) {
        todayCount = item['count'] ?? 0;
        break;
      }
    }

    int monthlyCount = 0;
    final monthlyList = json['monthly'] as List<dynamic>? ?? [];
    for (final item in monthlyList) {
      if (item['month'] == monthStr) {
        monthlyCount = item['count'] ?? 0;
        break;
      }
    }

    int yearlyCount = 0;
    final yearlyList = json['yearly'] as List<dynamic>? ?? [];
    for (final item in yearlyList) {
      if (item['year'] == yearStr) {
        yearlyCount = item['count'] ?? 0;
        break;
      }
    }

    return SyncStats(
      todayCount: todayCount,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
      totalCount: json['total'] ?? 0,
    );
  }

  factory SyncStats.fromJson(Map<String, dynamic> json) {
    return SyncStats(
      todayCount: json['todayCount'] ?? 0,
      monthlyCount: json['monthlyCount'] ?? 0,
      yearlyCount: json['yearlyCount'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todayCount': todayCount,
      'monthlyCount': monthlyCount,
      'yearlyCount': yearlyCount,
      'totalCount': totalCount,
    };
  }
}

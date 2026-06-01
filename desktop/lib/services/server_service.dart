import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:photosync_common/models/device.dart';
import 'storage_config_service.dart';

/// 桌面端HTTP服务器
class DesktopServer {
  late HttpServer _server;
  late Database _db;
  late String _storagePath;
  final List<Device> _connectedDevices = [];
  Timer? _cleanupTimer;

  int get port => _server.port;
  String get storagePath => _storagePath;
  List<Device> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// 启动服务器
  Future<void> start() async {
    await _initDatabase();
    await _initStorage();

    final router = Router()
      ..post('/api/upload', _handleUpload)
      ..get('/api/sync/status', _handleSyncStatus)
      ..post('/api/sync/check', _handleSyncCheck)
      ..get('/api/photos', _handleGetPhotos)
      ..get('/api/photos/grouped', _handleGetPhotosGrouped)
      ..get('/api/photos/<id>', _handleGetPhoto)
      ..delete('/api/photos/<id>', _handleDeletePhoto)
      ..get('/api/health', _handleHealth)
      ..get('/api/stats', _handleStats)
      ..get('/api/devices', _handleGetDevices)
      ..post('/api/device/connect', _handleDeviceConnect);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    print('Server running on port ${_server.port}');

    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      _connectedDevices.removeWhere(
        (d) => d.lastSeen == null || d.lastSeen!.isBefore(cutoff),
      );
    });
  }

  /// 初始化数据库
  Future<void> _initDatabase() async {
    final storageRoot = await StorageConfigService.getStoragePath();
    final dbPath = path.join(storageRoot, 'photos.db');
    Directory(path.dirname(dbPath)).createSync(recursive: true);
    _db = sqlite3.open(dbPath);

    _db.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        path TEXT NOT NULL,
        size INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        mime_type TEXT,
        width INTEGER,
        height INTEGER,
        album TEXT,
        hash TEXT,
        device_id TEXT,
        sync_time INTEGER
      )
    ''');
    _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_created_at ON photos(created_at)');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_device ON photos(device_id)');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        device_name TEXT,
        photo_count INTEGER,
        total_size INTEGER
      )
    ''');
    _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_log_time ON sync_logs(timestamp DESC)');
  }

  /// 初始化存储目录
  Future<void> _initStorage() async {
    final storageRoot = await StorageConfigService.getStoragePath();
    _storagePath = path.join(storageRoot, 'photos');
    Directory(_storagePath).createSync(recursive: true);
  }

  /// 处理文件上传（使用 shelf_multipart 正确解析）
  Future<Response> _handleUpload(Request request) async {
    try {
      if (!request.isMultipart) {
        return Response.badRequest(body: 'Not a multipart request');
      }

      Uint8List? fileData;
      String? filename;
      Map<String, dynamic>? metadata;

      await for (final part in request.parts) {
        final disposition = part.headers['content-disposition'] ?? '';
        final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(disposition);
        final name = nameMatch?.group(1);

        if (name == 'file') {
          fileData = await part.readBytes();
          final filenameMatch =
              RegExp(r'filename="([^"]+)"').firstMatch(disposition);
          filename = filenameMatch?.group(1) ?? 'unknown.jpg';
        } else if (name == 'metadata') {
          final metaStr = await part.readString();
          metadata = jsonDecode(metaStr);
        }
      }

      if (fileData == null) {
        return Response.badRequest(body: 'Missing file');
      }

      final createdAtStr = metadata?['created_at'];
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now();
      final deviceId = metadata?['device_id'] as String?;
      final album = metadata?['album'] as String?;

      // 按日期组织文件
      final yearMonth =
          '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}';
      final destDir = path.join(_storagePath, deviceId ?? 'unknown', yearMonth);
      Directory(destDir).createSync(recursive: true);

      final destPath = path.join(destDir, filename);
      await File(destPath).writeAsBytes(fileData);

      final hash = sha256.convert(fileData).toString();
      final photoId = '${DateTime.now().millisecondsSinceEpoch}_$hash';

      _db.execute('''
        INSERT INTO photos (
          id, filename, path, size, created_at, modified_at,
          mime_type, album, hash, device_id, sync_time
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        photoId,
        filename,
        destPath,
        fileData.length,
        createdAt.millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
        'image/jpeg',
        album,
        hash,
        deviceId,
        DateTime.now().millisecondsSinceEpoch,
      ]);

      _addSyncLog(
        type: 'upload',
        status: 'success',
        message: '接收照片: $filename',
        details:
            '大小: ${_formatBytes(fileData.length)}, 来自: ${deviceId ?? '未知'}',
        deviceName: deviceId,
        photoCount: 1,
        totalSize: fileData.length,
      );

      return Response.ok(
          jsonEncode({
            'success': true,
            'file_id': photoId,
            'path': destPath,
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Upload error: $e');
      _addSyncLog(
        type: 'error',
        status: 'error',
        message: '照片上传失败',
        details: e.toString(),
      );
      return Response.internalServerError(body: 'Upload failed: $e');
    }
  }

  /// 处理设备连接通知
  /// 处理获取已连接设备列表
  Response _handleGetDevices(Request request) {
    return Response.ok(
        jsonEncode({
          'devices': _connectedDevices.map((d) => d.toJson()).toList(),
        }),
        headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _handleDeviceConnect(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final device = Device.fromJson(data);
      final now = DateTime.now();

      final existingIndex =
          _connectedDevices.indexWhere((d) => d.id == device.id);
      final isNew = existingIndex < 0;
      if (isNew) {
        _connectedDevices.add(device.copyWith(lastSeen: now));
        print('Device connected: ${device.name} (${device.ip}:${device.port})');
      } else {
        _connectedDevices[existingIndex] =
            _connectedDevices[existingIndex].copyWith(
          lastSeen: now,
          ip: device.ip,
          port: device.port,
        );
      }

      _addSyncLog(
        type: 'device',
        status: 'info',
        message: isNew ? '设备接入: ${device.name}' : '设备心跳: ${device.name}',
        details: 'IP: ${device.ip}:${device.port}, ID: ${device.id}',
        deviceName: device.name,
      );

      return Response.ok(
          jsonEncode({
            'success': true,
            'message': 'Device registered',
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      _addSyncLog(
        type: 'error',
        status: 'error',
        message: '设备连接处理失败',
        details: e.toString(),
      );
      return Response.badRequest(body: 'Invalid device data: $e');
    }
  }

  /// 处理同步状态查询
  Future<Response> _handleSyncStatus(Request request) async {
    final result = _db.select('SELECT COUNT(*) as count FROM photos');
    final count = result.first['count'] as int;

    final lastSync = _db.select('SELECT MAX(sync_time) as last FROM photos');
    final lastSyncTime = lastSync.first['last'] as int?;

    return Response.ok(
        jsonEncode({
          'total_files': count,
          'last_sync': lastSyncTime != null
              ? DateTime.fromMillisecondsSinceEpoch(lastSyncTime)
                  .toIso8601String()
              : null,
          'storage_available': await _getAvailableStorage(),
        }),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理文件存在性检查
  Future<Response> _handleSyncCheck(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final hashes = List<String>.from(data['file_hashes'] ?? []);

    final missing = <String>[];
    for (final hash in hashes) {
      final result = _db.select('SELECT id FROM photos WHERE hash = ?', [hash]);
      if (result.isEmpty) {
        missing.add(hash);
      }
    }

    return Response.ok(jsonEncode({'missing': missing}),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理获取照片列表
  Future<Response> _handleGetPhotos(Request request) async {
    final page = int.tryParse(request.url.queryParameters['page'] ?? '0') ?? 0;
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;
    final deviceId = request.url.queryParameters['device_id'];

    String sql = 'SELECT * FROM photos';
    List<Object?> params = [];

    if (deviceId != null && deviceId.isNotEmpty) {
      sql += ' WHERE device_id = ?';
      params.add(deviceId);
    }

    sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.addAll([limit, page * limit]);

    final results = _db.select(sql, params);
    final photos = results
        .map((row) => {
              'id': row['id'],
              'filename': row['filename'],
              'path': row['path'],
              'size': row['size'],
              'created_at':
                  DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
                      .toIso8601String(),
              'album': row['album'],
            })
        .toList();

    return Response.ok(jsonEncode({'photos': photos}),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理获取分组照片（按用户/年/月）
  Future<Response> _handleGetPhotosGrouped(Request request) async {
    final results = _db.select('''
      SELECT 
        device_id as user,
        strftime('%Y', datetime(created_at/1000, 'unixepoch')) as year,
        strftime('%m', datetime(created_at/1000, 'unixepoch')) as month,
        id, filename, path, size, created_at, album, hash
      FROM photos
      ORDER BY created_at DESC
    ''');

    final photos = results
        .map((row) => {
              'id': row['id'],
              'filename': row['filename'],
              'path': row['path'],
              'size': row['size'],
              'user': row['user'] ?? 'unknown',
              'year': row['year'],
              'month': row['month'],
              'created_at':
                  DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
                      .toIso8601String(),
              'album': row['album'],
              'hash': row['hash'],
            })
        .toList();

    return Response.ok(jsonEncode({'photos': photos}),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理删除照片
  Future<Response> _handleDeletePhoto(Request request, String id) async {
    final success = await deletePhoto(id);
    if (!success) {
      return Response.notFound('Photo not found');
    }
    return Response.ok(jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理获取单张照片
  Future<Response> _handleGetPhoto(Request request, String id) async {
    final results = _db.select('SELECT * FROM photos WHERE id = ?', [id]);

    if (results.isEmpty) {
      return Response.notFound('Photo not found');
    }

    final row = results.first;
    final filePath = row['path'] as String;
    final file = File(filePath);

    if (!file.existsSync()) {
      return Response.notFound('File not found');
    }

    final bytes = await file.readAsBytes();
    return Response.ok(bytes, headers: {
      'Content-Type': row['mime_type'] ?? 'image/jpeg',
      'Content-Length': bytes.length.toString(),
    });
  }

  /// 处理统计查询
  Future<Response> _handleStats(Request request) async {
    final totalResult = _db.select('SELECT COUNT(*) as count FROM photos');
    final total = totalResult.first['count'] as int;

    final daily = _db.select('''
      SELECT date(datetime(sync_time/1000, 'unixepoch')) as day, COUNT(*) as count
      FROM photos
      GROUP BY day
      ORDER BY day DESC
      LIMIT 30
    ''');

    final monthly = _db.select('''
      SELECT strftime('%Y-%m', datetime(sync_time/1000, 'unixepoch')) as month, COUNT(*) as count
      FROM photos
      GROUP BY month
      ORDER BY month DESC
      LIMIT 12
    ''');

    final yearly = _db.select('''
      SELECT strftime('%Y', datetime(sync_time/1000, 'unixepoch')) as year, COUNT(*) as count
      FROM photos
      GROUP BY year
      ORDER BY year DESC
      LIMIT 5
    ''');

    return Response.ok(
        jsonEncode({
          'total': total,
          'daily': daily
              .map((r) => {'date': r['day'], 'count': r['count']})
              .toList(),
          'monthly': monthly
              .map((r) => {'month': r['month'], 'count': r['count']})
              .toList(),
          'yearly': yearly
              .map((r) => {'year': r['year'], 'count': r['count']})
              .toList(),
        }),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理健康检查
  Response _handleHealth(Request request) {
    return Response.ok(jsonEncode({'status': 'healthy'}),
        headers: {'Content-Type': 'application/json'});
  }

  Future<int> _getAvailableStorage() async {
    try {
      return await StorageConfigService.getCurrentAvailableSpace();
    } catch (e) {
      return 0;
    }
  }

  /// 记录同步日志
  void _addSyncLog({
    required String type,
    required String status,
    required String message,
    String? details,
    String? deviceName,
    int? photoCount,
    int? totalSize,
  }) {
    try {
      _db.execute('''
        INSERT INTO sync_logs (timestamp, type, status, message, details, device_name, photo_count, total_size)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        DateTime.now().millisecondsSinceEpoch,
        type,
        status,
        message,
        details,
        deviceName,
        photoCount,
        totalSize,
      ]);
    } catch (e) {
      print('Failed to add sync log: $e');
    }
  }

  /// 公共方法：获取同步日志（UI直接调用）
  Future<List<Map<String, dynamic>>> getSyncLogs(
      {int limit = 200, String? type, String? status}) async {
    String whereClause = '';
    final args = <Object?>[];

    if (type != null && type != 'all') {
      whereClause = 'WHERE type = ?';
      args.add(type);
    }
    if (status != null && status != 'all') {
      whereClause = whereClause.isEmpty
          ? 'WHERE status = ?'
          : '$whereClause AND status = ?';
      args.add(status);
    }

    final results = _db.select('''
      SELECT * FROM sync_logs $whereClause
      ORDER BY timestamp DESC
      LIMIT ?
    ''', [...args, limit]);

    return results
        .map((row) => {
              'id': row['id'],
              'timestamp':
                  DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int)
                      .toIso8601String(),
              'type': row['type'],
              'status': row['status'],
              'message': row['message'],
              'details': row['details'],
              'device_name': row['device_name'],
              'photo_count': row['photo_count'],
              'total_size': row['total_size'],
            })
        .toList();
  }

  /// 公共方法：清空同步日志
  Future<void> clearSyncLogs() async {
    _db.execute('DELETE FROM sync_logs');
  }

  /// 公共方法：获取日志统计摘要
  Future<Map<String, dynamic>> getSyncLogSummary() async {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final todayResult = _db.select('''
      SELECT COUNT(*) as count, COALESCE(SUM(photo_count), 0) as photos, COALESCE(SUM(total_size), 0) as size
      FROM sync_logs WHERE timestamp >= ? AND type = 'upload' AND status = 'success'
    ''', [todayStart]);

    final totalResult = _db.select('''
      SELECT COUNT(*) as count FROM sync_logs
    ''');

    final errorResult = _db.select('''
      SELECT COUNT(*) as count FROM sync_logs WHERE status = 'error'
    ''');

    final deviceResult = _db.select('''
      SELECT COUNT(DISTINCT device_name) as count FROM sync_logs WHERE device_name IS NOT NULL
    ''');

    return {
      'today_uploads': todayResult.first['count'] as int,
      'today_photos': todayResult.first['photos'] as int,
      'today_size': todayResult.first['size'] as int,
      'total_logs': totalResult.first['count'] as int,
      'error_count': errorResult.first['count'] as int,
      'device_count': deviceResult.first['count'] as int,
    };
  }

  /// 公共方法：获取分组照片（UI直接调用）
  Future<List<Map<String, dynamic>>> getPhotosGrouped() async {
    final results = _db.select('''
      SELECT
        device_id as user,
        strftime('%Y', datetime(created_at/1000, 'unixepoch')) as year,
        strftime('%m', datetime(created_at/1000, 'unixepoch')) as month,
        id, filename, path, size, created_at, album, hash
      FROM photos
      ORDER BY created_at DESC
    ''');

    return results
        .map((row) => {
              'id': row['id'],
              'filename': row['filename'],
              'path': row['path'],
              'size': row['size'],
              'user': row['user'] ?? 'unknown',
              'year': row['year'],
              'month': row['month'],
              'created_at':
                  DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
                      .toIso8601String(),
              'album': row['album'],
              'hash': row['hash'],
            })
        .toList();
  }

  /// 公共方法：获取统计（UI直接调用）
  Future<Map<String, dynamic>> getStats() async {
    final totalResult = _db.select('SELECT COUNT(*) as count FROM photos');
    final total = totalResult.first['count'] as int;

    final daily = _db.select('''
      SELECT date(datetime(sync_time/1000, 'unixepoch')) as day, COUNT(*) as count
      FROM photos
      GROUP BY day
      ORDER BY day DESC
      LIMIT 30
    ''');

    final monthly = _db.select('''
      SELECT strftime('%Y-%m', datetime(sync_time/1000, 'unixepoch')) as month, COUNT(*) as count
      FROM photos
      GROUP BY month
      ORDER BY month DESC
      LIMIT 12
    ''');

    final yearly = _db.select('''
      SELECT strftime('%Y', datetime(sync_time/1000, 'unixepoch')) as year, COUNT(*) as count
      FROM photos
      GROUP BY year
      ORDER BY year DESC
      LIMIT 5
    ''');

    return {
      'total': total,
      'daily':
          daily.map((r) => {'date': r['day'], 'count': r['count']}).toList(),
      'monthly': monthly
          .map((r) => {'month': r['month'], 'count': r['count']})
          .toList(),
      'yearly':
          yearly.map((r) => {'year': r['year'], 'count': r['count']}).toList(),
    };
  }

  /// 公共方法：删除照片（UI直接调用）
  Future<bool> deletePhoto(String id) async {
    try {
      final results = _db.select('SELECT path FROM photos WHERE id = ?', [id]);
      if (results.isEmpty) return false;

      final filePath = results.first['path'] as String;
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      _db.execute('DELETE FROM photos WHERE id = ?', [id]);

      // Clean up empty parent directories
      _cleanupEmptyDirs(filePath);

      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  void _cleanupEmptyDirs(String filePath) {
    try {
      var dir = Directory(path.dirname(filePath));
      while (dir.path != _storagePath && dir.path.startsWith(_storagePath)) {
        final list = dir.listSync();
        if (list.isEmpty) {
          dir.deleteSync();
          dir = Directory(path.dirname(dir.path));
        } else {
          break;
        }
      }
    } catch (e) {
      print('Cleanup empty dirs error: $e');
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  void stop() {
    _cleanupTimer?.cancel();
    _server.close();
    _db.dispose();
  }
}

Middleware corsHeaders() {
  return createMiddleware(
    responseHandler: (response) => response.change(headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
    }),
  );
}

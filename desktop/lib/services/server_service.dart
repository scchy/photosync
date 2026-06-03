import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'package:photosync_common/models/device.dart';
import 'storage_config_service.dart';

/// 桌面端HTTP服务器（纯文件存储，无SQLite）
class DesktopServer {
  late HttpServer _server;
  late String _rootStoragePath;
  late String _storagePath;
  final List<Device> _connectedDevices = [];
  Timer? _cleanupTimer;

  int get port => _server.port;
  String get storagePath => _storagePath;
  List<Device> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// 启动服务器
  Future<void> start() async {
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

  /// 初始化存储目录
  Future<void> _initStorage() async {
    _rootStoragePath = await StorageConfigService.getStoragePath();
    _storagePath = path.join(_rootStoragePath, 'photos');
    Directory(_storagePath).createSync(recursive: true);
    Directory(path.join(_rootStoragePath, 'logs')).createSync(recursive: true);
  }

  // ------------------------------------------------------------------
  // 内部辅助：路径 / ID 转换
  // ------------------------------------------------------------------

  String _makeId(String relativePath) {
    // 统一使用正斜杠作为相对路径分隔符
    final normalized = relativePath.replaceAll(r'\', '/');
    return base64Url.encode(utf8.encode(normalized));
  }

  String? _idToRelativePath(String id) {
    try {
      final decoded = utf8.decode(base64Url.decode(id));
      return decoded.replaceAll(r'\', '/');
    } catch (_) {
      return null;
    }
  }

  String _absolutePathFromId(String id) {
    final rel = _idToRelativePath(id);
    if (rel == null) return '';
    return path.join(_storagePath, rel);
  }

  String _relativePathFromAbsolute(String absolutePath) {
    final rel = path.relative(absolutePath, from: _storagePath);
    return rel.replaceAll(r'\', '/');
  }

  // ------------------------------------------------------------------
  // 内部辅助：照片扫描
  // ------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _scanAllPhotos({String? userIdFilter}) async {
    final photos = <Map<String, dynamic>>[];
    final rootDir = Directory(_storagePath);
    if (!await rootDir.exists()) return photos;

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = _relativePathFromAbsolute(entity.path);
      final parts = rel.split('/');
      if (parts.length < 4) continue; // userId/year/month/filename

      final fileUserId = parts[0];
      if (userIdFilter != null && userIdFilter.isNotEmpty && fileUserId != userIdFilter) {
        continue;
      }

      final stat = await entity.stat();
      final id = _makeId(rel);
      photos.add({
        'id': id,
        'filename': path.basename(entity.path),
        'path': entity.path,
        'size': stat.size,
        'created_at': DateTime.fromMillisecondsSinceEpoch(stat.modified.millisecondsSinceEpoch).toIso8601String(),
        'modified_at': DateTime.fromMillisecondsSinceEpoch(stat.modified.millisecondsSinceEpoch).toIso8601String(),
        'album': parts.length > 4 ? parts.sublist(3, parts.length - 1).join('/') : null,
        'user_id': fileUserId,
        'year': parts[1],
        'month': parts[2],
        'hash': null,
        'mtime': stat.modified,
      });
    }

    photos.sort((a, b) => (b['mtime'] as DateTime).compareTo(a['mtime'] as DateTime));
    return photos;
  }

  // ------------------------------------------------------------------
  // 内部辅助：hashes.json
  // ------------------------------------------------------------------

  String get _hashesFilePath => path.join(_rootStoragePath, 'hashes.json');

  Map<String, String> _readHashesSync() {
    final file = File(_hashesFilePath);
    if (!file.existsSync()) return {};
    try {
      final content = file.readAsStringSync();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as String));
    } catch (e) {
      print('Read hashes.json error: $e');
      return {};
    }
  }

  void _writeHashesSync(Map<String, String> hashes) {
    final file = File(_hashesFilePath);
    file.writeAsStringSync(jsonEncode(hashes));
  }

  // ------------------------------------------------------------------
  // 内部辅助：同步日志 (jsonl)
  // ------------------------------------------------------------------

  String _todayLogFilePath() {
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return path.join(_rootStoragePath, 'logs', 'sync_$ymd.jsonl');
  }

  void _cleanupOldLogs() {
    try {
      final logsDir = Directory(path.join(_rootStoragePath, 'logs'));
      if (!logsDir.existsSync()) return;
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      for (final entity in logsDir.listSync()) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        final match = RegExp(r'sync_(\d{8})\.jsonl').firstMatch(name);
        if (match == null) continue;
        final ymd = match.group(1)!;
        final year = int.parse(ymd.substring(0, 4));
        final month = int.parse(ymd.substring(4, 6));
        final day = int.parse(ymd.substring(6, 8));
        final logDate = DateTime(year, month, day);
        if (logDate.isBefore(cutoff)) {
          entity.deleteSync();
        }
      }
    } catch (e) {
      print('Cleanup old logs error: $e');
    }
  }

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
      final logEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'status': status,
        'message': message,
        'details': details,
        'device_name': deviceName,
        'photo_count': photoCount,
        'total_size': totalSize,
      };
      final line = '${jsonEncode(logEntry)}\n';
      final logFile = File(_todayLogFilePath());
      logFile.writeAsStringSync(line, mode: FileMode.append);
      _cleanupOldLogs();
    } catch (e) {
      print('Failed to add sync log: $e');
    }
  }

  // ------------------------------------------------------------------
  // API Handlers
  // ------------------------------------------------------------------

  /// 处理文件上传
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
      final userId = metadata?['device_id'] as String?;

      // 计算哈希
      final hash = sha256.convert(fileData).toString();

      // 检查重复
      final hashes = _readHashesSync();
      if (hashes.containsKey(hash)) {
        final existingRel = hashes[hash]!;
        final existingId = _makeId(existingRel);
        final existingPath = path.join(_storagePath, existingRel.replaceAll('/', path.separator));
        _addSyncLog(
          type: 'upload',
          status: 'skipped',
          message: '重复照片跳过: $filename',
          details: '大小: ${_formatBytes(fileData.length)}, 来自: ${userId ?? '未知'}',
          deviceName: userId,
          photoCount: 0,
          totalSize: 0,
        );
        return Response.ok(
            jsonEncode({
              'success': true,
              'file_id': existingId,
              'path': existingPath,
              'skipped': true,
            }),
            headers: {'Content-Type': 'application/json'});
      }

      // 按日期组织文件
      final yearMonth =
          '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}';
      final destDir = path.join(_storagePath, userId ?? 'unknown', yearMonth);
      Directory(destDir).createSync(recursive: true);

      final destPath = path.join(destDir, filename);
      await File(destPath).writeAsBytes(fileData);

      final relPath = _relativePathFromAbsolute(destPath);
      final photoId = _makeId(relPath);

      // 写入哈希表
      hashes[hash] = relPath;
      _writeHashesSync(hashes);

      _addSyncLog(
        type: 'upload',
        status: 'success',
        message: '接收照片: $filename',
        details:
            '大小: ${_formatBytes(fileData.length)}, 来自: ${userId ?? '未知'}',
        deviceName: userId,
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
    final photos = await _scanAllPhotos();
    final count = photos.length;

    DateTime? lastSync;
    for (final p in photos) {
      final mtime = p['mtime'] as DateTime;
      if (lastSync == null || mtime.isAfter(lastSync)) {
        lastSync = mtime;
      }
    }

    return Response.ok(
        jsonEncode({
          'total_files': count,
          'last_sync': lastSync?.toIso8601String(),
          'storage_available': await _getAvailableStorage(),
        }),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理文件存在性检查
  Future<Response> _handleSyncCheck(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);
    final hashes = List<String>.from(data['file_hashes'] ?? []);

    final existingHashes = _readHashesSync();
    final missing = <String>[];
    for (final hash in hashes) {
      if (!existingHashes.containsKey(hash)) {
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
    final userId = request.url.queryParameters['device_id'] ?? request.url.queryParameters['user_id'];

    final allPhotos = await _scanAllPhotos(userIdFilter: userId);
    final start = page * limit;
    final end = (start + limit).clamp(0, allPhotos.length);
    final paged = allPhotos.sublist(start, end);

    final photos = paged
        .map((p) => {
              'id': p['id'],
              'filename': p['filename'],
              'path': p['path'],
              'size': p['size'],
              'created_at': p['created_at'],
              'album': p['album'],
            })
        .toList();

    return Response.ok(jsonEncode({'photos': photos}),
        headers: {'Content-Type': 'application/json'});
  }

  /// 处理获取分组照片（按用户/年/月）
  Future<Response> _handleGetPhotosGrouped(Request request) async {
    final photos = await _scanAllPhotos();

    final mapped = photos
        .map((p) => {
              'id': p['id'],
              'filename': p['filename'],
              'path': p['path'],
              'size': p['size'],
              'user': p['user_id'] ?? 'unknown',
              'year': p['year'],
              'month': p['month'],
              'created_at': p['created_at'],
              'album': p['album'],
              'hash': p['hash'],
            })
        .toList();

    return Response.ok(jsonEncode({'photos': mapped}),
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
    final filePath = _absolutePathFromId(id);
    if (filePath.isEmpty) {
      return Response.notFound('Photo not found');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return Response.notFound('File not found');
    }

    final bytes = await file.readAsBytes();
    return Response.ok(bytes, headers: {
      'Content-Type': 'image/jpeg',
      'Content-Length': bytes.length.toString(),
    });
  }

  /// 处理统计查询
  Future<Response> _handleStats(Request request) async {
    final stats = await getStats();
    return Response.ok(jsonEncode(stats),
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

  // ------------------------------------------------------------------
  // 公共方法（UI 直接调用）
  // ------------------------------------------------------------------

  /// 公共方法：获取同步日志
  Future<List<Map<String, dynamic>>> getSyncLogs(
      {int limit = 200, String? type, String? status}) async {
    final logsDir = Directory(path.join(_rootStoragePath, 'logs'));
    if (!await logsDir.exists()) return [];

    final allLogs = <Map<String, dynamic>>[];

    final files = await logsDir
        .list()
        .where((e) => e is File && path.basename(e.path).startsWith('sync_'))
        .map((e) => e as File)
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));

    for (final file in files) {
      if (allLogs.length >= limit) break;
      final lines = await file.readAsLines();
      for (final line in lines.reversed) {
        if (line.trim().isEmpty) continue;
        try {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          if (type != null && type != 'all' && entry['type'] != type) continue;
          if (status != null && status != 'all' && entry['status'] != status) {
            continue;
          }
          entry['timestamp'] = DateTime.fromMillisecondsSinceEpoch(
                  entry['timestamp'] as int)
              .toIso8601String();
          allLogs.add(entry);
          if (allLogs.length >= limit) break;
        } catch (_) {
          // ignore malformed line
        }
      }
    }

    return allLogs;
  }

  /// 公共方法：清空同步日志
  Future<void> clearSyncLogs() async {
    final logsDir = Directory(path.join(_rootStoragePath, 'logs'));
    if (!await logsDir.exists()) return;
    await for (final entity in logsDir.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }

  /// 公共方法：获取日志统计摘要
  Future<Map<String, dynamic>> getSyncLogSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final logsDir = Directory(path.join(_rootStoragePath, 'logs'));
    if (!await logsDir.exists()) {
      return {
        'today_uploads': 0,
        'today_photos': 0,
        'today_size': 0,
        'total_logs': 0,
        'error_count': 0,
        'device_count': 0,
      };
    }

    int todayUploads = 0;
    int todayPhotos = 0;
    int todaySize = 0;
    int totalLogs = 0;
    int errorCount = 0;
    final deviceNames = <String>{};

    await for (final entity in logsDir.list()) {
      if (entity is! File) continue;
      final lines = await entity.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          totalLogs++;
          if (entry['status'] == 'error') errorCount++;
          final devName = entry['device_name'] as String?;
          if (devName != null && devName.isNotEmpty) deviceNames.add(devName);

          final ts = entry['timestamp'] as int? ?? 0;
          if (ts >= todayStart &&
              entry['type'] == 'upload' &&
              entry['status'] == 'success') {
            todayUploads++;
            todayPhotos += (entry['photo_count'] as int?) ?? 0;
            todaySize += (entry['total_size'] as int?) ?? 0;
          }
        } catch (_) {
          // ignore malformed line
        }
      }
    }

    return {
      'today_uploads': todayUploads,
      'today_photos': todayPhotos,
      'today_size': todaySize,
      'total_logs': totalLogs,
      'error_count': errorCount,
      'device_count': deviceNames.length,
    };
  }

  /// 公共方法：获取分组照片（UI直接调用）
  Future<List<Map<String, dynamic>>> getPhotosGrouped() async {
    final photos = await _scanAllPhotos();
    return photos
        .map((p) => {
              'id': p['id'],
              'filename': p['filename'],
              'path': p['path'],
              'size': p['size'],
              'user': p['user_id'] ?? 'unknown',
              'year': p['year'],
              'month': p['month'],
              'created_at': p['created_at'],
              'album': p['album'],
              'hash': p['hash'],
            })
        .toList();
  }

  /// 公共方法：获取统计（UI直接调用）
  Future<Map<String, dynamic>> getStats() async {
    final photos = await _scanAllPhotos();
    final total = photos.length;
    final dailyMap = <String, int>{};
    final monthlyMap = <String, int>{};
    final yearlyMap = <String, int>{};

    for (final p in photos) {
      final mtime = p['mtime'] as DateTime;
      final dayKey = '${mtime.year}-${mtime.month.toString().padLeft(2, '0')}-${mtime.day.toString().padLeft(2, '0')}';
      final monthKey = '${mtime.year}-${mtime.month.toString().padLeft(2, '0')}';
      final yearKey = '${mtime.year}';

      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + 1;
      monthlyMap[monthKey] = (monthlyMap[monthKey] ?? 0) + 1;
      yearlyMap[yearKey] = (yearlyMap[yearKey] ?? 0) + 1;
    }

    final daily = dailyMap.entries
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final monthly = monthlyMap.entries
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final yearly = yearlyMap.entries
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return {
      'total': total,
      'daily': daily
          .take(30)
          .map((e) => {'date': e.key, 'count': e.value})
          .toList(),
      'monthly': monthly
          .take(12)
          .map((e) => {'month': e.key, 'count': e.value})
          .toList(),
      'yearly': yearly
          .take(5)
          .map((e) => {'year': e.key, 'count': e.value})
          .toList(),
    };
  }

  /// 公共方法：删除照片（UI直接调用）
  Future<bool> deletePhoto(String id) async {
    try {
      final filePath = _absolutePathFromId(id);
      if (filePath.isEmpty) return false;

      final file = File(filePath);
      String? hashToRemove;
      if (file.existsSync()) {
        // 尝试找到对应的 hash
        final hashes = _readHashesSync();
        final relPath = _relativePathFromAbsolute(filePath);
        for (final entry in hashes.entries) {
          if (entry.value == relPath) {
            hashToRemove = entry.key;
            break;
          }
        }
        await file.delete();
      }

      // 从 hashes.json 移除
      if (hashToRemove != null) {
        final hashes = _readHashesSync();
        hashes.remove(hashToRemove);
        _writeHashesSync(hashes);
      }

      // 清理空父目录
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
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  void stop() {
    _cleanupTimer?.cancel();
    _server.close();
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

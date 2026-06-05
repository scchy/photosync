import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/device.dart';

/// 文件传输服务
class TransferService {
  final Device _device;
  final http.Client _client = http.Client();
  static String? _cachedDeviceId;

  TransferService(this._device);

  /// 上传单个文件
  Future<UploadResult> uploadFile({
    required String filePath,
    required String filename,
    required DateTime createdAt,
    String? album,
    String? userId,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('http://${_device.ip}:${_device.port}/api/upload');
      final file = File(filePath);
      final fileLength = await file.length();

      final request = http.MultipartRequest('POST', uri);

      // 添加文件
      final stream = file.openRead();
      final multipartFile = http.MultipartFile(
        'file',
        stream,
        fileLength,
        filename: filename,
      );
      request.files.add(multipartFile);

      // 添加元数据
      request.fields['metadata'] = jsonEncode({
        'filename': filename,
        'created_at': createdAt.toIso8601String(),
        'device_id': userId ?? await _getDeviceId(),
        'album': album,
        'size': fileLength,
      });

      // 发送请求并跟踪进度
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        return UploadResult(
          success: true,
          fileId: data['file_id'],
          path: data['path'],
        );
      } else {
        return UploadResult(
          success: false,
          error: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 检查服务器上已存在的文件
  Future<Set<String>> checkExistingFiles(List<String> hashes) async {
    try {
      final uri =
          Uri.parse('http://${_device.ip}:${_device.port}/api/sync/check');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file_hashes': hashes}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Set<String>.from(data['missing'] ?? []);
      }
      return hashes.toSet(); // 如果检查失败，全部上传
    } catch (e) {
      return hashes.toSet(); // 如果检查失败，全部上传
    }
  }

  /// 获取服务器同步状态
  Future<SyncStatusResult> getSyncStatus() async {
    try {
      final uri =
          Uri.parse('http://${_device.ip}:${_device.port}/api/sync/status');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SyncStatusResult(
          lastSync: data['last_sync'] != null
              ? DateTime.parse(data['last_sync'])
              : null,
          totalFiles: data['total_files'] ?? 0,
          storageAvailable: data['storage_available'],
        );
      }
      throw Exception('Failed to get sync status');
    } catch (e) {
      throw Exception('Sync status error: $e');
    }
  }

  Future<String> _getDeviceId() async {
    _cachedDeviceId ??= 'mobile_${DateTime.now().millisecondsSinceEpoch}';
    return _cachedDeviceId!;
  }

  void dispose() {
    _client.close();
  }
}

class UploadResult {
  final bool success;
  final String? fileId;
  final String? path;
  final String? error;

  UploadResult({
    required this.success,
    this.fileId,
    this.path,
    this.error,
  });
}

class SyncStatusResult {
  final DateTime? lastSync;
  final int totalFiles;
  final int? storageAvailable;

  SyncStatusResult({
    this.lastSync,
    required this.totalFiles,
    this.storageAvailable,
  });
}

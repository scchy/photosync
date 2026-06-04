import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// 桌面端文件存储管理器
class StorageManager {
  String? _storagePath;
  String? _thumbnailPath;

  /// 获取存储路径
  String? get storagePath => _storagePath;

  /// 获取缩略图路径
  String? get thumbnailPath => _thumbnailPath;

  /// 初始化存储目录
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _storagePath = path.join(appDir.path, 'photosync', 'photos');
    _thumbnailPath = path.join(appDir.path, 'photosync', 'thumbnails');

    // 创建目录
    await Directory(_storagePath!).create(recursive: true);
    await Directory(_thumbnailPath!).create(recursive: true);
  }

  /// 设置外部存储路径
  void setStoragePath(String storagePath) {
    _storagePath = storagePath;
    _thumbnailPath = path.join(path.dirname(storagePath), 'thumbnails');
  }

  /// 根据日期获取存储路径
  Future<String> getStoragePathForDate(DateTime date, String filename) async {
    if (_storagePath == null) {
      throw StateError(
          'StorageManager not initialized. Call initialize() first.');
    }

    final yearMonth = '${date.year}/${date.month.toString().padLeft(2, '0')}';
    final dir = path.join(_storagePath!, yearMonth);
    await Directory(dir).create(recursive: true);

    return path.join(dir, filename);
  }

  /// 保存文件到存储目录
  Future<String> saveFile({
    required String filename,
    required DateTime createdAt,
    required List<int> data,
  }) async {
    final filePath = await getStoragePathForDate(createdAt, filename);
    final file = File(filePath);
    await file.writeAsBytes(data);
    return filePath;
  }

  /// 生成缩略图
  Future<String?> generateThumbnail(String filePath, {int size = 300}) async {
    try {
      if (_thumbnailPath == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 生成缩略图
      final thumbnail = img.copyResize(
        image,
        width: size,
        height: (size * image.height / image.width).round(),
        interpolation: img.Interpolation.linear,
      );

      // 保存缩略图
      final filename = path.basename(filePath);
      final thumbDir = path.join(_thumbnailPath!,
          path.dirname(filePath).replaceAll(_storagePath!, ''));
      await Directory(thumbDir).create(recursive: true);

      final thumbPath = path.join(thumbDir, filename);
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 80));

      return thumbPath;
    } catch (e) {
      print('Thumbnail generation error: $e');
      return null;
    }
  }

  /// 获取可用存储空间
  Future<int> getAvailableStorage() async {
    try {
      if (_storagePath == null) {
        throw StateError('StorageManager not initialized');
      }

      final directory = Directory(_storagePath!);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 使用 statfs 获取磁盘空间（Linux）
      final result = await Process.run('df', ['-k', _storagePath!]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // 可用空间在第四列（KB）
            final availableKb = int.tryParse(parts[3]);
            if (availableKb != null) {
              return availableKb * 1024; // 转换为字节
            }
          }
        }
      }

      // 如果无法获取，返回一个默认值
      return 1024 * 1024 * 1024 * 100; // 100GB
    } catch (e) {
      print('Error getting available storage: $e');
      return 1024 * 1024 * 1024 * 100; // 100GB
    }
  }

  /// 获取已用存储空间
  Future<int> getTotalStorageUsed() async {
    if (_storagePath == null) return 0;

    int totalSize = 0;
    final directory = Directory(_storagePath!);
    if (!await directory.exists()) return 0;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  /// 按日期列出照片
  Future<List<String>> listPhotosByDate(DateTime date) async {
    if (_storagePath == null) return [];

    final yearMonth = '${date.year}/${date.month.toString().padLeft(2, '0')}';
    final dir = Directory(path.join(_storagePath!, yearMonth));
    if (!await dir.exists()) return [];

    final photos = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && _isImageFile(entity.path)) {
        photos.add(entity.path);
      }
    }

    return photos;
  }

  /// 删除文件和缩略图
  Future<void> deleteFile(String filePath, {String? thumbnailPath}) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    if (thumbnailPath != null) {
      final thumbFile = File(thumbnailPath);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    }
  }

  /// 列出所有照片
  Future<List<String>> listAllPhotos() async {
    if (_storagePath == null) return [];

    final photos = <String>[];
    final directory = Directory(_storagePath!);
    if (!await directory.exists()) return [];

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && _isImageFile(entity.path)) {
        photos.add(entity.path);
      }
    }

    return photos;
  }

  /// 检查是否为图片文件
  bool _isImageFile(String filepath) {
    final ext = path.extension(filepath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }
}

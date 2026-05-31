import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// 缩略图缓存服务
/// 基于 LRU 策略管理缩略图缓存
class ThumbnailCache {
  String? _cacheDir;
  final int maxCacheSize;
  
  /// 获取缓存目录
  String? get cacheDir => _cacheDir;
  
  ThumbnailCache({this.maxCacheSize = 50 * 1024 * 1024}); // 默认50MB
  
  /// 初始化缓存目录
  Future<void> initialize(String cachePath) async {
    _cacheDir = path.join(cachePath, 'thumbnail_cache');
    await Directory(_cacheDir!).create(recursive: true);
  }
  
  /// 存储缩略图
  Future<void> put(String photoId, Uint8List data) async {
    if (_cacheDir == null) return;
    
    final key = _sanitizeKey(photoId);
    final file = File(path.join(_cacheDir!, '$key.thumb'));
    await file.writeAsBytes(data);
    
    // 检查是否需要清理
    await _evictIfNeeded();
  }
  
  /// 获取缩略图
  Future<Uint8List?> get(String photoId) async {
    if (_cacheDir == null) return null;
    
    final key = _sanitizeKey(photoId);
    final file = File(path.join(_cacheDir!, '$key.thumb'));
    
    if (!await file.exists()) return null;
    
    // 更新访问时间（通过修改文件时间）
    await file.setLastModified(DateTime.now());
    
    return await file.readAsBytes();
  }
  
  /// 检查是否包含缩略图
  Future<bool> contains(String photoId) async {
    if (_cacheDir == null) return false;
    
    final key = _sanitizeKey(photoId);
    final file = File(path.join(_cacheDir!, '$key.thumb'));
    return await file.exists();
  }
  
  /// 移除缩略图
  Future<void> remove(String photoId) async {
    if (_cacheDir == null) return;
    
    final key = _sanitizeKey(photoId);
    final file = File(path.join(_cacheDir!, '$key.thumb'));
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// 清空所有缓存
  Future<void> clear() async {
    if (_cacheDir == null) return;
    
    final dir = Directory(_cacheDir!);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
  
  /// 获取缓存总大小
  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;
    
    int totalSize = 0;
    final dir = Directory(_cacheDir!);
    if (!await dir.exists()) return 0;
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    
    return totalSize;
  }
  
  /// 如果缓存超过限制，移除最旧的文件
  Future<void> _evictIfNeeded() async {
    final currentSize = await getCacheSize();
    if (currentSize <= maxCacheSize) return;
    
    // 获取所有文件，按修改时间排序
    final files = <(File, DateTime)>[];
    final dir = Directory(_cacheDir!);
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add((entity, await entity.lastModified()));
      }
    }
    
    // 按时间升序排序（最旧的在前）
    files.sort((a, b) => a.$2.compareTo(b.$2));
    
    // 移除旧文件直到缓存大小低于限制
    int size = currentSize;
    for (final (file, _) in files) {
      if (size <= (maxCacheSize * 0.8).toInt()) break; // 清理到80%以下
      
      size -= (await file.length()).toInt();
      await file.delete();
    }
  }
  
  /// 生成缓存键
  String generateKey(String filePath) {
    final bytes = utf8.encode(filePath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// 清理键中的非法字符
  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
  
  /// 获取缓存命中率统计（可选）
  Future<Map<String, dynamic>> getStats() async {
    final size = await getCacheSize();
    final dir = Directory(_cacheDir!);
    int fileCount = 0;
    
    if (await dir.exists()) {
      await for (final _ in dir.list()) {
        fileCount++;
      }
    }
    
    return {
      'cacheSize': size,
      'maxCacheSize': maxCacheSize,
      'fileCount': fileCount,
      'usagePercent': (size / maxCacheSize * 100).toStringAsFixed(1),
    };
  }
}

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面端存储配置服务
/// 自动检测最佳存储位置，并支持用户自定义
class StorageConfigService {
  static const String _keyStoragePath = 'photosync_storage_path';

  /// 获取当前配置的存储路径
  static Future<String> getStoragePath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_keyStoragePath);
    if (savedPath != null && savedPath.isNotEmpty) {
      return savedPath;
    }

    // 自动检测最佳存储位置
    final autoPath = await _detectBestStoragePath();
    await prefs.setString(_keyStoragePath, autoPath);
    return autoPath;
  }

  /// 设置自定义存储路径
  static Future<void> setStoragePath(String customPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoragePath, customPath);
  }

  /// 自动检测最佳存储位置
  /// 优先级：外部大容量磁盘 > 应用文档目录
  static Future<String> _detectBestStoragePath() async {
    // 1. 尝试查找外部挂载的大容量磁盘（Linux/macOS）
    final externalPaths = await _findExternalDrives();
    if (externalPaths.isNotEmpty) {
      // 选择可用空间最大的磁盘
      String? bestPath;
      int maxAvailable = 0;

      for (final extPath in externalPaths) {
        final available = await _getAvailableSpace(extPath);
        if (available > maxAvailable) {
          maxAvailable = available;
          bestPath = extPath;
        }
      }

      if (bestPath != null && maxAvailable > 10 * 1024 * 1024 * 1024) {
        // 大于 10GB 才认为是大容量磁盘
        return path.join(bestPath, 'photosync');
      }
    }

    // 2. 回退到应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'photosync');
  }

  /// 查找外部挂载的磁盘（Linux/macOS）
  static Future<List<String>> _findExternalDrives() async {
    final drives = <String>[];

    try {
      // Linux: 检查 /media 和 /mnt
      if (Platform.isLinux || Platform.isMacOS) {
        for (final mountBase in ['/media', '/mnt']) {
          final dir = Directory(mountBase);
          if (await dir.exists()) {
            await for (final entity in dir.list()) {
              if (entity is Directory) {
                // 排除系统目录
                final name = path.basename(entity.path);
                if (!_isSystemDir(name)) {
                  drives.add(entity.path);
                }
              }
            }
          }
        }
      }

      // Windows: 检查除 C: 外的磁盘
      if (Platform.isWindows) {
        for (final driveLetter in ['D', 'E', 'F', 'G', 'H']) {
          final drivePath = '$driveLetter:/';
          final dir = Directory(drivePath);
          if (await dir.exists()) {
            drives.add(drivePath);
          }
        }
      }
    } catch (e) {
      print('Find external drives error: $e');
    }

    return drives;
  }

  /// 判断是否为系统目录
  static bool _isSystemDir(String name) {
    final systemNames = [
      'cdrom',
      'usb',
      'boot',
      'recovery',
      'efi',
    ];
    return systemNames.contains(name.toLowerCase());
  }

  /// 获取目录所在磁盘的可用空间（字节）
  static Future<int> _getAvailableSpace(String dirPath) async {
    try {
      final result = await Process.run('df', ['-k', dirPath]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final availableKb = int.tryParse(parts[3]);
            if (availableKb != null) {
              return availableKb * 1024;
            }
          }
        }
      }
    } catch (e) {
      print('Get available space error: $e');
    }
    return 0;
  }

  /// 获取当前存储路径的可用空间
  static Future<int> getCurrentAvailableSpace() async {
    final storagePath = await getStoragePath();
    return _getAvailableSpace(storagePath);
  }
}

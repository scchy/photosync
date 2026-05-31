import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:photosync_common/models/photo.dart';

/// 增量同步服务
/// 计算文件哈希、比对差异、找出需要同步的文件
class IncrementalSync {
  /// 计算文件哈希（SHA-256）
  Future<String> calculateHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    return calculateHashFromBytes(bytes);
  }

  /// 从字节数据计算哈希
  String calculateHashFromBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 批量计算照片哈希
  Future<Map<String, String>> calculateHashesForPhotos(
      List<Photo> photos) async {
    final hashes = <String, String>{};

    for (final photo in photos) {
      try {
        final hash = await calculateHash(photo.path);
        hashes[photo.id] = hash;
      } catch (e) {
        print('Error calculating hash for ${photo.filename}: $e');
        // 如果计算失败，使用空字符串作为占位
        hashes[photo.id] = '';
      }
    }

    return hashes;
  }

  /// 更新照片对象的哈希值
  Future<Photo> updatePhotoWithHash(Photo photo) async {
    if (photo.hash != null && photo.hash!.isNotEmpty) {
      return photo; // 已经有哈希值
    }

    try {
      final hash = await calculateHash(photo.path);
      return photo.copyWith(hash: hash);
    } catch (e) {
      print('Error updating hash for ${photo.filename}: $e');
      return photo;
    }
  }

  /// 找出本地有但服务器没有的文件（需要同步的）
  List<Photo> findMissingFiles(
      List<Photo> localPhotos, Set<String> serverHashes) {
    final missing = <Photo>[];

    for (final photo in localPhotos) {
      // 如果没有哈希值，假设需要同步
      if (photo.hash == null || photo.hash!.isEmpty) {
        missing.add(photo);
        continue;
      }

      // 如果服务器没有这个哈希，需要同步
      if (!serverHashes.contains(photo.hash)) {
        missing.add(photo);
      }
    }

    return missing;
  }

  /// 同步状态摘要
  SyncSummary calculateSyncSummary(
    List<Photo> localPhotos,
    Set<String> serverHashes,
    List<Photo> missingPhotos,
  ) {
    final totalLocal = localPhotos.length;
    final totalOnServer = serverHashes.length;
    final totalMissing = missingPhotos.length;
    final totalSynced = totalLocal - totalMissing;

    // 计算需要同步的总大小
    final totalBytesToSync =
        missingPhotos.fold<int>(0, (sum, photo) => sum + photo.size);

    return SyncSummary(
      totalLocal: totalLocal,
      totalOnServer: totalOnServer,
      totalSynced: totalSynced,
      totalMissing: totalMissing,
      totalBytesToSync: totalBytesToSync,
      syncPercentage: totalLocal > 0 ? (totalSynced / totalLocal) : 0.0,
    );
  }
}

/// 同步状态摘要
class SyncSummary {
  final int totalLocal;
  final int totalOnServer;
  final int totalSynced;
  final int totalMissing;
  final int totalBytesToSync;
  final double syncPercentage;

  SyncSummary({
    required this.totalLocal,
    required this.totalOnServer,
    required this.totalSynced,
    required this.totalMissing,
    required this.totalBytesToSync,
    required this.syncPercentage,
  });

  @override
  String toString() {
    return 'SyncSummary(local: $totalLocal, server: $totalOnServer, '
        'synced: $totalSynced, missing: $totalMissing, '
        'bytesToSync: $totalBytesToSync, percentage: ${(syncPercentage * 100).toStringAsFixed(1)}%)';
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:photosync_common/models/device.dart';

/// 断点续传服务
/// 将大文件分片上传，支持中断后恢复
class ResumableTransfer {
  final Device _device;
  
  // 存储上传进度（文件路径 -> 已上传的chunk索引）
  final Map<String, Set<int>> _uploadProgress = {};
  
  // 存储每个文件的分片大小
  final Map<String, int> _fileChunkSizes = {};
  
  // 默认分片大小: 1MB
  static const int defaultChunkSize = 1024 * 1024;
  
  ResumableTransfer(this._device);
  
  /// 将文件分片
  Future<List<FileChunk>> splitFile(String filePath, {int chunkSize = defaultChunkSize}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    
    final bytes = await file.readAsBytes();
    final chunks = <FileChunk>[];
    
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunkData = bytes.sublist(i, end);
      
      final chunk = FileChunk(
        index: chunks.length,
        data: chunkData,
        size: chunkData.length,
        hash: _calculateHash(chunkData),
      );
      
      chunks.add(chunk);
    }
    
    _fileChunkSizes[filePath] = chunkSize;
    return chunks;
  }
  
  /// 计算字节数据的哈希
  String _calculateHash(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
  
  /// 计算文件哈希
  Future<String> calculateFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    
    final bytes = await file.readAsBytes();
    return _calculateHash(bytes);
  }
  
  /// 获取上传进度
  Future<double> getUploadProgress(String filePath) async {
    final uploadedChunks = _uploadProgress[filePath];
    if (uploadedChunks == null || uploadedChunks.isEmpty) {
      return 0.0;
    }
    
    // 需要知道总 chunk 数，这里从文件推断
    final file = File(filePath);
    if (!await file.exists()) {
      return 0.0;
    }
    
    final totalSize = await file.length();
    final chunkSize = _fileChunkSizes[filePath] ?? defaultChunkSize;
    final totalChunks = (totalSize / chunkSize).ceil();
    
    if (totalChunks == 0) return 0.0;
    return uploadedChunks.length / totalChunks;
  }
  
  /// 标记 chunk 已上传
  Future<void> markChunkUploaded(String filePath, int chunkIndex) async {
    _uploadProgress.putIfAbsent(filePath, () => <int>{});
    _uploadProgress[filePath]!.add(chunkIndex);
  }
  
  /// 获取未上传的 chunk
  Future<List<MissingChunk>> getMissingChunks(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    
    final bytes = await file.readAsBytes();
    final chunkSize = _fileChunkSizes[filePath] ?? defaultChunkSize;
    final totalChunks = (bytes.length / chunkSize).ceil();
    final uploadedChunks = _uploadProgress[filePath] ?? <int>{};
    
    final missing = <MissingChunk>[];
    
    for (var i = 0; i < totalChunks; i++) {
      if (!uploadedChunks.contains(i)) {
        final start = i * chunkSize;
        final end = (start + chunkSize < bytes.length) 
            ? start + chunkSize 
            : bytes.length;
        final chunkData = bytes.sublist(start, end);
        
        missing.add(MissingChunk(
          index: i,
          size: chunkData.length,
          hash: _calculateHash(chunkData),
        ));
      }
    }
    
    return missing;
  }
  
  /// 合并分片为完整文件
  Future<void> mergeChunks(String chunkDir, int totalChunks, String outputPath) async {
    final output = File(outputPath);
    final sink = output.openWrite();
    
    try {
      for (var i = 0; i < totalChunks; i++) {
        final chunkFile = File(path.join(chunkDir, 'chunk_$i.tmp'));
        if (!await chunkFile.exists()) {
          throw FileSystemException('Chunk file not found', chunkFile.path);
        }
        
        final bytes = await chunkFile.readAsBytes();
        sink.add(bytes);
      }
    } finally {
      await sink.close();
    }
  }
  
  /// 清理上传进度
  void clearProgress(String filePath) {
    _uploadProgress.remove(filePath);
    _fileChunkSizes.remove(filePath);
  }
  
  /// 释放资源
  void dispose() {
    _uploadProgress.clear();
    _fileChunkSizes.clear();
  }
}

/// 文件分片
class FileChunk {
  final int index;
  final Uint8List data;
  final int size;
  final String hash;
  
  FileChunk({
    required this.index,
    required this.data,
    required this.size,
    required this.hash,
  });
  
  @override
  String toString() {
    return 'FileChunk(index: $index, size: $size, hash: ${hash.substring(0, 8)}...)';
  }
}

/// 未上传的分片
class MissingChunk {
  final int index;
  final int size;
  final String hash;
  
  MissingChunk({
    required this.index,
    required this.size,
    required this.hash,
  });
  
  @override
  String toString() {
    return 'MissingChunk(index: $index, size: $size, hash: ${hash.substring(0, 8)}...)';
  }
}

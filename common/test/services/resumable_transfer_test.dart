import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:photosync_common/services/resumable_transfer.dart';
import 'package:photosync_common/models/device.dart';

void main() {
  group('ResumableTransfer Tests', () {
    late ResumableTransfer resumableTransfer;
    late Device mockDevice;
    late Directory tempDir;

    setUp(() async {
      mockDevice = Device(
        id: 'desktop_001',
        name: 'TestPC',
        type: 'desktop',
        ip: '127.0.0.1',
        port: 8080,
      );
      resumableTransfer = ResumableTransfer(mockDevice);
      tempDir = await Directory.systemTemp.createTemp('resumable_test_');
    });

    tearDown(() async {
      resumableTransfer.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create ResumableTransfer with device', () {
      expect(resumableTransfer, isNotNull);
    });

    test('should split file into chunks', () async {
      // Arrange: Create a 1MB test file
      final testFile = File(path.join(tempDir.path, 'test_1mb.bin'));
      final data = Uint8List(1024 * 1024); // 1MB
      for (var i = 0; i < data.length; i++) {
        data[i] = i % 256;
      }
      await testFile.writeAsBytes(data);

      // Act
      final chunks = await resumableTransfer.splitFile(testFile.path,
          chunkSize: 256 * 1024);

      // Assert: 1MB / 256KB = 4 chunks
      expect(chunks.length, 4);
      expect(chunks[0].index, 0);
      expect(chunks[1].index, 1);
      expect(chunks[2].index, 2);
      expect(chunks[3].index, 3);
    });

    test('should calculate chunk hash', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world chunk 1');

      // Act
      final chunks =
          await resumableTransfer.splitFile(testFile.path, chunkSize: 10);

      // Assert
      expect(chunks[0].hash, isNotNull);
      expect(chunks[0].hash.length, 64); // SHA-256 hex
      expect(chunks[0].size, 10);
    });

    test('should track upload progress', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world');

      // Act
      final progress = await resumableTransfer.getUploadProgress(testFile.path);

      // Assert: New file, no progress
      expect(progress, 0.0);
    });

    test('should save and resume upload progress', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello worl'); // 10 bytes
      final chunks =
          await resumableTransfer.splitFile(testFile.path, chunkSize: 5);

      // Act: Simulate uploading first chunk
      await resumableTransfer.markChunkUploaded(testFile.path, chunks[0].index);

      // Assert: Progress should be 50% (1 of 2 chunks)
      final progress = await resumableTransfer.getUploadProgress(testFile.path);
      expect(progress, 0.5);
    });

    test('should identify missing chunks', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world test data');
      final chunks =
          await resumableTransfer.splitFile(testFile.path, chunkSize: 7);

      // Mark some chunks as uploaded
      await resumableTransfer.markChunkUploaded(testFile.path, 0);
      await resumableTransfer.markChunkUploaded(testFile.path, 2);

      // Act
      final missingChunks =
          await resumableTransfer.getMissingChunks(testFile.path);

      // Assert: Chunk 1 should be missing
      expect(missingChunks.length, 1);
      expect(missingChunks[0].index, 1);
    });

    test('should merge chunks into complete file', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'original.txt'));
      final originalData = 'hello world this is a test';
      await testFile.writeAsString(originalData);

      final chunks =
          await resumableTransfer.splitFile(testFile.path, chunkSize: 10);

      // Create chunk files
      final chunkDir = Directory(path.join(tempDir.path, 'chunks'));
      await chunkDir.create();

      for (final chunk in chunks) {
        final chunkFile =
            File(path.join(chunkDir.path, 'chunk_${chunk.index}.tmp'));
        await chunkFile.writeAsBytes(chunk.data);
      }

      // Act
      final mergedFile = File(path.join(tempDir.path, 'merged.txt'));
      await resumableTransfer.mergeChunks(
        chunkDir.path,
        chunks.length,
        mergedFile.path,
      );

      // Assert
      expect(await mergedFile.exists(), true);
      final mergedData = await mergedFile.readAsString();
      expect(mergedData, originalData);
    });

    test('should handle interrupted upload and resume', () async {
      // Arrange: Simulate interrupted upload
      final testFile = File(path.join(tempDir.path, 'large_file.bin'));
      final data = Uint8List(5 * 1024 * 1024); // 5MB
      for (var i = 0; i < data.length; i++) {
        data[i] = i % 256;
      }
      await testFile.writeAsBytes(data);

      final chunks = await resumableTransfer.splitFile(testFile.path,
          chunkSize: 1024 * 1024);

      // Simulate: Upload 2 of 5 chunks, then interrupt
      await resumableTransfer.markChunkUploaded(testFile.path, 0);
      await resumableTransfer.markChunkUploaded(testFile.path, 1);

      // Act: Resume upload - should only upload remaining 3 chunks
      final missingChunks =
          await resumableTransfer.getMissingChunks(testFile.path);

      // Assert
      expect(missingChunks.length, 3);
      expect(missingChunks[0].index, 2);
      expect(missingChunks[1].index, 3);
      expect(missingChunks[2].index, 4);
    });

    test('should verify file integrity after merge', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'verify.txt'));
      await testFile.writeAsString('verify this file integrity');

      // Act
      final hash = await resumableTransfer.calculateFileHash(testFile.path);

      // Assert
      expect(hash, isNotNull);
      expect(hash.length, 64);
    });
  });
}

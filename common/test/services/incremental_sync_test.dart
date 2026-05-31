import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:photosync_common/services/incremental_sync.dart';
import 'package:photosync_common/models/photo.dart';

void main() {
  group('IncrementalSync Tests', () {
    late IncrementalSync incrementalSync;
    late Directory tempDir;

    setUp(() async {
      incrementalSync = IncrementalSync();
      tempDir = await Directory.systemTemp.createTemp('incremental_sync_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should calculate file hash', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world');

      // Act
      final hash = await incrementalSync.calculateHash(testFile.path);

      // Assert
      expect(hash, isNotNull);
      expect(hash.length, 64); // SHA-256 hex string length
      expect(hash, isNotEmpty);
    });

    test('should return same hash for same file', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world');

      // Act
      final hash1 = await incrementalSync.calculateHash(testFile.path);
      final hash2 = await incrementalSync.calculateHash(testFile.path);

      // Assert
      expect(hash1, equals(hash2));
    });

    test('should return different hash for different files', () async {
      // Arrange
      final file1 = File(path.join(tempDir.path, 'test1.txt'));
      final file2 = File(path.join(tempDir.path, 'test2.txt'));
      await file1.writeAsString('hello world');
      await file2.writeAsString('hello world!');

      // Act
      final hash1 = await incrementalSync.calculateHash(file1.path);
      final hash2 = await incrementalSync.calculateHash(file2.path);

      // Assert
      expect(hash1, isNot(equals(hash2)));
    });

    test('should find missing files from server', () async {
      // Arrange
      final localPhotos = [
        Photo(id: '1', filename: 'a.jpg', path: '/a.jpg', size: 100, createdAt: DateTime.now(), modifiedAt: DateTime.now(), hash: 'hash1'),
        Photo(id: '2', filename: 'b.jpg', path: '/b.jpg', size: 200, createdAt: DateTime.now(), modifiedAt: DateTime.now(), hash: 'hash2'),
        Photo(id: '3', filename: 'c.jpg', path: '/c.jpg', size: 300, createdAt: DateTime.now(), modifiedAt: DateTime.now(), hash: 'hash3'),
      ];
      final serverHashes = {'hash1', 'hash2'}; // server has hash1 and hash2

      // Act
      final missing = incrementalSync.findMissingFiles(localPhotos, serverHashes);

      // Assert
      expect(missing.length, 1);
      expect(missing.first.id, '3');
      expect(missing.first.hash, 'hash3');
    });

    test('should return empty when all files exist on server', () async {
      // Arrange
      final localPhotos = [
        Photo(id: '1', filename: 'a.jpg', path: '/a.jpg', size: 100, createdAt: DateTime.now(), modifiedAt: DateTime.now(), hash: 'hash1'),
      ];
      final serverHashes = {'hash1'};

      // Act
      final missing = incrementalSync.findMissingFiles(localPhotos, serverHashes);

      // Assert
      expect(missing, isEmpty);
    });

    test('should handle empty local photos', () async {
      // Act
      final missing = incrementalSync.findMissingFiles([], {});

      // Assert
      expect(missing, isEmpty);
    });

    test('should calculate hash for binary data', () async {
      // Arrange
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      // Act
      final hash = incrementalSync.calculateHashFromBytes(data);

      // Assert
      expect(hash, isNotNull);
      expect(hash.length, 64);
    });

    test('should batch calculate hashes for multiple files', () async {
      // Arrange
      final file1 = File(path.join(tempDir.path, 'file1.txt'));
      final file2 = File(path.join(tempDir.path, 'file2.txt'));
      await file1.writeAsString('content1');
      await file2.writeAsString('content2');

      final photos = [
        Photo(id: '1', filename: 'file1.txt', path: file1.path, size: 8, createdAt: DateTime.now(), modifiedAt: DateTime.now()),
        Photo(id: '2', filename: 'file2.txt', path: file2.path, size: 8, createdAt: DateTime.now(), modifiedAt: DateTime.now()),
      ];

      // Act
      final hashes = await incrementalSync.calculateHashesForPhotos(photos);

      // Assert
      expect(hashes.length, 2);
      expect(hashes['1'], isNotNull);
      expect(hashes['2'], isNotNull);
      expect(hashes['1'], isNot(equals(hashes['2'])));
    });

    test('should update photo with hash', () async {
      // Arrange
      final testFile = File(path.join(tempDir.path, 'test.txt'));
      await testFile.writeAsString('hello world');
      var photo = Photo(id: '1', filename: 'test.txt', path: testFile.path, size: 11, createdAt: DateTime.now(), modifiedAt: DateTime.now());

      // Act
      final updatedPhoto = await incrementalSync.updatePhotoWithHash(photo);

      // Assert
      expect(updatedPhoto.hash, isNotNull);
      expect(updatedPhoto.hash!.length, 64);
    });
  });
}

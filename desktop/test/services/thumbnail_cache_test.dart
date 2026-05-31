import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_desktop/services/thumbnail_cache.dart';

void main() {
  group('ThumbnailCache Tests', () {
    late ThumbnailCache cache;
    late Directory tempDir;

    setUp(() async {
      cache = ThumbnailCache();
      tempDir = await Directory.systemTemp.createTemp('thumbnail_cache_test_');
      await cache.initialize(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should initialize cache directory', () async {
      expect(cache.cacheDir, isNotNull);
      expect(await Directory(cache.cacheDir!).exists(), true);
    });

    test('should store and retrieve thumbnail', () async {
      // Arrange
      final photoId = 'photo_001';
      final thumbnailData =
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      // Act
      await cache.put(photoId, thumbnailData);
      final retrieved = await cache.get(photoId);

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.length, thumbnailData.length);
      expect(retrieved, equals(thumbnailData));
    });

    test('should return null for non-existent thumbnail', () async {
      // Act
      final result = await cache.get('non_existent');

      // Assert
      expect(result, isNull);
    });

    test('should check if thumbnail exists', () async {
      // Arrange
      final photoId = 'photo_002';
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      await cache.put(photoId, data);

      // Act & Assert
      expect(await cache.contains(photoId), true);
      expect(await cache.contains('non_existent'), false);
    });

    test('should remove thumbnail', () async {
      // Arrange
      final photoId = 'photo_003';
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      await cache.put(photoId, data);

      // Act
      await cache.remove(photoId);

      // Assert
      expect(await cache.contains(photoId), false);
      expect(await cache.get(photoId), isNull);
    });

    test('should clear all thumbnails', () async {
      // Arrange
      await cache.put('photo_004', Uint8List.fromList([0x01]));
      await cache.put('photo_005', Uint8List.fromList([0x02]));
      await cache.put('photo_006', Uint8List.fromList([0x03]));

      // Act
      await cache.clear();

      // Assert
      expect(await cache.contains('photo_004'), false);
      expect(await cache.contains('photo_005'), false);
      expect(await cache.contains('photo_006'), false);
    });

    test('should get cache size', () async {
      // Arrange
      await cache.put('photo_007', Uint8List(100));
      await cache.put('photo_008', Uint8List(200));

      // Act
      final size = await cache.getCacheSize();

      // Assert
      expect(size, 300);
    });

    test('should evict oldest when cache exceeds max size', () async {
      // Arrange: Set small max size
      cache = ThumbnailCache(maxCacheSize: 150);
      await cache.initialize(tempDir.path);

      // Act: Add files that exceed cache limit
      await cache.put('photo_009', Uint8List(100));
      await Future.delayed(
          Duration(milliseconds: 10)); // Ensure different timestamps
      await cache.put('photo_010', Uint8List(100));

      // Assert: Oldest should be evicted
      expect(await cache.contains('photo_009'), false);
      expect(await cache.contains('photo_010'), true);
    });

    test('should generate cache key from file path', () {
      // Act
      final key1 = cache.generateKey('/storage/photos/IMG_001.jpg');
      final key2 = cache.generateKey('/storage/photos/IMG_001.jpg');
      final key3 = cache.generateKey('/storage/photos/IMG_002.jpg');

      // Assert
      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('should handle concurrent writes', () async {
      // Arrange
      final photoId = 'photo_011';
      final data1 = Uint8List.fromList([0x01, 0x02]);
      final data2 = Uint8List.fromList([0x03, 0x04]);

      // Act: Write concurrently
      await Future.wait([
        cache.put(photoId, data1),
        cache.put(photoId, data2),
      ]);

      // Assert: Should not crash, data should be one of them
      final result = await cache.get(photoId);
      expect(result, isNotNull);
      expect(result!.length, 2);
    });
  });
}

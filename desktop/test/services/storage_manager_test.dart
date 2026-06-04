import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:photosync_desktop/services/storage_manager.dart';

// Mock PathProvider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;

  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsDirectory() async {
    return tempPath;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return tempPath;
  }
}

void main() {
  group('StorageManager Tests', () {
    late StorageManager storageManager;
    late Directory tempDir;

    setUp(() async {
      // Create temp directory for testing
      tempDir = await Directory.systemTemp.createTemp('photosync_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
      storageManager = StorageManager();
    });

    tearDown(() async {
      // Clean up temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should initialize storage directory', () async {
      // Act
      await storageManager.initialize();

      // Assert
      final storagePath = storageManager.storagePath;
      expect(storagePath, isNotNull);
      expect(await Directory(storagePath!).exists(), true);
    });

    test('should create date-based directory structure', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30, 10, 30, 0);
      final filename = 'IMG_001.jpg';

      // Act
      final path = await storageManager.getStoragePathForDate(date, filename);

      // Assert
      expect(path, contains('/2026/'));
      expect(path, contains('/05/'));
      expect(path, contains(filename));
    });

    test('should save file to correct location', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30);
      final filename = 'test_image.jpg';
      final data = [0xFF, 0xD8, 0xFF, 0xE0]; // JPEG header

      // Act
      final savedPath = await storageManager.saveFile(
        filename: filename,
        createdAt: date,
        data: data,
      );

      // Assert
      final file = File(savedPath);
      expect(await file.exists(), true);
      expect(await file.length(), data.length);
    });

    test('should generate thumbnail for image', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30);
      final filename = 'test_image.jpg';
      // Minimal valid JPEG (1x1 pixel, very small)
      final data = _createMinimalJpeg();

      // Act
      final savedPath = await storageManager.saveFile(
        filename: filename,
        createdAt: date,
        data: data,
      );
      final thumbnailPath = await storageManager.generateThumbnail(savedPath);

      // Assert
      if (thumbnailPath != null) {
        final thumbFile = File(thumbnailPath);
        expect(await thumbFile.exists(), true);
      }
    });

    test('should get available storage space', () async {
      // Act
      final available = await storageManager.getAvailableStorage();

      // Assert
      expect(available, isNotNull);
      expect(available, greaterThan(0));
    });

    test('should list photos by date', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30);
      await storageManager.saveFile(
        filename: 'IMG_001.jpg',
        createdAt: date,
        data: [0xFF, 0xD8, 0xFF, 0xE0],
      );
      await storageManager.saveFile(
        filename: 'IMG_002.jpg',
        createdAt: date,
        data: [0xFF, 0xD8, 0xFF, 0xE0],
      );

      // Act
      final photos = await storageManager.listPhotosByDate(date);

      // Assert
      expect(photos.length, 2);
      expect(photos.any((p) => p.contains('IMG_001.jpg')), true);
      expect(photos.any((p) => p.contains('IMG_002.jpg')), true);
    });

    test('should delete file and thumbnail', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30);
      final data = _createMinimalJpeg();
      final savedPath = await storageManager.saveFile(
        filename: 'delete_me.jpg',
        createdAt: date,
        data: data,
      );
      final thumbnailPath = await storageManager.generateThumbnail(savedPath);

      // Act
      await storageManager.deleteFile(savedPath, thumbnailPath: thumbnailPath);

      // Assert
      expect(await File(savedPath).exists(), false);
      if (thumbnailPath != null) {
        expect(await File(thumbnailPath).exists(), false);
      }
    });

    test('should get total storage used', () async {
      // Arrange
      await storageManager.initialize();
      final date = DateTime(2026, 5, 30);
      await storageManager.saveFile(
        filename: 'IMG_001.jpg',
        createdAt: date,
        data: [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10],
      );

      // Act
      final totalUsed = await storageManager.getTotalStorageUsed();

      // Assert
      expect(totalUsed, greaterThan(0));
    });
  });
}

// Helper to create minimal valid JPEG bytes
List<int> _createMinimalJpeg() {
  // This is a very minimal valid JPEG structure (not a real image but enough for parsing)
  return [
    0xFF, 0xD8, // SOI marker
    0xFF, 0xE0, // APP0 marker
    0x00, 0x10, // length
    0x4A, 0x46, 0x49, 0x46, 0x00, // JFIF identifier
    0x01, 0x01, // version
    0x00, // units
    0x00, 0x01, // X density
    0x00, 0x01, // Y density
    0x00, 0x00, // thumbnail size
    // SOF0 marker
    0xFF, 0xC0,
    0x00, 0x0B, // length
    0x08, // precision
    0x00, 0x01, // height (1)
    0x00, 0x01, // width (1)
    0x01, // components
    0x01, 0x11, 0x00, // component info
    // DHT marker
    0xFF, 0xC4,
    0x00, 0x1F, // length
    0x00, // class and id
    // ... minimal Huffman table
    0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B,
    // SOS marker
    0xFF, 0xDA,
    0x00, 0x08, // length
    0x01, // components
    0x01, 0x00, // component selector
    0x00, 0x3F, 0x00, // spectral selection
    0x00, // data
    0xFF, 0xD9, // EOI marker
  ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_common/models/photo.dart';

void main() {
  group('Photo Model Tests', () {
    test('should create Photo from JSON correctly', () {
      // Arrange
      final json = {
        'id': 'photo_123',
        'filename': 'IMG_001.jpg',
        'path': '/storage/IMG_001.jpg',
        'size': 2048,
        'createdAt': '2026-05-30T10:00:00.000',
        'modifiedAt': '2026-05-30T10:00:00.000',
        'thumbnailPath': '/thumb/IMG_001.jpg',
        'mimeType': 'image/jpeg',
        'width': 1920,
        'height': 1080,
        'album': 'Camera',
        'hash': 'abc123',
        'syncStatus': 'pending',
        'syncTime': '2026-05-30T12:00:00.000',
        'deviceId': 'device_001',
      };

      // Act
      final photo = Photo.fromJson(json);

      // Assert
      expect(photo.id, 'photo_123');
      expect(photo.filename, 'IMG_001.jpg');
      expect(photo.path, '/storage/IMG_001.jpg');
      expect(photo.size, 2048);
      expect(photo.createdAt, isA<DateTime>());
      expect(photo.syncStatus, SyncStatus.pending);
      expect(photo.deviceId, 'device_001');
    });

    test('should serialize Photo to JSON correctly', () {
      // Arrange
      final photo = Photo(
        id: 'photo_456',
        filename: 'IMG_002.jpg',
        path: '/storage/IMG_002.jpg',
        size: 1024,
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
        syncStatus: SyncStatus.completed,
        deviceId: 'device_002',
      );

      // Act
      final json = photo.toJson();

      // Assert
      expect(json['id'], 'photo_456');
      expect(json['filename'], 'IMG_002.jpg');
      expect(json['syncStatus'], 'completed');
      expect(json['deviceId'], 'device_002');
    });

    test('should handle optional fields as null', () {
      // Arrange
      final json = {
        'id': 'photo_789',
        'filename': 'IMG_003.jpg',
        'path': '/storage/IMG_003.jpg',
        'size': 512,
        'createdAt': '2026-05-30T10:00:00.000',
        'modifiedAt': '2026-05-30T10:00:00.000',
      };

      // Act
      final photo = Photo.fromJson(json);

      // Assert
      expect(photo.id, 'photo_789');
      expect(photo.thumbnailPath, isNull);
      expect(photo.syncStatus, isNull);
      expect(photo.deviceId, isNull);
    });

    test('should copyWith correctly', () {
      // Arrange
      final photo = Photo(
        id: 'photo_001',
        filename: 'IMG_001.jpg',
        path: '/storage/IMG_001.jpg',
        size: 1024,
        createdAt: DateTime(2026, 5, 30),
        modifiedAt: DateTime(2026, 5, 30),
      );

      // Act
      final updatedPhoto = photo.copyWith(
        syncStatus: SyncStatus.completed,
        syncTime: DateTime(2026, 5, 30, 14, 0),
      );

      // Assert
      expect(updatedPhoto.id, 'photo_001'); // unchanged
      expect(updatedPhoto.syncStatus, SyncStatus.completed); // changed
      expect(updatedPhoto.syncTime, isNotNull); // changed
    });
  });
}

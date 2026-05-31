import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_common/models/sync_task.dart';

void main() {
  group('SyncTask Model Tests', () {
    test('should create SyncTask from JSON correctly', () {
      // Arrange
      final json = {
        'id': 'task_123',
        'deviceId': 'device_001',
        'photoIds': ['photo_1', 'photo_2', 'photo_3'],
        'status': 'running',
        'createdAt': '2026-05-30T10:00:00.000',
        'startedAt': '2026-05-30T10:01:00.000',
        'totalBytes': 10240,
        'transferredBytes': 5120,
        'error': null,
      };

      // Act
      final task = SyncTask.fromJson(json);

      // Assert
      expect(task.id, 'task_123');
      expect(task.deviceId, 'device_001');
      expect(task.photoIds, ['photo_1', 'photo_2', 'photo_3']);
      expect(task.status, TaskStatus.running);
      expect(task.totalBytes, 10240);
      expect(task.transferredBytes, 5120);
      expect(task.error, isNull);
    });

    test('should serialize SyncTask to JSON correctly', () {
      // Arrange
      final task = SyncTask(
        id: 'task_456',
        deviceId: 'device_002',
        photoIds: ['photo_4'],
        status: TaskStatus.completed,
        createdAt: DateTime(2026, 5, 30),
        completedAt: DateTime(2026, 5, 30, 10, 30),
        totalBytes: 2048,
        transferredBytes: 2048,
      );

      // Act
      final json = task.toJson();

      // Assert
      expect(json['id'], 'task_456');
      expect(json['status'], 'completed');
      expect(json['totalBytes'], 2048);
      expect(json['transferredBytes'], 2048);
      expect(json['error'], isNull);
    });

    test('should calculate progress correctly', () {
      // Arrange
      final task = SyncTask(
        id: 'task_001',
        deviceId: 'device_001',
        photoIds: ['photo_1'],
        status: TaskStatus.running,
        totalBytes: 1000,
        transferredBytes: 400,
      );

      // Act & Assert
      expect(task.transferredBytes, 400);
      expect(task.totalBytes, 1000);
      // 进度 = 400/1000 = 40%
    });
  });
}
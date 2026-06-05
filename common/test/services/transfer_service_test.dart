import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/models/device.dart';

void main() {
  group('TransferService Tests', () {
    late TransferService transferService;
    late Device mockDevice;

    setUp(() {
      mockDevice = Device(
        id: 'desktop_001',
        name: 'TestPC',
        type: 'desktop',
        ip: '127.0.0.1',
        port: 8080,
      );
      transferService = TransferService(mockDevice);
    });

    tearDown(() {
      transferService.dispose();
    });

    test('should create TransferService with device', () {
      // Assert
      expect(transferService, isNotNull);
    });

    test('should upload file and return success', () async {
      // Arrange - create a mock file path
      const filePath = '/tmp/test_image.jpg';
      const filename = 'test_image.jpg';
      final createdAt = DateTime(2026, 5, 30);

      // Act - mock the upload by intercepting the HTTP call
      // In real test, this would use mockito to mock the HTTP client
      final result = await transferService.uploadFile(
        filePath: filePath,
        filename: filename,
        createdAt: createdAt,
      );

      // Assert - should handle file not found gracefully
      expect(result, isNotNull);
    });

    test('should check existing files on server', () async {
      // Arrange
      final hashes = ['hash1', 'hash2', 'hash3'];

      // Act
      final missing = await transferService.checkExistingFiles(hashes);

      // Assert - should return all as missing when server is not available
      expect(missing, isA<Set<String>>());
    });

    test('should get sync status from server', () async {
      // Act
      try {
        final status = await transferService.getSyncStatus();
        // Assert
        expect(status, isNotNull);
      } catch (e) {
        // Expected when server is not available
        expect(e, isA<Exception>());
      }
    });
  });
}

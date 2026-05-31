import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_common/models/device.dart';

void main() {
  group('Device Model Tests', () {
    test('should create Device from JSON correctly', () {
      // Arrange
      final json = {
        'id': 'device_123',
        'name': 'TestPhone',
        'type': 'mobile',
        'ip': '192.168.1.100',
        'port': 8080,
        'lastSeen': '2026-05-30T10:00:00.000',
        'storageAvailable': 1000000000,
        'version': '1.0.0',
      };

      // Act
      final device = Device.fromJson(json);

      // Assert
      expect(device.id, 'device_123');
      expect(device.name, 'TestPhone');
      expect(device.type, 'mobile');
      expect(device.ip, '192.168.1.100');
      expect(device.port, 8080);
      expect(device.lastSeen, isNotNull);
      expect(device.storageAvailable, 1000000000);
      expect(device.version, '1.0.0');
    });

    test('should serialize Device to JSON correctly', () {
      // Arrange
      final device = Device(
        id: 'device_456',
        name: 'HomePC',
        type: 'desktop',
        ip: '192.168.1.200',
        port: 9090,
        lastSeen: DateTime(2026, 5, 30, 15, 30),
        storageAvailable: 5000000000,
        version: '1.0.0',
      );

      // Act
      final json = device.toJson();

      // Assert
      expect(json['id'], 'device_456');
      expect(json['name'], 'HomePC');
      expect(json['type'], 'desktop');
      expect(json['ip'], '192.168.1.200');
      expect(json['port'], 9090);
      expect(json['lastSeen'], isNotNull);
      expect(json['storageAvailable'], 5000000000);
      expect(json['version'], '1.0.0');
    });

    test('should handle optional fields', () {
      // Arrange
      final json = {
        'id': 'device_789',
        'name': 'MinimalDevice',
        'type': 'mobile',
        'ip': '192.168.1.50',
        'port': 7000,
      };

      // Act
      final device = Device.fromJson(json);

      // Assert
      expect(device.id, 'device_789');
      expect(device.lastSeen, isNull);
      expect(device.storageAvailable, isNull);
      expect(device.version, isNull);
    });

    test('should copyWith correctly', () {
      // Arrange
      final device = Device(
        id: 'device_001',
        name: 'Phone',
        type: 'mobile',
        ip: '192.168.1.10',
        port: 8080,
      );

      // Act
      final updatedDevice = device.copyWith(
        name: 'UpdatedPhone',
        port: 9090,
      );

      // Assert
      expect(updatedDevice.id, 'device_001'); // unchanged
      expect(updatedDevice.name, 'UpdatedPhone'); // changed
      expect(updatedDevice.port, 9090); // changed
      expect(updatedDevice.ip, '192.168.1.10'); // unchanged
    });
  });
}

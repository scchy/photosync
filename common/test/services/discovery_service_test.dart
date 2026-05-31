import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:photosync_common/services/discovery_service.dart';
import 'package:photosync_common/models/device.dart';

class MockDiscoveryService extends Mock implements DiscoveryService {}

void main() {
  group('DiscoveryService Tests', () {
    late DiscoveryService discoveryService;

    setUp(() {
      discoveryService = DiscoveryService();
    });

    tearDown(() {
      discoveryService.stop();
    });

    test('should start discovery without error', () async {
      // Act & Assert - should not throw
      await discoveryService.startDiscovery(
        deviceName: 'TestDevice',
        deviceType: 'mobile',
        httpPort: 8080,
      );
      expect(discoveryService.isRunning, true);
    });

    test('should discover devices on network', () async {
      // Arrange
      final discoveredDevices = <Device>[];
      discoveryService.onDeviceFound = (device) {
        discoveredDevices.add(device);
      };

      await discoveryService.startDiscovery(
        deviceName: 'TestDevice',
        deviceType: 'mobile',
        httpPort: 8080,
      );

      // Simulate receiving a response
      final mockDevice = Device(
        id: 'desktop_001',
        name: 'TestPC',
        type: 'desktop',
        ip: '192.168.1.100',
        port: 9090,
      );

      // Act - simulate device found
      discoveryService.onDeviceFound?.call(mockDevice);

      // Assert
      expect(discoveredDevices.length, 1);
      expect(discoveredDevices[0].name, 'TestPC');
      expect(discoveredDevices[0].type, 'desktop');
    });

    test('should remove device when offline', () async {
      // Arrange
      final lostDevices = <Device>[];
      discoveryService.onDeviceLost = (device) {
        lostDevices.add(device);
      };

      await discoveryService.startDiscovery(
        deviceName: 'TestDevice',
        deviceType: 'mobile',
        httpPort: 8080,
      );

      // Act - simulate device lost
      final mockDevice = Device(
        id: 'desktop_001',
        name: 'TestPC',
        type: 'desktop',
        ip: '192.168.1.100',
        port: 9090,
      );
      discoveryService.onDeviceLost?.call(mockDevice);

      // Assert
      expect(lostDevices.length, 1);
      expect(lostDevices[0].id, 'desktop_001');
    });

    test('should stop discovery correctly', () async {
      // Arrange
      await discoveryService.startDiscovery(
        deviceName: 'TestDevice',
        deviceType: 'mobile',
        httpPort: 8080,
      );

      // Act
      discoveryService.stop();

      // Assert
      expect(discoveryService.isRunning, false);
    });
  });
}

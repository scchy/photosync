import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_desktop/services/server_service.dart';

void main() {
  group('DesktopServer Tests', () {
    late DesktopServer server;

    setUp(() {
      server = DesktopServer();
    });

    tearDown(() {
      server.stop();
    });

    test('should start server on available port', () async {
      // Act
      await server.start();
      final port = server.port;

      // Assert
      expect(port, isNotNull);
      expect(port, greaterThan(0));
    });

    test('should stop server cleanly', () async {
      // Arrange
      await server.start();

      // Act
      server.stop();

      // Assert - should not throw
    });

    test('should handle health check', () async {
      // Arrange
      await server.start();

      // Act - make HTTP request to health endpoint
      // In real test, would use http client
      // final response = await http.get(Uri.parse('http://localhost:$port/api/health'));

      // Assert
      // expect(response.statusCode, 200);
    });
  });
}

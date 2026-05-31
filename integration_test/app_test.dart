import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:photosync/main.dart' as mobile_app;
import 'package:photosync_desktop/main.dart' as desktop_app;
import 'package:photosync_common/services/discovery_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_common/models/photo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Photo Sync Tests', () {
    testWidgets('should discover desktop from mobile', (WidgetTester tester) async {
      // Arrange: Start desktop server
      final desktopServer = desktop_app.DesktopServer();
      await desktopServer.start();

      // Act: Launch mobile app and start discovery
      await tester.pumpWidget(mobile_app.PhotoSyncApp());
      await tester.pumpAndSettle();

      // Navigate to devices screen
      await tester.tap(find.byIcon(Icons.devices_outlined));
      await tester.pumpAndSettle();

      // Wait for discovery
      await tester.pump(const Duration(seconds: 5));

      // Assert: Desktop device should be found
      expect(find.text('HomePC'), findsOneWidget);
      expect(find.text('192.168.1.x'), findsOneWidget);

      // Cleanup
      desktopServer.stop();
    });

    testWidgets('should sync photo from mobile to desktop', (WidgetTester tester) async {
      // Arrange: Start both apps
      final desktopServer = desktop_app.DesktopServer();
      await desktopServer.start();

      await tester.pumpWidget(mobile_app.PhotoSyncApp());
      await tester.pumpAndSettle();

      // Navigate to gallery and select a photo
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.tap(find.byIcon(Icons.select_all_rounded));
      await tester.pumpAndSettle();

      // Select first photo
      await tester.tap(find.byType(PhotoGridItem).first);
      await tester.pumpAndSettle();

      // Tap sync button
      await tester.tap(find.byIcon(Icons.cloud_upload_rounded));
      await tester.pumpAndSettle();

      // Wait for sync to complete
      await tester.pump(const Duration(seconds: 10));

      // Assert: Should show completion
      expect(find.text('同步完成！'), findsOneWidget);

      // Cleanup
      desktopServer.stop();
    });

    testWidgets('should display synced photos on desktop', (WidgetTester tester) async {
      // Arrange: Start desktop with some photos
      final desktopServer = desktop_app.DesktopServer();
      await desktopServer.start();

      // Add a mock photo to storage
      final storagePath = desktopServer.storagePath;
      // ... setup mock photo

      await tester.pumpWidget(desktop_app.PhotoSyncDesktopApp(server: desktopServer));
      await tester.pumpAndSettle();

      // Assert: Photo should be displayed
      expect(find.byType(Image), findsWidgets);

      // Cleanup
      desktopServer.stop();
    });

    testWidgets('should auto-sync when reconnected to WiFi', (WidgetTester tester) async {
      // Arrange: Enable auto-sync
      await tester.pumpWidget(mobile_app.PhotoSyncApp());
      await tester.pumpAndSettle();

      // Navigate to settings and enable auto-sync
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Simulate WiFi connection change
      // ... simulate connectivity change

      // Assert: Auto-sync should trigger
      // ... verify sync was triggered
    });
  });
}

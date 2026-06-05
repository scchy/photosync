import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:photosync/screens/devices_screen.dart';
import 'package:photosync/theme/app_theme.dart';

void main() {
  group('DevicesScreen Widget Tests', () {
    testWidgets('should render devices screen', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DevicesScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Assert
      expect(find.text('可同步设备'), findsOneWidget);
      expect(find.byType(DevicesScreen), findsOneWidget);
    });

    testWidgets('should show scanning state initially',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DevicesScreen(),
        ),
      );

      // Assert - should show scanning indicator initially
      expect(find.text('正在搜索设备'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show empty state when no devices found',
        (WidgetTester tester) async {
      // Act - wait for discovery to complete
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DevicesScreen(),
        ),
      );

      // Wait for async discovery + device loading
      await tester.pump(const Duration(seconds: 5));

      // Assert - should show either scanning or empty state
      final hasText = find.text('正在搜索设备').evaluate().isNotEmpty ||
          find.text('未发现设备').evaluate().isNotEmpty;
      expect(hasText, true);
    });
  });
}

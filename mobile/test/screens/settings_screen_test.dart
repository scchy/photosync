import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:photosync/screens/settings_screen.dart';
import 'package:photosync/theme/app_theme.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    testWidgets('should render settings screen', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('设置'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('should show auto sync toggle', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - should find the auto sync toggle
      expect(find.text('自动同步'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('should show sync quality selector', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(onLogout: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - should find the sync quality option
      expect(find.text('同步质量'), findsOneWidget);
      expect(find.text('原图'), findsOneWidget);
    });
  });
}
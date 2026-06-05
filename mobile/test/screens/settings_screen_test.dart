import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photosync/screens/settings_screen.dart';
import 'package:photosync/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('should render settings screen', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(onLogout: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

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
      await tester.pump(const Duration(seconds: 3));

      // Assert - should find the auto sync toggle
      expect(find.text('自动同步'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('should show sync quality selector',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SettingsScreen(onLogout: () {}),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      // Assert - should find the sync quality option
      expect(find.text('同步质量'), findsOneWidget);
      expect(find.text('原图'), findsOneWidget);
    });
  });
}

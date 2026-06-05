import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:photosync/screens/gallery_screen.dart';
import 'package:photosync/theme/app_theme.dart';

void main() {
  group('GalleryScreen Widget Tests', () {
    testWidgets('should render gallery screen', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GalleryScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Assert
      expect(find.text('相册同步'), findsOneWidget);
      expect(find.byType(GalleryScreen), findsOneWidget);
    });

    testWidgets('should show loading state initially',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GalleryScreen(),
        ),
      );

      // Assert - should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should have selection mode button',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GalleryScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Assert - should find the select button
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    });
  });
}

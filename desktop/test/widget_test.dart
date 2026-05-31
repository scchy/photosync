import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photosync_desktop/services/server_service.dart';

import 'package:photosync_desktop/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    final server = DesktopServer();
    await server.start();

    await tester.pumpWidget(
      PhotoSyncDesktopApp(
        server: server,
        initialLoggedIn: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    server.stop();
  });
}

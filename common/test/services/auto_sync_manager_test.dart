import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:photosync_common/services/auto_sync_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return 'wifi';
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, null);
  });

  group('AutoSyncManager Tests', () {
    late AutoSyncManager autoSyncManager;

    setUp(() {
      autoSyncManager = AutoSyncManager(
        onSyncTrigger: () {},
        onDeviceFound: () {},
      );
    });

    tearDown(() {
      autoSyncManager.dispose();
    });

    test('should initialize with default settings', () {
      expect(autoSyncManager.isEnabled, false);
      expect(autoSyncManager.syncOnWifiOnly, true);
    });

    test('should enable auto sync', () {
      autoSyncManager.setEnabled(true);
      expect(autoSyncManager.isEnabled, true);
    });

    test('should disable auto sync', () {
      autoSyncManager.setEnabled(true);
      autoSyncManager.setEnabled(false);
      expect(autoSyncManager.isEnabled, false);
    });

    test('should check if WiFi is connected', () async {
      final result = await autoSyncManager.checkConnectivity();
      expect(result, isNotNull);
    });

    test('should detect network change', () async {
      var networkChanged = false;
      autoSyncManager = AutoSyncManager(
        onSyncTrigger: () {},
        onDeviceFound: () {
          networkChanged = true;
        },
      );

      // Simulate network change
      await autoSyncManager.simulateNetworkChange(ConnectivityResult.wifi);

      expect(networkChanged, true);
    });

    test('should trigger sync when WiFi connected and auto sync enabled',
        () async {
      var syncTriggered = false;
      autoSyncManager = AutoSyncManager(
        onSyncTrigger: () {
          syncTriggered = true;
        },
        onDeviceFound: () {},
      );

      autoSyncManager.setEnabled(true);
      await autoSyncManager.simulateNetworkChange(ConnectivityResult.wifi);

      expect(syncTriggered, true);
    });

    test('should not trigger sync when auto sync disabled', () async {
      var syncTriggered = false;
      autoSyncManager = AutoSyncManager(
        onSyncTrigger: () {
          syncTriggered = true;
        },
        onDeviceFound: () {},
      );

      // auto sync is disabled by default
      await autoSyncManager.simulateNetworkChange(ConnectivityResult.wifi);

      expect(syncTriggered, false);
    });

    test('should not trigger sync on mobile data when wifiOnly is true',
        () async {
      var syncTriggered = false;
      autoSyncManager = AutoSyncManager(
        onSyncTrigger: () {
          syncTriggered = true;
        },
        onDeviceFound: () {},
      );

      autoSyncManager.setEnabled(true);
      autoSyncManager.setSyncOnWifiOnly(true);
      await autoSyncManager.simulateNetworkChange(ConnectivityResult.mobile);

      expect(syncTriggered, false);
    });

    test('should set sync interval', () {
      autoSyncManager.setSyncInterval(Duration(minutes: 30));
      expect(autoSyncManager.syncInterval, equals(Duration(minutes: 30)));
    });

    test('should add and remove sync listener', () {
      void listener() {}

      autoSyncManager.addSyncListener(listener);
      expect(autoSyncManager.hasListeners, true);

      autoSyncManager.removeSyncListener(listener);
      expect(autoSyncManager.hasListeners, false);
    });
  });
}

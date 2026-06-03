import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/auto_sync_manager.dart';
import 'package:photosync_common/services/settings_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photo_manager/photo_manager.dart';
import 'services/sync_service.dart';
import 'services/sync_log_service.dart';
import 'screens/auth_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

/// 全局同步完成通知流，用于跨页面刷新
final StreamController<void> syncCompleteController = StreamController<void>.broadcast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();

  runApp(PhotoSyncApp(initialLoggedIn: isLoggedIn));
}

class PhotoSyncApp extends StatefulWidget {
  final bool initialLoggedIn;

  const PhotoSyncApp({Key? key, required this.initialLoggedIn})
      : super(key: key);

  @override
  State<PhotoSyncApp> createState() => _PhotoSyncAppState();
}

class _PhotoSyncAppState extends State<PhotoSyncApp> {
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialLoggedIn;
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  void _handleLogout() {
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isLoggedIn
          ? MainScreen(onLogout: _handleLogout)
          : AuthScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late AutoSyncManager _autoSyncManager;

  @override
  void initState() {
    super.initState();
    _initAutoSync();
  }

  Future<void> _initAutoSync() async {
    final settings = SettingsService();
    await settings.load();

    _autoSyncManager = AutoSyncManager(
      onSyncTrigger: () => _performAutoSync(),
      onDeviceFound: () => _attemptReconnectSavedDevices(),
    );
    _autoSyncManager.setSyncOnWifiOnly(settings.syncOnWifiOnly);
    _autoSyncManager.setEnabled(settings.autoSync);

    // 应用启动时立即检查一次网络状态并尝试同步
    // 因为 onConnectivityChanged 只在网络状态变化时触发
    if (settings.autoSync) {
      _checkAndTriggerAutoSyncOnLaunch();
    }
  }

  /// 应用启动时主动检查网络并触发同步
  Future<void> _checkAndTriggerAutoSyncOnLaunch() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final isWifi = result == ConnectivityResult.wifi;
      final isMobile = result == ConnectivityResult.mobile;
      final settings = SettingsService();
      await settings.load();

      final shouldSync =
          settings.syncOnWifiOnly ? isWifi : (isWifi || isMobile);

      print(
          'AutoSync: launch check - connectivity=$result, shouldSync=$shouldSync');

      if (shouldSync) {
        // 延迟几秒等待 UI 初始化完成
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _performAutoSync();
        }
      }
    } catch (e) {
      print('AutoSync: launch check failed: $e');
    }
  }

  /// 当WiFi连接时，尝试重连保存的设备
  Future<void> _attemptReconnectSavedDevices() async {
    try {
      final deviceStorage = DeviceStorageService();
      final savedDevices = await deviceStorage.getSavedDevices();
      if (savedDevices.isEmpty) return;

      print(
          'WiFi connected, attempting to reconnect ${savedDevices.length} saved devices');

      for (final device in savedDevices) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 5);
          final req = await client.get(device.ip, device.port, '/api/health');
          final resp = await req.close();
          client.close();

          if (resp.statusCode == 200) {
            print(
                'AutoReconnect: device ${device.name} at ${device.ip}:${device.port} is online');
            // 设备在线，通知桌面端
            final notifyClient = HttpClient();
            notifyClient.connectionTimeout = const Duration(seconds: 5);
            final authService = AuthService();
            final user = await authService.loadUser();
            final myDevice = Device(
              id: user?.id ?? 'mobile_${DateTime.now().millisecondsSinceEpoch}',
              name: '手机端 (${user?.username ?? '用户'})',
              type: 'mobile',
              ip: '',
              port: 0,
            );
            final request = await notifyClient.post(
                device.ip, device.port, '/api/device/connect');
            request.headers.contentType = ContentType.json;
            request.write(jsonEncode(myDevice.toJson()));
            await request.close();
            notifyClient.close();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已自动连接到 ${device.name}')),
              );
            }

            // 只连接第一个可用的设备
            break;
          }
        } catch (e) {
          print('AutoReconnect: device ${device.name} unreachable: $e');
        }
      }
    } catch (e) {
      print('AutoReconnect failed: $e');
    }
  }

  /// 执行自动同步
  Future<void> _performAutoSync() async {
    final logService = SyncLogService();
    int syncCount = 0;
    String deviceName = '桌面端';
    String? deviceIp;
    bool hasError = false;

    try {
      final settings = SettingsService();
      await settings.load();

      // 1. 获取保存的设备
      final deviceStorage = DeviceStorageService();
      final savedDevices = await deviceStorage.getSavedDevices();
      if (savedDevices.isEmpty) {
        print('AutoSync: no saved device');
        await logService.addLog(
          photoCount: 0,
          deviceName: '无设备',
          message: '没有保存的设备',
        );
        _notifySyncComplete();
        return;
      }
      final device = savedDevices.last;
      deviceName = device.name;
      deviceIp = '${device.ip}:${device.port}';

      // 2. 检查设备是否在线
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.get(device.ip, device.port, '/api/health');
        final resp = await req.close();
        if (resp.statusCode != 200) {
          client.close();
          print('AutoSync: device offline');
          await logService.addLog(
            photoCount: 0,
            deviceName: deviceName,
            deviceIp: deviceIp,
            success: false,
            message: '设备离线',
          );
          _notifySyncComplete();
          return;
        }
      } catch (e) {
        client.close();
        print('AutoSync: device unreachable: $e');
        await logService.addLog(
          photoCount: 0,
          deviceName: deviceName,
          deviceIp: deviceIp,
          success: false,
          message: '设备不可达: $e',
        );
        _notifySyncComplete();
        return;
      }
      client.close();

      // 3. 获取待同步照片
      final syncService = SyncService(syncTodayOnly: settings.syncTodayOnly);
      final photos = await syncService.getPhotosToSync();
      if (photos.isEmpty) {
        print('AutoSync: no photos to sync');
        await logService.addLog(
          photoCount: 0,
          deviceName: deviceName,
          deviceIp: deviceIp,
          message: '没有待同步的照片',
        );
        _notifySyncComplete();
        return;
      }

      print('AutoSync: found ${photos.length} photos to sync');

      // 4. 计算 hash 并检查重复
      final hashes = <String>[];
      final hashToPhoto = <String, AssetEntity>{};
      for (final photo in photos) {
        try {
          final file = await photo.originFile;
          if (file == null) continue;
          final bytes = await file.readAsBytes();
          final hash = sha256.convert(bytes).toString();
          hashes.add(hash);
          hashToPhoto[hash] = photo;
        } catch (e) {
          print('AutoSync: hash error: $e');
        }
      }

      if (hashes.isEmpty) {
        await logService.addLog(
          photoCount: 0,
          deviceName: deviceName,
          deviceIp: deviceIp,
          message: '无法计算照片哈希',
        );
        _notifySyncComplete();
        return;
      }

      final transferService = TransferService(device);
      final missingHashes = await transferService.checkExistingFiles(hashes);

      final photosToSync = missingHashes
          .where((h) => hashToPhoto.containsKey(h))
          .map((h) => hashToPhoto[h]!)
          .toList();

      if (photosToSync.isEmpty) {
        transferService.dispose();
        print('AutoSync: all photos already synced');
        await logService.addLog(
          photoCount: 0,
          deviceName: deviceName,
          deviceIp: deviceIp,
          message: '所有照片已同步',
        );
        _notifySyncComplete();
        return;
      }

      print('AutoSync: uploading ${photosToSync.length} photos');

      // 5. 上传照片
      final authService = AuthService();
      final user = await authService.loadUser();

      int successCount = 0;
      for (final photo in photosToSync) {
        try {
          final file = await photo.originFile;
          if (file == null) continue;

          final result = await transferService.uploadFile(
            filePath: file.path,
            filename: photo.title ?? 'photo.jpg',
            createdAt: photo.createDateTime,
            album: photo.relativePath,
            userId: user?.username ?? user?.id,
          );

          if (result.success) successCount++;
        } catch (e) {
          print('AutoSync: upload error: $e');
          hasError = true;
        }
      }

      transferService.dispose();
      syncCount = successCount;

      print(
          'AutoSync: completed, $successCount/${photosToSync.length} uploaded');

      await logService.addLog(
        photoCount: successCount,
        deviceName: deviceName,
        deviceIp: deviceIp,
        success: !hasError,
        message: hasError ? '部分照片上传失败' : null,
      );

      // 显示通知
      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自动同步完成: $successCount 张照片已上传')),
        );
      }
    } catch (e) {
      print('AutoSync: failed: $e');
      hasError = true;
      await logService.addLog(
        photoCount: syncCount,
        deviceName: deviceName,
        deviceIp: deviceIp,
        success: false,
        message: '同步异常: $e',
      );
    } finally {
      _notifySyncComplete();
    }
  }

  /// 通知所有监听页面同步已完成
  void _notifySyncComplete() {
    if (!syncCompleteController.isClosed) {
      syncCompleteController.add(null);
    }
  }

  @override
  void dispose() {
    _autoSyncManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const GalleryScreen(),
      const DevicesScreen(),
      SettingsScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined), label: '相册'),
          BottomNavigationBarItem(
              icon: Icon(Icons.devices_outlined), label: '设备'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
    );
  }
}

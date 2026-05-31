import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_desktop/services/server_service.dart';
import 'package:photosync_common/services/discovery_service.dart';
import 'package:photosync_desktop/theme/app_theme.dart';

import 'screens/auth_screen.dart';
import 'screens/photo_browser_screen.dart';
import 'screens/device_manager_screen.dart';
import 'screens/sync_log_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动桌面端服务器
  final server = DesktopServer();
  await server.start();

  // 检查登录状态
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();

  runApp(PhotoSyncDesktopApp(
    server: server,
    initialLoggedIn: isLoggedIn,
  ));
}

class PhotoSyncDesktopApp extends StatefulWidget {
  final DesktopServer server;
  final bool initialLoggedIn;

  const PhotoSyncDesktopApp({
    Key? key,
    required this.server,
    required this.initialLoggedIn,
  }) : super(key: key);

  @override
  State<PhotoSyncDesktopApp> createState() => _PhotoSyncDesktopAppState();
}

class _PhotoSyncDesktopAppState extends State<PhotoSyncDesktopApp> {
  late bool _isLoggedIn;
  int _currentIndex = 0;
  late final DiscoveryService _discoveryService;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialLoggedIn;

    _discoveryService = DiscoveryService();

    _discoveryService.startDiscovery(
      deviceName: 'HomePC',
      deviceType: 'desktop',
      httpPort: widget.server.port,
    );

    _screens.addAll([
      PhotoBrowserScreen(desktopServer: widget.server),
      DeviceManagerScreen(
        desktopServer: widget.server,
      ),
      SyncLogScreen(desktopServer: widget.server),
      SettingsScreen(onLogout: _handleLogout),
    ]);
  }

  @override
  void dispose() {
    _discoveryService.stop();
    widget.server.stop();
    super.dispose();
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSync Desktop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: _isLoggedIn ? _buildMainScaffold() : AuthScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: Text('照片'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices),
                label: Text('设备'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sync_outlined),
                selectedIcon: Icon(Icons.sync),
                label: Text('同步'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 主内容区
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}

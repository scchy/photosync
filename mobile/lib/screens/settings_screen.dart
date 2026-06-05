import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/settings_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/models/device.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const SettingsScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _authService = AuthService();
  final _deviceStorage = DeviceStorageService();
  bool _isLoading = true;

  bool _autoSync = false;
  bool _syncOnWifi = true;
  bool _syncOnlyNew = true;
  bool _syncTodayOnly = false;
  String _syncQuality = '原图';
  String? _username;
  List<Device> _savedDevices = [];
  String _version = '1.0.0';

  final List<String> _qualityOptions = ['原图', '高质量', '中等质量'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _settingsService.load();
    final user = await _authService.loadUser();
    final devices = await _deviceStorage.getSavedDevices();
    // 读取应用版本号
    String version = '1.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform()
          .timeout(const Duration(seconds: 2));
      version = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      print('读取版本号失败: $e');
    }

    setState(() {
      _autoSync = _settingsService.autoSync;
      _syncOnWifi = _settingsService.syncOnWifiOnly;
      _syncOnlyNew = _settingsService.syncOnlyNew;
      _syncTodayOnly = _settingsService.syncTodayOnly;
      _syncQuality = _settingsService.syncQuality;
      _username = user?.username;
      _savedDevices = devices;
      _version = version;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              title: '账户',
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                    child: Icon(Icons.person,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  title: Text(_username ?? '未知用户'),
                  subtitle: const Text('当前登录用户'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    ),
                    child:
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                  ),
                  title: const Text('退出登录'),
                  textColor: Colors.red,
                  onTap: _logout,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              title: '同步设置',
              children: [
                _buildSwitchTile(
                  title: '自动同步',
                  subtitle: '连接到WiFi时自动同步新照片',
                  icon: Icons.sync_rounded,
                  value: _autoSync,
                  onChanged: (value) async {
                    await _settingsService.setAutoSync(value);
                    setState(() => _autoSync = value);
                  },
                ),
                _buildSwitchTile(
                  title: '仅WiFi同步',
                  subtitle: '仅在WiFi网络下同步',
                  icon: Icons.wifi_rounded,
                  value: _syncOnWifi,
                  onChanged: (value) async {
                    await _settingsService.setSyncOnWifiOnly(value);
                    setState(() => _syncOnWifi = value);
                  },
                ),
                _buildSwitchTile(
                  title: '仅同步新照片',
                  subtitle: '跳过已同步的照片',
                  icon: Icons.photo_library_rounded,
                  value: _syncOnlyNew,
                  onChanged: (value) async {
                    await _settingsService.setSyncOnlyNew(value);
                    setState(() => _syncOnlyNew = value);
                  },
                ),
                _buildSwitchTile(
                  title: '仅同步当天照片',
                  subtitle: '只同步今天拍摄的照片',
                  icon: Icons.today_rounded,
                  value: _syncTodayOnly,
                  onChanged: (value) async {
                    await _settingsService.setSyncTodayOnly(value);
                    setState(() => _syncTodayOnly = value);
                  },
                ),
                _buildSelectTile(
                  title: '同步质量',
                  subtitle: _syncQuality,
                  icon: Icons.high_quality_rounded,
                  options: _qualityOptions,
                  onSelected: (value) async {
                    await _settingsService.setSyncQuality(value);
                    setState(() => _syncQuality = value);
                  },
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              title: '已保存设备',
              children: _savedDevices.isEmpty
                  ? [
                      const ListTile(
                        leading: Icon(Icons.devices_other,
                            color: AppTheme.textLightColor),
                        title: Text('暂无保存的设备'),
                        subtitle: Text('在"可同步设备"页面添加桌面端设备'),
                      ),
                    ]
                  : [
                      ..._savedDevices
                          .map((device) => _buildDeviceTile(device)),
                    ],
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              title: '关于',
              children: [
                _buildInfoTile(
                  title: '版本',
                  subtitle: _version,
                  icon: Icons.info_outline_rounded,
                ),
                _buildActionTile(
                  title: '隐私政策',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                _buildActionTile(
                  title: '使用帮助',
                  icon: Icons.help_outline_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppTheme.spacingMD,
        left: AppTheme.spacingMD,
        right: AppTheme.spacingMD,
        bottom: AppTheme.spacingMD,
      ),
      child: Text(
        '设置',
        style: Theme.of(context).textTheme.displaySmall,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingMD,
            right: AppTheme.spacingMD,
            top: AppTheme.spacingMD,
            bottom: AppTheme.spacingSM,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildSelectTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSelectDialog(title, options, onSelected),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child: Icon(icon, color: AppTheme.textSecondaryColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child: Icon(icon, color: AppTheme.textSecondaryColor, size: 20),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textLightColor),
      onTap: onTap,
    );
  }

  Widget _buildDeviceTile(Device device) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child:
            const Icon(Icons.computer, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(device.name),
      subtitle: Text('${device.ip}:${device.port}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit,
                size: 20, color: AppTheme.textSecondaryColor),
            onPressed: () => _showEditDeviceDialog(device),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => _confirmDeleteDevice(device),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDeviceDialog(Device device) async {
    final ipController = TextEditingController(text: device.ip);
    final portController = TextEditingController(text: device.port.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '8080',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );

    if (result == true) {
      final newIp = ipController.text.trim();
      final newPort = int.tryParse(portController.text.trim()) ?? device.port;
      if (newIp.isNotEmpty) {
        await _deviceStorage.updateDeviceIpPort(device.id, newIp, newPort);
        final devices = await _deviceStorage.getSavedDevices();
        setState(() => _savedDevices = devices);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备信息已更新')),
        );
      }
    }
  }

  Future<void> _confirmDeleteDevice(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除设备 "${device.name}" 吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deviceStorage.removeDevice(device.id);
      final devices = await _deviceStorage.getSavedDevices();
      setState(() => _savedDevices = devices);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备已删除')),
      );
    }
  }

  void _showSelectDialog(
    String title,
    List<String> options,
    Function(String) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.largeRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ...options.map((option) => ListTile(
                  title: Text(option),
                  trailing: option == _syncQuality
                      ? const Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

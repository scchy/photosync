import 'package:flutter/material.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/settings_service.dart';
import 'package:photosync_desktop/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const SettingsScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _autoSync = false;
  bool _syncOnWifi = true;
  bool _syncOnlyNew = true;
  bool _syncTodayOnly = false;
  String _syncQuality = '原图';
  String? _username;

  final List<String> _qualityOptions = ['原图', '高质量', '中等质量'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _settingsService.load();
    final user = await _authService.loadUser();
    setState(() {
      _autoSync = _settingsService.autoSync;
      _syncOnWifi = _settingsService.syncOnWifiOnly;
      _syncOnlyNew = _settingsService.syncOnlyNew;
      _syncTodayOnly = _settingsService.syncTodayOnly;
      _syncQuality = _settingsService.syncQuality;
      _username = user?.username;
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
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          _buildSection(
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
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: const Text('退出登录'),
                textColor: Colors.red,
                onTap: _logout,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildSection(
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
          const SizedBox(height: AppTheme.spacingMD),
          _buildSection(
            title: '关于',
            children: [
              _buildInfoTile(
                title: '版本',
                subtitle: '1.0.0',
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
        ],
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
            left: AppTheme.spacingSM,
            bottom: AppTheme.spacingSM,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ),
        Container(
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
    required ValueChanged<bool> onChanged,
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
    required ValueChanged<String> onSelected,
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

  void _showSelectDialog(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return ListTile(
              title: Text(option),
              trailing: option == _syncQuality
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                onSelected(option);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

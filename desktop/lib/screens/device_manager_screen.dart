import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_desktop/services/server_service.dart';
import 'package:photosync_desktop/theme/app_theme.dart';

class DeviceManagerScreen extends StatefulWidget {
  final DesktopServer desktopServer;

  const DeviceManagerScreen({
    Key? key,
    required this.desktopServer,
  }) : super(key: key);

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final List<Device> _connectedDevices = [];
  bool _isLoading = true;
  String _localIp = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _getNetworkInfo();
    _loadDevices();
    // 每 3 秒轮询一次服务器上的已连接设备
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _loadDevices());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadDevices() {
    final fromServer = widget.desktopServer.connectedDevices;
    setState(() {
      // 完全替换为服务器当前记录的设备列表
      _connectedDevices.clear();
      _connectedDevices.addAll(fromServer);
      _isLoading = false;
    });
  }

  Future<void> _getNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('172.')) {
            setState(() => _localIp = addr.address);
            break;
          }
        }
        if (_localIp.isNotEmpty) break;
      }
    } catch (e) {
      print('Error getting network info: $e');
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServerInfoCard(),
                  const SizedBox(height: AppTheme.spacingLG),
                  _buildConnectionGuide(),
                  const SizedBox(height: AppTheme.spacingLG),
                  if (_connectedDevices.isNotEmpty) ...[
                    Text(
                      '已连接设备',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    ..._connectedDevices.map(_buildDeviceCard),
                  ] else ...[
                    _buildEmptyState(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildServerInfoCard() {
    final serverUrl = _localIp.isNotEmpty
        ? 'http://$_localIp:${widget.desktopServer.port}'
        : '正在获取...';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: AppTheme.successColor, size: 12),
                const SizedBox(width: 8),
                Text(
                  '服务器运行中',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            _buildInfoRow('IP 地址', _localIp.isNotEmpty ? _localIp : '获取中...'),
            const SizedBox(height: AppTheme.spacingSM),
            _buildInfoRow('端口', '${widget.desktopServer.port}'),
            const SizedBox(height: AppTheme.spacingSM),
            _buildInfoRow('连接地址', serverUrl),
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _localIp.isNotEmpty
                    ? () => _copyToClipboard(serverUrl)
                    : null,
                icon: const Icon(Icons.copy),
                label: const Text('复制连接地址'),
              ),
            ),
            if (_localIp.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingLG),
              Center(
                child: QrImageView(
                  data: jsonEncode({
                    'type': 'photosync_device',
                    'ip': _localIp,
                    'port': widget.desktopServer.port,
                    'name': '桌面端',
                  }),
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showScanGuide,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('扫描二维码'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionGuide() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '连接指南',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            _buildGuideStep('1', '确保手机和电脑连接同一个 WiFi'),
            _buildGuideStep('2', '打开手机 PhotoSync App'),
            _buildGuideStep('3', '进入"可同步设备"页面'),
            _buildGuideStep('4', '点击"手动添加"，输入上方 IP 和端口'),
            _buildGuideStep('5', '点击"连接"完成配对'),
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '如果连接失败，请检查路由器是否开启了"AP隔离/客户端隔离"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_outlined,
            size: 64,
            color: AppTheme.textLightColor,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            '暂无连接设备',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '等待手机端连接...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }

  bool _isDeviceOffline(Device device) {
    if (device.lastSeen == null) return true;
    return DateTime.now().difference(device.lastSeen!) >
        const Duration(minutes: 2);
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return '从未连接';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  Widget _buildDeviceCard(Device device) {
    final isOffline = _isDeviceOffline(device);
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          ),
          child: Icon(
            device.type == 'mobile' ? Icons.smartphone : Icons.computer,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.ip}:${device.port}'),
            Text(
              _formatLastSeen(device.lastSeen),
              style: TextStyle(
                fontSize: 12,
                color: isOffline ? Colors.grey : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOffline ? Colors.grey : AppTheme.successColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              isOffline ? '离线' : '在线',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOffline ? Colors.grey : AppTheme.successColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('扫描二维码'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请使用手机 PhotoSync App 扫描上方二维码，或按照以下步骤操作：'),
            SizedBox(height: 12),
            Text('1. 打开手机 PhotoSync App'),
            Text('2. 进入「可同步设备」页面'),
            Text('3. 点击右上角的「手动添加」'),
            Text('4. 输入本机显示的 IP 地址和端口'),
            Text('5. 点击「连接」完成配对'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/discovery_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/services/settings_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../services/sync_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  List<Device> _devices = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    _discoveryService.onDeviceFound = (device) {
      setState(() {
        if (!_devices.any((d) => d.id == device.id)) {
          _devices.add(device);
        }
      });
    };

    _discoveryService.onDeviceLost = (device) {
      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
      });
    };

    await _discoveryService.startDiscovery(
      deviceName: 'MyPhone',
      deviceType: 'mobile',
      httpPort: 8080,
    );

    setState(() => _isScanning = false);
  }

  /// 手动添加设备：通过 IP 地址连接桌面端
  Future<void> _addDeviceByIp() async {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '42433');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入桌面端的 IP 地址和端口',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '例如: 192.168.31.174',
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如: 42433',
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('连接'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final ip = ipCtrl.text.trim();
    final port = int.tryParse(portCtrl.text.trim()) ?? 0;

    if (ip.isEmpty || port <= 0) {
      _showMessage('请输入有效的 IP 地址和端口');
      return;
    }

    setState(() => _isScanning = true);

    try {
      // 尝试连接桌面端 health 接口验证
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);

      final request = await httpClient.get(ip, port, '/api/health');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      httpClient.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        if (data['status'] == 'healthy') {
          // 获取更多信息（用新的 client）
          final statusClient = HttpClient();
          statusClient.connectionTimeout = const Duration(seconds: 5);
          final statusReq =
              await statusClient.get(ip, port, '/api/sync/status');
          final statusResp = await statusReq.close();
          final statusBody = await statusResp.transform(utf8.decoder).join();
          statusClient.close();
          final statusData = jsonDecode(statusBody);

          final device = Device(
            id: 'desktop_$ip:$port',
            name: '桌面端 ($ip)',
            type: 'desktop',
            ip: ip,
            port: port,
            storageAvailable: statusData['storage_available'] as int?,
          );

          setState(() {
            if (!_devices.any((d) => d.id == device.id)) {
              _devices.add(device);
            }
          });

          // 保存设备信息供相册页面使用
          await _saveDeviceToPrefs(device);

          // 通知桌面端设备已连接
          await _notifyDesktopConnected(device);

          _showMessage('设备连接成功！');
        }
      } else {
        _showMessage('连接失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _showMessage(
          '无法连接到 $ip:$port，请检查:\n1. 桌面端是否已启动\n2. 手机和电脑是否在同一WiFi\n3. IP 地址是否正确');
    } catch (e) {
      _showMessage('连接失败: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _saveDeviceToPrefs(Device device) async {
    final storage = DeviceStorageService();
    await storage.addOrUpdateDevice(device);
  }

  Future<void> _notifyDesktopConnected(Device desktopDevice) async {
    try {
      final authService = AuthService();
      final user = await authService.loadUser();
      final userName = user?.username ?? '手机用户';

      // 发送手机自身的信息给桌面端，而不是桌面端的信息
      final myDevice = Device(
        id: user?.id ?? 'mobile_${DateTime.now().millisecondsSinceEpoch}',
        name: '手机端 ($userName)',
        type: 'mobile',
        ip: '',
        port: 0,
      );

      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      final request = await httpClient.post(
          desktopDevice.ip, desktopDevice.port, '/api/device/connect');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(myDevice.toJson()));
      final response = await request.close();
      httpClient.close();
      print('Notify desktop result: ${response.statusCode}');
    } catch (e) {
      print('Failed to notify desktop: $e');
    }
  }

  void _showDeviceInfo(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('名称', device.name),
            _buildInfoRow('类型', device.type),
            _buildInfoRow('IP 地址', device.ip),
            _buildInfoRow('端口', '${device.port}'),
            if (device.storageAvailable != null)
              _buildInfoRow('可用空间',
                  '${(device.storageAvailable! / 1024 / 1024 / 1024).toStringAsFixed(1)} GB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showShareQrCode(Device device) {
    final qrData = jsonEncode({
      'type': 'photosync_device',
      'name': device.name,
      'ip': device.ip,
      'port': device.port,
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分享二维码'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 250,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  Future<String?> _calculatePhotoHash(AssetEntity photo) async {
    try {
      final file = await photo.originFile;
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      return null;
    }
  }

  Future<void> _uploadPhotos(Device device, List<AssetEntity> photos) async {
    final transferService = TransferService(device);
    final authService = AuthService();
    final user = await authService.loadUser();
    for (final photo in photos) {
      try {
        final file = await photo.originFile;
        if (file == null) continue;
        await transferService.uploadFile(
          filePath: file.path,
          filename: photo.title ?? 'photo.jpg',
          createdAt: photo.createDateTime,
          album: photo.relativePath,
          userId: user?.username ?? user?.id,
        );
      } catch (e) {
        print('Upload error: $e');
      }
    }
    transferService.dispose();
  }

  @override
  void dispose() {
    _discoveryService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          if (_isScanning && _devices.isEmpty)
            SliverFillRemaining(
              child: _buildScanningState(),
            )
          else if (_devices.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildDeviceCard(_devices[index]),
                  childCount: _devices.length,
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '可同步设备',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: _addDeviceByIp,
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            _isScanning ? '正在扫描局域网...' : '发现 ${_devices.length} 个设备',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            '正在搜索设备',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '请确保设备在同一WiFi网络下',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
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
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: AppTheme.dividerColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              size: 48,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            '未发现设备',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            '自动发现可能因路由器限制而失败\n请尝试手动添加设备',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          ElevatedButton.icon(
            onPressed: _addDeviceByIp,
            icon: const Icon(Icons.add),
            label: const Text('手动添加设备'),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          TextButton.icon(
            onPressed: () {
              setState(() => _isScanning = true);
              _startDiscovery();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新扫描'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeviceOptions(device),
          borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  ),
                  child: Icon(
                    device.type == 'desktop'
                        ? Icons.computer_rounded
                        : Icons.smartphone_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        '${device.ip}:${device.port}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                      if (device.storageAvailable != null)
                        Text(
                          '可用空间: ${_formatBytes(device.storageAvailable!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.successColor,
                                  ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                    vertical: AppTheme.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        '在线',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  void _showDeviceOptions(Device device) {
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
              device.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            _buildOptionTile(
              icon: Icons.sync_rounded,
              title: '立即同步',
              subtitle: '同步当天拍摄的照片',
              onTap: () async {
                Navigator.pop(context);
                final settings = SettingsService();
                await settings.load();
                final syncService =
                    SyncService(syncTodayOnly: settings.syncTodayOnly);
                final photos = await syncService.getPhotosToSync();

                if (photos.isEmpty) {
                  if (context.mounted) {
                    _showMessage('今天没有新照片');
                  }
                  return;
                }

                // 自动同步：检查重复并跳过
                if (context.mounted) {
                  _showMessage('正在检查 ${photos.length} 张当天照片...');
                }

                final hashes = <String>[];
                final hashToPhoto = <String, AssetEntity>{};
                for (final photo in photos) {
                  final hash = await _calculatePhotoHash(photo);
                  if (hash != null) {
                    hashes.add(hash);
                    hashToPhoto[hash] = photo;
                  }
                }

                final transferService = TransferService(device);
                final missingHashes =
                    await transferService.checkExistingFiles(hashes);
                transferService.dispose();

                final duplicateCount = hashes.length - missingHashes.length;
                final photosToSync = missingHashes
                    .where((h) => hashToPhoto.containsKey(h))
                    .map((h) => hashToPhoto[h]!)
                    .toList();

                if (photosToSync.isEmpty) {
                  if (context.mounted) {
                    _showMessage('当天的照片都已经同步过了');
                  }
                  return;
                }

                if (context.mounted) {
                  _showMessage(
                    duplicateCount > 0
                        ? '跳过 $duplicateCount 张重复，正在同步 ${photosToSync.length} 张新照片...'
                        : '正在同步 ${photosToSync.length} 张当天照片...',
                  );
                }

                // 实际上传
                await _uploadPhotos(device, photosToSync);

                if (context.mounted) {
                  _showMessage(
                    duplicateCount > 0
                        ? '同步完成！上传 ${photosToSync.length} 张，跳过 $duplicateCount 张重复'
                        : '同步完成！已上传 ${photosToSync.length} 张当天照片',
                  );
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.settings_rounded,
              title: '同步设置',
              subtitle: '配置自动同步规则',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.info_rounded,
              title: '设备信息',
              subtitle: '查看设备详情',
              onTap: () {
                Navigator.pop(context);
                _showDeviceInfo(device);
              },
            ),
            _buildOptionTile(
              icon: Icons.qr_code_rounded,
              title: '分享二维码',
              subtitle: '通过二维码分享设备连接信息',
              onTap: () {
                Navigator.pop(context);
                _showShareQrCode(device);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 同步设置页面（从设备详情页跳转）
class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: const Center(
        child: Text('请在底部「设置」页面中配置同步规则'),
      ),
    );
  }
}

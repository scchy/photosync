import 'dart:convert';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/discovery_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/services/settings_service.dart';



import 'package:qr_flutter/qr_flutter.dart';


import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import 'qr_scan_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final DeviceStorageService _deviceStorage = DeviceStorageService();
  List<Device> _onlineDevices = [];
  List<Device> _savedDevices = [];
  bool _isScanning = true;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
    _startDiscovery();
  }

  /// 加载已保存的历史设备
  Future<void> _loadSavedDevices() async {
    final saved = await _deviceStorage.getSavedDevices();
    setState(() {
      _savedDevices = saved;
    });
  }

  Future<void> _startDiscovery() async {
    _discoveryService.onDeviceFound = (device) {
      setState(() {
        if (!_onlineDevices.any((d) => d.id == device.id)) {
          _onlineDevices.add(device);
        }
        // 同步更新已保存设备中的在线状态
        final savedIndex = _savedDevices.indexWhere((d) => d.id == device.id);
        if (savedIndex >= 0) {
          _savedDevices[savedIndex] = device;
        }
      });
    };

    _discoveryService.onDeviceLost = (device) {
      setState(() {
        _onlineDevices.removeWhere((d) => d.id == device.id);
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context, false);
                _scanQrCode();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫一扫添加'),
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

    await _connectToDevice(ip, port);
  }

  /// 扫描二维码添加设备
  Future<void> _scanQrCode() async {
    final device = await Navigator.push<Device>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (device != null) {
      await _connectToDevice(device.ip, device.port);
    }
  }

  /// 连接指定 IP 和端口的设备
  Future<void> _connectToDevice(String ip, int port) async {
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
            if (!_onlineDevices.any((d) => d.id == device.id)) {
              _onlineDevices.add(device);
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
    } on SocketException catch (_) {
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

  void _showSyncEmptyDialog(String diagnostics,
      {bool permissionDenied = false, bool isLimited = false}) {
    final String title;
    final String hint;
    if (permissionDenied) {
      title = '相册权限未开启';
      hint =
          '提示:\n• 请在系统设置中为 PhotoSync 开启「照片和视频」访问权限\n• 如果已开启但仍提示此错误，请尝试完全关闭 App 后重新打开';
    } else if (isLimited) {
      title = '仅允许访问部分照片';
      hint =
          '提示:\n• 您选择了"仅允许访问部分照片"，系统只让 App 读取选中的照片\n• 请在系统设置中将权限改为"全部允许"\n• 修改后请完全关闭 App 再重新打开';
    } else {
      title = '未找到可同步的当天照片';
      hint =
          '提示:\n• 确保手机相册中有今天拍摄的照片\n• 部分照片可能因缺少拍摄时间信息无法识别\n• 请检查相册访问权限是否已开启\n• 刚拍的照片可能还未被系统索引，请等待几秒后重试';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline,
                color: permissionDenied || isLimited
                    ? Colors.orange
                    : Colors.blue),
            const SizedBox(width: 8),
            const Text('同步诊断'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(diagnostics, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Text(
                hint,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          if (permissionDenied || isLimited)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('去设置修改'),
            )
          else
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: diagnostics));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('诊断信息已复制')),
                );
              },
              child: const Text('复制信息'),
            ),
        ],
      ),
    );
  }

  Future<void> _saveDeviceToPrefs(Device device) async {
    await _deviceStorage.addOrUpdateDevice(device);
    await _loadSavedDevices();
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

  /// 重连历史设备
  Future<void> _reconnectDevice(Device device) async {
    setState(() => _isReconnecting = true);

    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);

      final request =
          await httpClient.get(device.ip, device.port, '/api/health');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      httpClient.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        if (data['status'] == 'healthy') {
          // 获取更多信息
          final statusClient = HttpClient();
          statusClient.connectionTimeout = const Duration(seconds: 5);
          final statusReq = await statusClient.get(
              device.ip, device.port, '/api/sync/status');
          final statusResp = await statusReq.close();
          final statusBody = await statusResp.transform(utf8.decoder).join();
          statusClient.close();
          final statusData = jsonDecode(statusBody);

          final updatedDevice = device.copyWith(
            storageAvailable: statusData['storage_available'] as int?,
          );

          setState(() {
            if (!_onlineDevices.any((d) => d.id == updatedDevice.id)) {
              _onlineDevices.add(updatedDevice);
            }
          });

          await _saveDeviceToPrefs(updatedDevice);
          await _notifyDesktopConnected(updatedDevice);

          _showMessage('设备重连成功！');
        }
      } else {
        _showMessage('重连失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (_) {
      _showMessage('无法连接到 ${device.ip}:${device.port}，请检查设备是否在线');
    } catch (e) {
      _showMessage('重连失败: $e');
    } finally {
      setState(() => _isReconnecting = false);
    }
  }

  @override
  void dispose() {
    _discoveryService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              if (_isScanning &&
                  _onlineDevices.isEmpty &&
                  _savedDevices.isEmpty)
                SliverFillRemaining(
                  child: _buildScanningState(),
                )
              else if (_onlineDevices.isEmpty && _savedDevices.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              else ...[
                // 在线设备列表
                if (_onlineDevices.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppTheme.spacingMD,
                        right: AppTheme.spacingMD,
                        top: AppTheme.spacingSM,
                        bottom: AppTheme.spacingXS,
                      ),
                      child: Text(
                        '在线设备',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDeviceCard(
                            _onlineDevices[index],
                            isOnline: true),
                        childCount: _onlineDevices.length,
                      ),
                    ),
                  ),
                ],
                // 历史/离线设备列表
                if (_savedDevices.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppTheme.spacingMD,
                        right: AppTheme.spacingMD,
                        top: AppTheme.spacingSM,
                        bottom: AppTheme.spacingXS,
                      ),
                      child: Text(
                        '历史设备',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final device = _savedDevices[index];
                          final isOnline =
                              _onlineDevices.any((d) => d.id == device.id);
                          return _buildDeviceCard(device, isOnline: isOnline);
                        },
                        childCount: _savedDevices.length,
                      ),
                    ),
                  ),
                ],
              ],
              // 底部占位
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
          // 重连加载指示器
          if (_isReconnecting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
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
            _isScanning
                ? '正在扫描局域网...'
                : '发现 ${_onlineDevices.length} 个在线设备，${_savedDevices.length} 个历史设备',
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
              color: AppTheme.dividerColor.withValues(alpha: 0.3),
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

  Widget _buildDeviceCard(Device device, {required bool isOnline}) {
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
          onTap: isOnline
              ? () => _showDeviceOptions(device)
              : () => _reconnectDevice(device),
          borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  ),
                  child: Icon(
                    device.type == 'desktop'
                        ? Icons.computer_rounded
                        : Icons.smartphone_rounded,
                    color: isOnline
                        ? AppTheme.primaryColor
                        : AppTheme.textLightColor,
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isOnline ? null : AppTheme.textLightColor,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        '${device.ip}:${device.port}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                      if (device.storageAvailable != null && isOnline)
                        Text(
                          '可用空间: ${_formatBytes(device.storageAvailable!)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.successColor,
                                  ),
                        ),
                      if (!isOnline)
                        Text(
                          '点击重连',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
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
                    color: isOnline
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.textLightColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTheme.successColor
                              : AppTheme.textLightColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        isOnline ? '在线' : '离线',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isOnline
                                  ? AppTheme.successColor
                                  : AppTheme.textLightColor,
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
                try {
                  Navigator.pop(context);
                  final settings = SettingsService();
                  await settings.load();
                  final syncService =
                      SyncService(syncTodayOnly: settings.syncTodayOnly);
                  final checkResult = await syncService.checkPhotosToSync();
                  final photos = checkResult.photos;

                  if (photos.isEmpty) {
                    if (context.mounted) {
                      _showSyncEmptyDialog(checkResult.diagnostics,
                          permissionDenied: checkResult.permissionDenied,
                          isLimited: checkResult.isLimited);
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
                } catch (e) {
                  if (context.mounted) {
                    _showMessage('同步出错: $e');
                  }
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
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
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

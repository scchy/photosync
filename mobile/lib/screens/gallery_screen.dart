import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:photosync_common/services/settings_service.dart';

import '../services/sync_service.dart';
import '../services/sync_stats_service.dart';
import '../services/today_sync_service.dart';
import '../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedFiles = [];
  SyncStats? _stats;
  bool _statsLoading = false;
  List<TodaySyncedPhoto> _todaySynced = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadTodaySynced();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    setState(() => _statsLoading = true);
    final service = SyncStatsService();
    final stats = await service.getStats(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadTodaySynced() async {
    final service = TodaySyncService();
    final list = await service.getTodaySyncedPhotos();
    if (mounted) {
      setState(() => _todaySynced = list);
    }
  }

  Future<void> _pickFromSystemGallery() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() => _selectedFiles = picked);
    await _startSyncFlow(picked);
  }

  /// 读取上次保存的设备
  Future<Device?> _loadLastDevice() async {
    final storage = DeviceStorageService();
    return await storage.getLastDevice();
  }

  /// 保存设备信息
  Future<void> _saveLastDevice(Device device) async {
    final storage = DeviceStorageService();
    await storage.addOrUpdateDevice(device);
  }

  Future<void> _startSyncFlow(List<XFile> files) async {
    // 1. 先尝试读取已保存的设备
    Device? device = await _loadLastDevice();

    // 2. 如果没有保存的设备，或用户想更换，弹出输入框
    if (device == null) {
      device = await _showDeviceInputDialog();
    } else {
      // 有保存的设备，询问是否使用
      final useSaved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('同步到设备'),
          content: Text(
            '使用已保存的设备？\n\n'
            'IP: ${device!.ip}\n'
            '端口: ${device.port}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('更换设备'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('使用此设备'),
            ),
          ],
        ),
      );

      if (useSaved == null) {
        // 用户取消
        setState(() => _selectedFiles.clear());
        return;
      }
      if (!useSaved) {
        device = await _showDeviceInputDialog();
      }
    }

    if (device == null) {
      // 用户取消输入
      setState(() => _selectedFiles.clear());
      return;
    }

    // 保存设备供下次使用
    await _saveLastDevice(device);

    if (!mounted) return;

    // 3. 检查重复
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在检查重复照片...'),
          ],
        ),
      ),
    );

    final hashes = <String>[];
    final hashToFile = <String, XFile>{};
    for (final file in files) {
      final hash = await _calculateFileHash(file);
      if (hash != null) {
        hashes.add(hash);
        hashToFile[hash] = file;
      }
    }

    final transferService = TransferService(device);
    final missingHashes = await transferService.checkExistingFiles(hashes);
    transferService.dispose();

    if (!mounted) return;
    Navigator.pop(context); // 关闭加载框

    final duplicateCount = hashes.length - missingHashes.length;

    // 全部重复
    if (duplicateCount > 0 && missingHashes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选中的照片都已经同步过了')),
        );
      }
      setState(() => _selectedFiles.clear());
      return;
    }

    // 有重复，弹出确认
    List<XFile> filesToSync = files;
    if (duplicateCount > 0 && missingHashes.isNotEmpty) {
      final skipDuplicate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发现重复照片'),
          content: Text(
            '选中的 ${files.length} 张照片中，有 $duplicateCount 张已经在服务器上。\n\n'
            '跳过重复，只同步 ${missingHashes.length} 张新照片？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('全部同步'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('跳过重复'),
            ),
          ],
        ),
      );

      if (skipDuplicate == null) {
        setState(() => _selectedFiles.clear());
        return;
      }
      if (skipDuplicate) {
        filesToSync = missingHashes
            .where((h) => hashToFile.containsKey(h))
            .map((h) => hashToFile[h]!)
            .toList();
      }
    }

    // 4. 开始上传
    _showSyncSheet(filesToSync, device, skipped: duplicateCount);
  }

  Future<Device?> _showDeviceInputDialog() async {
    final ipCtrl = TextEditingController(text: '192.168.31.174');
    final portCtrl = TextEditingController(text: '45043');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('同步到设备'),
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
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: '端口',
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('开始同步'),
          ),
        ],
      ),
    );

    if (result != true) return null;

    final ip = ipCtrl.text.trim();
    final port = int.tryParse(portCtrl.text.trim()) ?? 0;
    if (ip.isEmpty || port <= 0) return null;

    return Device(
      id: 'desktop_$ip:$port',
      name: '桌面端',
      type: 'desktop',
      ip: ip,
      port: port,
    );
  }

  Future<String?> _calculateFileHash(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> _calculateAssetHash(AssetEntity photo) async {
    try {
      final file = await photo.originFile;
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      return null;
    }
  }

  /// 同步当天照片
  Future<void> _syncTodayPhotos() async {
    try {
      final settings = SettingsService();
      await settings.load();

      final syncService = SyncService(syncTodayOnly: settings.syncTodayOnly);
      final checkResult = await syncService.checkPhotosToSync();
      final photos = checkResult.photos;

      if (photos.isEmpty) {
        if (mounted) {
          _showSyncEmptyDialog(checkResult.diagnostics,
              permissionDenied: checkResult.permissionDenied);
        }
        return;
      }

      // 获取保存的设备
      Device? device = await _loadLastDevice();
      if (device == null) {
        device = await _showDeviceInputDialog();
      } else {
        final useSaved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('同步到设备'),
            content: Text('使用已保存的设备?\n\nIP: ${device!.ip}\n端口: ${device.port}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('更换'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('使用'),
              ),
            ],
          ),
        );
        if (useSaved == null) return;
        if (!useSaved) {
          device = await _showDeviceInputDialog();
        }
      }

      if (device == null) return;
      await _saveLastDevice(device);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在检查 ${photos.length} 张当天照片...')),
      );

      // 检查重复
      final hashes = <String>[];
      final hashToPhoto = <String, AssetEntity>{};
      for (final photo in photos) {
        final hash = await _calculateAssetHash(photo);
        if (hash != null) {
          hashes.add(hash);
          hashToPhoto[hash] = photo;
        }
      }

      final transferService = TransferService(device);
      final missingHashes = await transferService.checkExistingFiles(hashes);
      transferService.dispose();

      final duplicateCount = hashes.length - missingHashes.length;
      final photosToSync = missingHashes
          .where((h) => hashToPhoto.containsKey(h))
          .map((h) => hashToPhoto[h]!)
          .toList();

      if (photosToSync.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当天的照片都已经同步过了')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(duplicateCount > 0
                ? '跳过 $duplicateCount 张重复，同步 ${photosToSync.length} 张...'
                : '正在同步 ${photosToSync.length} 张当天照片...'),
          ),
        );
      }

      // 上传
      await _uploadAssetPhotos(device, photosToSync);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(duplicateCount > 0
                ? '同步完成! 上传 ${photosToSync.length} 张，跳过 $duplicateCount 张重复'
                : '同步完成! 已上传 ${photosToSync.length} 张当天照片'),
          ),
        );
        await _loadTodaySynced();
        await _loadStats(forceRefresh: true);
      }
    } catch (e, st) {
      log('Sync today photos error: $e', stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步出错: $e')),
        );
      }
    }
  }

  Future<void> _uploadAssetPhotos(
      Device device, List<AssetEntity> photos) async {
    final transferService = TransferService(device);
    final authService = AuthService();
    final user = await authService.loadUser();
    for (final photo in photos) {
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
        if (result.success && mounted) {
          final service = TodaySyncService();
          await service.addSyncedPhoto(
              filename: photo.title ?? 'photo.jpg', path: file.path);
        }
      } catch (e) {
        print('Upload error: $e');
      }
    }
    transferService.dispose();
  }

  void _showSyncEmptyDialog(String diagnostics,
      {bool permissionDenied = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('同步诊断'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                permissionDenied ? '相册权限未开启' : '未找到可同步的当天照片',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(diagnostics, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const Text(
                '提示:\n• 确保手机相册中有今天拍摄的照片\n• 部分照片可能因缺少拍摄时间信息无法识别\n• 请检查相册访问权限是否已开启\n• 刚拍的照片可能还未被系统索引，请等待几秒后重试',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          if (permissionDenied)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('去设置开启'),
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

  void _showSyncSheet(List<XFile> files, Device device, {int skipped = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _SyncProgressSheet(
        files: files,
        device: device,
        skippedCount: skipped,
        onComplete: () {
          setState(() => _selectedFiles.clear());
        },
        onPhotoSynced: (filename, path) async {
          final service = TodaySyncService();
          await service.addSyncedPhoto(filename: filename, path: path);
          await _loadTodaySynced();
          await _loadStats(forceRefresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStats(forceRefresh: true);
            await _loadTodaySynced();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 头部
                  Text(
                    '相册同步',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    '从手机系统相册选择照片，同步到桌面端',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // 统计卡片
                  _buildStatsCard(),

                  const SizedBox(height: AppTheme.spacingXL),

                  // 主按钮：从系统相册选择
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickFromSystemGallery,
                      icon: const Icon(Icons.photo_library_rounded, size: 22),
                      label: const Text(
                        '从系统相册选择',
                        style: TextStyle(fontSize: 15, letterSpacing: -0.01),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingMD),

                  // 同步当天照片按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _syncTodayPhotos,
                      icon: const Icon(Icons.today_rounded, size: 20),
                      label: const Text(
                        '同步当天照片',
                        style: TextStyle(fontSize: 15, letterSpacing: -0.01),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // 辅助说明
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      border: Border.all(
                          color: AppTheme.infoColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.infoColor, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '选择照片手动同步，或一键同步今天拍摄的照片到桌面端。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.infoColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 今日已同步照片
                  if (_todaySynced.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXL),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '今日已同步 (${_todaySynced.length} 张)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _todaySynced.length,
                        itemBuilder: (context, index) {
                          final photo = _todaySynced[index];
                          return _TodaySyncedThumbnail(photo: photo);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacingXL),

                  // 已选文件预览（如果有）
                  if (_selectedFiles.isNotEmpty) ...[
                    Text(
                      '已选择 ${_selectedFiles.length} 张照片',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(
                                right: AppTheme.spacingSM),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.smallRadius),
                              image: DecorationImage(
                                image:
                                    FileImage(File(_selectedFiles[index].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    // 取消选择按钮
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedFiles.clear()),
                      icon: const Icon(Icons.clear),
                      label: const Text('清除选择'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_statsLoading && _stats == null) {
      return _StatsContainer(
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final stats = _stats;
    if (stats == null) {
      return _StatsContainer(
        child: Column(
          children: [
            const Icon(Icons.bar_chart,
                color: AppTheme.textLightColor, size: 28),
            const SizedBox(height: AppTheme.spacingMD),
            const Text('暂无同步统计',
                style: TextStyle(
                    color: AppTheme.textSecondaryColor, fontSize: 14)),
            const SizedBox(height: AppTheme.spacingSM),
            TextButton(
              onPressed: () => _loadStats(forceRefresh: true),
              child: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return _StatsContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart,
                      color: AppTheme.textPrimaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '同步统计',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.01,
                        ),
                  ),
                ],
              ),
              if (_statsLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                InkWell(
                  onTap: () => _loadStats(forceRefresh: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh,
                        size: 16, color: AppTheme.textSecondaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: '今日同步',
                  value: '${stats.todayCount}',
                  unit: '张',
                  icon: Icons.today,
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.dividerColor),
              Expanded(
                child: _StatItem(
                  label: '本月同步',
                  value: '${stats.monthlyCount}',
                  unit: '张',
                  icon: Icons.calendar_month,
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.dividerColor),
              Expanded(
                child: _StatItem(
                  label: '本年同步',
                  value: '${stats.yearlyCount}',
                  unit: '张',
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsContainer extends StatelessWidget {
  final Widget child;

  const _StatsContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
        border: Border.all(color: AppTheme.dividerColor, width: 1.0),
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: AppTheme.textLightColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textLightColor,
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                  letterSpacing: -0.02,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySyncedThumbnail extends StatelessWidget {
  final TodaySyncedPhoto photo;

  const _TodaySyncedThumbnail({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: AppTheme.spacingSM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        color: AppTheme.backgroundColor,
        border: Border.all(color: AppTheme.dividerColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.fileExists
          ? Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image, color: AppTheme.textLightColor, size: 22),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            photo.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppTheme.textLightColor),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// 同步进度底部弹窗
class _SyncProgressSheet extends StatefulWidget {
  final List<XFile> files;
  final Device device;
  final int skippedCount;
  final VoidCallback onComplete;
  final void Function(String filename, String path) onPhotoSynced;

  const _SyncProgressSheet({
    required this.files,
    required this.device,
    this.skippedCount = 0,
    required this.onComplete,
    required this.onPhotoSynced,
  });

  @override
  State<_SyncProgressSheet> createState() => _SyncProgressSheetState();
}

class _SyncProgressSheetState extends State<_SyncProgressSheet> {
  int _currentIndex = 0;
  bool _isComplete = false;
  bool _hasError = false;
  String _currentFile = '';
  double _progress = 0.0;
  String _status = '准备中...';

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    final transferService = TransferService(widget.device);

    for (int i = 0; i < widget.files.length; i++) {
      final file = widget.files[i];
      setState(() {
        _currentIndex = i;
        _currentFile = file.name;
        _progress = i / widget.files.length;
        _status = '正在上传...';
      });

      try {
        final authService = AuthService();
        final user = await authService.loadUser();
        final result = await transferService.uploadFile(
          filePath: file.path,
          filename: file.name,
          createdAt: DateTime.now(),
          userId: user?.username ?? user?.id,
        );

        if (!result.success) {
          setState(() {
            _hasError = true;
            _status = '上传失败: ${result.error}';
          });
        } else {
          // 记录成功同步的照片
          widget.onPhotoSynced(file.name, file.path);
        }
      } catch (e) {
        setState(() {
          _hasError = true;
          _status = '上传失败: $e';
        });
      }
    }

    transferService.dispose();

    setState(() {
      _isComplete = true;
      _progress = 1.0;
      _status = '同步完成';
    });

    await Future.delayed(const Duration(seconds: 1));
    widget.onComplete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.largeRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: AppTheme.spacingMD),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            child: Column(
              children: [
                if (!_isComplete) ...[
                  CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 3,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    '$_currentIndex / ${widget.files.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    _currentFile,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: _hasError
                          ? Colors.orange.withValues(alpha: 0.1)
                          : AppTheme.successColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasError
                          ? Icons.warning_rounded
                          : Icons.check_circle_rounded,
                      color: _hasError ? Colors.orange : AppTheme.successColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Text(
                    _hasError ? '同步完成（部分失败）' : '同步完成！',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color:
                              _hasError ? Colors.orange : AppTheme.successColor,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    widget.skippedCount > 0
                        ? '已上传 ${widget.files.length} 张，跳过 ${widget.skippedCount} 张重复'
                        : '已处理 ${widget.files.length} 张照片',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photosync_common/models/device.dart';
import 'package:photosync_common/services/auth_service.dart';
import 'package:photosync_common/services/transfer_service.dart';
import 'package:photosync_common/services/device_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedFiles = [];
  bool _isSyncing = false;

  static const String _keyLastDevice = 'photosync_last_device';

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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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

              // 主按钮：从系统相册选择
              ElevatedButton.icon(
                onPressed: _pickFromSystemGallery,
                icon: const Icon(Icons.photo_library_rounded, size: 28),
                label: const Text(
                  '从系统相册选择照片',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // 辅助说明
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '点击上方按钮调起手机系统相册，选择要同步的照片。支持多选。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

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
                        margin: const EdgeInsets.only(right: AppTheme.spacingSM),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                          image: DecorationImage(
                            image: FileImage(File(_selectedFiles[index].path)),
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
    );
  }
}

// 同步进度底部弹窗
class _SyncProgressSheet extends StatefulWidget {
  final List<XFile> files;
  final Device device;
  final int skippedCount;
  final VoidCallback onComplete;

  const _SyncProgressSheet({
    Key? key,
    required this.files,
    required this.device,
    this.skippedCount = 0,
    required this.onComplete,
  }) : super(key: key);

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
        final bytes = await file.readAsBytes();
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
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
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
                          ? Colors.orange.withOpacity(0.1)
                          : AppTheme.successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _hasError ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: _hasError ? Colors.orange : AppTheme.successColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Text(
                    _hasError ? '同步完成（部分失败）' : '同步完成！',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _hasError ? Colors.orange : AppTheme.successColor,
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

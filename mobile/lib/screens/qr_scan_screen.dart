import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photosync_common/models/device.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );
  bool _hasScanned = false;
  String _status = '请将二维码对准摄像头';
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _cameraReady = true);
    } else {
      setState(() {
        _status = '相机权限被拒绝，请在设置中开启';
        _cameraReady = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) {
      log('QR Scan: no barcode detected');
      return;
    }

    final raw = barcode.rawValue!;
    log('QR Scan raw: $raw');

    setState(() => _status = '识别到内容，正在解析...');

    Device? device;
    String? errorMsg;

    // 尝试1: 解析JSON格式
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      log('QR Scan decoded JSON: $data');

      if (data['type'] == 'photosync_device') {
        final portValue = data['port'];
        final port = portValue is int
            ? portValue
            : portValue is num
                ? portValue.toInt()
                : int.tryParse(portValue.toString()) ?? 0;

        device = Device(
          id: 'desktop_${data['ip']}:$port',
          name: data['name']?.toString() ?? '桌面端',
          type: 'desktop',
          ip: data['ip']?.toString() ?? '',
          port: port,
        );
        log('QR Scan device parsed from JSON: ${device.name} ${device.ip}:${device.port}');
      } else {
        errorMsg = '类型不匹配: ${data['type']}';
      }
    } catch (e) {
      log('QR Scan JSON parse failed: $e');
    }

    // 尝试2: 解析纯URL格式 (fallback)
    if (device == null) {
      try {
        final uri = Uri.parse(raw);
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          final ip = uri.host;
          final port = uri.port;
          if (ip.isNotEmpty && port > 0) {
            device = Device(
              id: 'desktop_$ip:$port',
              name: '桌面端',
              type: 'desktop',
              ip: ip,
              port: port,
            );
            log('QR Scan device parsed from URL: ${device.ip}:${device.port}');
          }
        }
      } catch (e) {
        log('QR Scan URL parse failed: $e');
      }
    }

    if (device != null && mounted) {
      _hasScanned = true;
      await _controller.stop().catchError((_) {});
      HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.pop(context, device);
      }
    } else if (mounted) {
      setState(() {
        _status =
            '无法识别: ${errorMsg ?? "格式不支持"}\n原始内容: ${raw.substring(0, raw.length > 50 ? 50 : raw.length)}...';
      });
      // 2秒后恢复扫描状态
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _status = '请将二维码对准摄像头');
      }
    }
  }

  void _showManualInput() async {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动输入设备信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '38085',
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
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final ip = ipCtrl.text.trim();
      final port = int.tryParse(portCtrl.text.trim()) ?? 0;
      if (ip.isNotEmpty && port > 0) {
        Navigator.pop(
          context,
          Device(
            id: 'desktop_$ip:$port',
            name: '桌面端',
            type: 'desktop',
            ip: ip,
            port: port,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          TextButton(
            onPressed: _showManualInput,
            child: const Text('手动输入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 相机预览
          if (_cameraReady)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            )
          else
            const Center(child: CircularProgressIndicator()),

          // 扫描框 overlay
          if (_cameraReady)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

          // 状态提示
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),

          // 底部提示
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              '扫描桌面端设备管理页面的二维码，或点击右上角手动输入',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

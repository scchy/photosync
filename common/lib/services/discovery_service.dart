import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:udp/udp.dart';

import '../models/device.dart';

/// 局域网设备发现服务
class DiscoveryService {
  static const int discoveryPort = 8888;
  static const int broadcastInterval = 3; // seconds
  static const int deviceTimeoutSeconds = 30;

  UDP? _sender;
  UDP? _receiver;
  bool _isRunning = false;
  Function(Device)? onDeviceFound;
  Function(Device)? onDeviceLost;
  Timer? _broadcastTimer;
  Timer? _timeoutTimer;

  final Map<String, Device> _discoveredDevices = {};
  final Map<String, DateTime> _lastSeen = {};
  Device? _myDevice;

  /// 获取运行状态
  bool get isRunning => _isRunning;

  /// 获取已发现的设备列表
  List<Device> get discoveredDevices => _discoveredDevices.values.toList();

  /// 启动设备发现服务
  Future<void> startDiscovery({
    required String deviceName,
    required String deviceType,
    required int httpPort,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    // 创建设备信息
    _myDevice = Device(
      id: await _getDeviceId(),
      name: deviceName,
      type: deviceType,
      ip: await _getLocalIp(),
      port: httpPort,
    );

    // 创建广播发送器
    _sender = await UDP.bind(Endpoint.any(port: const Port(0)));
    
    // 创建广播接收器
    _receiver = await UDP.bind(Endpoint.any(port: const Port(discoveryPort)));

    // 启动广播发送
    await _startBroadcast();

    // 启动监听
    _startListening();

    // 启动设备超时检测
    _startTimeoutCheck();
  }

  /// 启动广播发送
  Future<void> _startBroadcast() async {
    if (_myDevice == null) return;

    final message = jsonEncode({
      'type': 'discover',
      ..._myDevice!.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final broadcastEndpoint = Endpoint.broadcast(port: const Port(discoveryPort));

    // 立即发送一次
    await _sender?.send(messageBytes, broadcastEndpoint);

    // 定期广播
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: broadcastInterval),
      (_) async {
        if (!_isRunning) return;
        await _sender?.send(messageBytes, broadcastEndpoint);
      },
    );
  }

  /// 启动监听
  void _startListening() {
    _receiver?.asStream().listen((datagram) async {
      if (datagram == null) return;

      try {
        final data = jsonDecode(utf8.decode(datagram.data));
        
        // 忽略自己的广播
        if (data['id'] == _myDevice?.id) return;

        if (data['type'] == 'discover') {
          // 收到发现请求，发送响应
          await _sendResponse(datagram.address.address);
        } else if (data['type'] == 'response') {
          // 收到响应，更新设备列表
          final device = Device.fromJson(data);
          _updateDevice(device);
        }
      } catch (e) {
        print('Discovery parse error: $e');
      }
    });
  }

  /// 发送响应
  Future<void> _sendResponse(String targetIp) async {
    if (_myDevice == null) return;

    final response = jsonEncode({
      'type': 'response',
      ..._myDevice!.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _sender?.send(
      Uint8List.fromList(utf8.encode(response)),
      Endpoint.unicast(
        InternetAddress(targetIp),
        port: const Port(discoveryPort),
      ),
    );
  }

  /// 更新设备列表
  void _updateDevice(Device device) {
    final now = DateTime.now();
    _lastSeen[device.id] = now;

    if (!_discoveredDevices.containsKey(device.id)) {
      _discoveredDevices[device.id] = device;
      onDeviceFound?.call(device);
    } else {
      _discoveredDevices[device.id] = device.copyWith(lastSeen: now);
    }
  }

  /// 启动设备超时检测
  void _startTimeoutCheck() {
    _timeoutTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        final now = DateTime.now();
        final expired = _lastSeen.entries
            .where((e) => now.difference(e.value).inSeconds > deviceTimeoutSeconds)
            .map((e) => e.key)
            .toList();

        for (final id in expired) {
          final device = _discoveredDevices.remove(id);
          _lastSeen.remove(id);
          if (device != null) {
            onDeviceLost?.call(device);
          }
        }
      },
    );
  }

  /// 获取本地IP地址
  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return '127.0.0.1';
  }

  /// 获取设备ID（简化实现）
  Future<String> _getDeviceId() async {
    // 实际应使用持久化存储
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 停止服务
  void stop() {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _timeoutTimer?.cancel();
    _sender?.close();
    _receiver?.close();
  }
}
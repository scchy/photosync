import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photosync_common/models/device.dart';

/// 统一管理服务端设备存储（支持多设备列表）
class DeviceStorageService {
  static const String _keyDevices = 'photosync_saved_devices';
  static const String _keyLastDevice = 'photosync_last_device';

  /// 获取所有已保存设备
  Future<List<Device>> getSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyDevices);
    if (jsonStr == null || jsonStr.isEmpty) {
      // 兼容旧数据：尝试读取单个设备
      final lastJson = prefs.getString(_keyLastDevice);
      if (lastJson != null) {
        final data = jsonDecode(lastJson);
        final device = Device.fromJson(data);
        // 迁移到列表
        await saveDevices([device]);
        return [device];
      }
      return [];
    }
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((d) => Device.fromJson(d)).toList();
  }

  /// 保存设备列表
  Future<void> saveDevices(List<Device> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(devices.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDevices, jsonStr);
    // 同步更新最后一个设备
    if (devices.isNotEmpty) {
      await prefs.setString(_keyLastDevice, jsonEncode(devices.last.toJson()));
    }
  }

  /// 添加/更新设备（按 ID 去重）
  Future<void> addOrUpdateDevice(Device device) async {
    final devices = await getSavedDevices();
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
    await saveDevices(devices);
  }

  /// 删除设备
  Future<void> removeDevice(String deviceId) async {
    final devices = await getSavedDevices();
    devices.removeWhere((d) => d.id == deviceId);
    await saveDevices(devices);
  }

  /// 更新设备的 IP 和端口
  Future<void> updateDeviceIpPort(String deviceId, String ip, int port) async {
    final devices = await getSavedDevices();
    final index = devices.indexWhere((d) => d.id == deviceId);
    if (index >= 0) {
      devices[index] = Device(
        id: devices[index].id,
        name: devices[index].name,
        type: devices[index].type,
        ip: ip,
        port: port,
      );
      await saveDevices(devices);
    }
  }

  /// 获取最后使用的设备
  Future<Device?> getLastDevice() async {
    final devices = await getSavedDevices();
    return devices.isNotEmpty ? devices.last : null;
  }
}

import 'package:flutter/material.dart';

/// 设备模型（手动实现，不依赖代码生成）
class Device {
  final String id;
  final String name;
  final String type; // 'mobile' or 'desktop'
  final String ip;
  final int port;
  final DateTime? lastSeen;
  final int? storageAvailable;
  final String? version;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.ip,
    required this.port,
    this.lastSeen,
    this.storageAvailable,
    this.version,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      storageAvailable: json['storageAvailable'] as int?,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'ip': ip,
      'port': port,
      'lastSeen': lastSeen?.toIso8601String(),
      'storageAvailable': storageAvailable,
      'version': version,
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? type,
    String? ip,
    int? port,
    DateTime? lastSeen,
    int? storageAvailable,
    String? version,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      storageAvailable: storageAvailable ?? this.storageAvailable,
      version: version ?? this.version,
    );
  }

  @override
  String toString() {
    return 'Device(id: $id, name: $name, type: $type, ip: $ip, port: $port)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

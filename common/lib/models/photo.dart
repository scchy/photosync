import 'package:flutter/material.dart';

enum SyncStatus {
  pending,
  syncing,
  completed,
  failed,
  skipped,
}

/// 照片模型（手动实现）
class Photo {
  final String id;
  final String filename;
  final String path;
  final int size;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? thumbnailPath;
  final String? mimeType;
  final int? width;
  final int? height;
  final String? album;
  final String? hash;
  final SyncStatus? syncStatus;
  final DateTime? syncTime;
  final String? deviceId;

  Photo({
    required this.id,
    required this.filename,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.modifiedAt,
    this.thumbnailPath,
    this.mimeType,
    this.width,
    this.height,
    this.album,
    this.hash,
    this.syncStatus,
    this.syncTime,
    this.deviceId,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as String,
      filename: json['filename'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      thumbnailPath: json['thumbnailPath'] as String?,
      mimeType: json['mimeType'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      album: json['album'] as String?,
      hash: json['hash'] as String?,
      syncStatus: json['syncStatus'] != null
          ? SyncStatus.values.firstWhere(
              (e) => e.name == json['syncStatus'],
              orElse: () => SyncStatus.pending,
            )
          : null,
      syncTime: json['syncTime'] != null
          ? DateTime.parse(json['syncTime'] as String)
          : null,
      deviceId: json['deviceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'path': path,
      'size': size,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'album': album,
      'hash': hash,
      'syncStatus': syncStatus?.name,
      'syncTime': syncTime?.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  Photo copyWith({
    String? id,
    String? filename,
    String? path,
    int? size,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? thumbnailPath,
    String? mimeType,
    int? width,
    int? height,
    String? album,
    String? hash,
    SyncStatus? syncStatus,
    DateTime? syncTime,
    String? deviceId,
  }) {
    return Photo(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      path: path ?? this.path,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      album: album ?? this.album,
      hash: hash ?? this.hash,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  String toString() {
    return 'Photo(id: $id, filename: $filename, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Photo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

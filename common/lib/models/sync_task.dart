enum TaskStatus {
  pending,
  running,
  paused,
  completed,
  failed,
  cancelled,
}

/// 同步任务模型（手动实现）
class SyncTask {
  final String id;
  final String deviceId;
  final List<String> photoIds;
  final TaskStatus status;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? totalBytes;
  final int? transferredBytes;
  final String? error;

  SyncTask({
    required this.id,
    required this.deviceId,
    required this.photoIds,
    required this.status,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.totalBytes,
    this.transferredBytes,
    this.error,
  });

  factory SyncTask.fromJson(Map<String, dynamic> json) {
    return SyncTask(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      photoIds: List<String>.from(json['photoIds'] as List),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      totalBytes: json['totalBytes'] as int?,
      transferredBytes: json['transferredBytes'] as int?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'photoIds': photoIds,
      'status': status.name,
      'createdAt': createdAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'totalBytes': totalBytes,
      'transferredBytes': transferredBytes,
      'error': error,
    };
  }

  SyncTask copyWith({
    String? id,
    String? deviceId,
    List<String>? photoIds,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? totalBytes,
    int? transferredBytes,
    String? error,
  }) {
    return SyncTask(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      photoIds: photoIds ?? this.photoIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      error: error ?? this.error,
    );
  }

  /// 计算传输进度百分比
  double get progressPercentage {
    final total = totalBytes;
    if (total == null || total == 0) return 0.0;
    if (transferredBytes == null) return 0.0;
    return (transferredBytes! / total).clamp(0.0, 1.0);
  }

  /// 是否已完成
  bool get isCompleted => status == TaskStatus.completed;

  /// 是否失败
  bool get isFailed => status == TaskStatus.failed;

  @override
  String toString() {
    return 'SyncTask(id: $id, status: $status, photos: ${photoIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

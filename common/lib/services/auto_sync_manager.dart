import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 自动同步管理器
/// 监听网络变化，在WiFi连接时自动触发同步
class AutoSyncManager {
  bool _isEnabled = false;
  bool _syncOnWifiOnly = true;
  Duration _syncInterval = const Duration(minutes: 30);
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;
  
  final List<VoidCallback> _syncListeners = [];
  final VoidCallback? onSyncTrigger;
  final VoidCallback? onDeviceFound;
  
  /// 是否启用自动同步
  bool get isEnabled => _isEnabled;
  
  /// 是否仅在WiFi下同步
  bool get syncOnWifiOnly => _syncOnWifiOnly;
  
  /// 同步间隔
  Duration get syncInterval => _syncInterval;
  
  /// 是否有监听器
  bool get hasListeners => _syncListeners.isNotEmpty;
  
  AutoSyncManager({
    this.onSyncTrigger,
    this.onDeviceFound,
  }) {
    _startConnectivityMonitoring();
  }
  
  /// 开始监听网络状态
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _handleConnectivityChange(result);
      },
    );
  }
  
  /// 处理网络状态变化
  void _handleConnectivityChange(ConnectivityResult result) async {
    if (result == ConnectivityResult.wifi) {
      onDeviceFound?.call();
      
      if (_isEnabled) {
        _triggerSync();
      }
    } else if (result == ConnectivityResult.mobile) {
      if (_isEnabled && !_syncOnWifiOnly) {
        _triggerSync();
      }
    }
  }
  
  /// 触发同步
  void _triggerSync() {
    onSyncTrigger?.call();
    
    for (final listener in _syncListeners) {
      listener();
    }
  }
  
  /// 设置是否启用自动同步
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    
    if (enabled) {
      _startPeriodicSync();
    } else {
      _stopPeriodicSync();
    }
  }
  
  /// 设置是否仅在WiFi下同步
  void setSyncOnWifiOnly(bool wifiOnly) {
    _syncOnWifiOnly = wifiOnly;
  }
  
  /// 设置同步间隔
  void setSyncInterval(Duration interval) {
    _syncInterval = interval;
    
    if (_isEnabled) {
      _stopPeriodicSync();
      _startPeriodicSync();
    }
  }
  
  /// 开始定期同步
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      _triggerSync();
    });
  }
  
  /// 停止定期同步
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  /// 检查当前网络状态
  Future<ConnectivityResult> checkConnectivity() async {
    return await Connectivity().checkConnectivity();
  }
  
  /// 添加同步监听器
  void addSyncListener(VoidCallback listener) {
    _syncListeners.add(listener);
  }
  
  /// 移除同步监听器
  void removeSyncListener(VoidCallback listener) {
    _syncListeners.remove(listener);
  }
  
  /// 模拟网络变化（用于测试）
  Future<void> simulateNetworkChange(ConnectivityResult result) async {
    _handleConnectivityChange(result);
  }
  
  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _stopPeriodicSync();
    _syncListeners.clear();
  }
}

typedef VoidCallback = void Function();

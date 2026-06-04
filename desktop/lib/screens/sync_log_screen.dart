import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photosync_desktop/services/server_service.dart';
import 'package:photosync_desktop/theme/app_theme.dart';

class SyncLogScreen extends StatefulWidget {
  final DesktopServer desktopServer;

  const SyncLogScreen({Key? key, required this.desktopServer})
      : super(key: key);

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  String _filterType = 'all';
  String _filterStatus = 'all';

  Timer? _refreshTimer;

  final List<Map<String, String>> _typeFilters = [
    {'value': 'all', 'label': '全部'},
    {'value': 'upload', 'label': '上传'},
    {'value': 'delete', 'label': '删除'},
    {'value': 'device', 'label': '设备'},
    {'value': 'error', 'label': '错误'},
  ];

  final List<Map<String, String>> _statusFilters = [
    {'value': 'all', 'label': '全部状态'},
    {'value': 'success', 'label': '成功'},
    {'value': 'error', 'label': '失败'},
    {'value': 'info', 'label': '信息'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final logs = await widget.desktopServer.getSyncLogs(
      limit: 200,
      type: _filterType == 'all' ? null : _filterType,
      status: _filterStatus == 'all' ? null : _filterStatus,
    );
    final summary = await widget.desktopServer.getSyncLogSummary();
    setState(() {
      _logs = logs;
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有同步日志吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.desktopServer.clearSyncLogs();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步日志'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _clearLogs),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterBar(),
          Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final todayUploads = _summary['today_uploads'] ?? 0;
    final todayPhotos = _summary['today_photos'] ?? 0;
    final errorCount = _summary['error_count'] ?? 0;
    final deviceCount = _summary['device_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          _buildSummaryCard('今日上传', '$todayUploads 次', Icons.cloud_upload,
              AppTheme.successColor),
          const SizedBox(width: AppTheme.spacingMD),
          _buildSummaryCard('今日照片', '$todayPhotos 张', Icons.photo_library,
              AppTheme.primaryColor),
          const SizedBox(width: AppTheme.spacingMD),
          _buildSummaryCard(
              '错误', '$errorCount 条', Icons.error_outline, AppTheme.errorColor),
          const SizedBox(width: AppTheme.spacingMD),
          _buildSummaryCard(
              '设备数', '$deviceCount 台', Icons.devices, AppTheme.infoColor),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondaryColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _typeFilters
                  .map((f) => DropdownMenuItem(
                        value: f['value'],
                        child: Text(f['label']!,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _filterType = value!);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _statusFilters
                  .map((f) => DropdownMenuItem(
                        value: f['value'],
                        child: Text(f['label']!,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync_outlined, size: 64, color: AppTheme.textLightColor),
            const SizedBox(height: AppTheme.spacingMD),
            Text('暂无同步记录', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('同步操作后会显示在这里', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isFirstOfDay = index == 0 ||
            !_isSameDay(
              DateTime.parse(_logs[index]['timestamp']),
              DateTime.parse(_logs[index - 1]['timestamp']),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfDay) _buildDayHeader(DateTime.parse(log['timestamp'])),
            _buildLogItem(log),
          ],
        );
      },
    );
  }

  Widget _buildDayHeader(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = '今天';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = '昨天';
    } else {
      label = '${date.month}月${date.day}日';
    }
    return Padding(
      padding: const EdgeInsets.only(
          top: AppTheme.spacingSM, bottom: AppTheme.spacingSM),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final status = log['status'] as String? ?? 'info';
    final type = log['type'] as String? ?? 'info';
    final timestamp = DateTime.parse(log['timestamp']);

    final (iconData, iconColor) = _getLogIcon(status, type);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['message'] as String? ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (log['details'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        log['details'] as String,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondaryColor),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeChip(type),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(timestamp),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textLightColor),
                      ),
                      if (log['device_name'] != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.devices,
                            size: 12, color: AppTheme.textLightColor),
                        const SizedBox(width: 2),
                        Text(
                          log['device_name'] as String,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textLightColor),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final labels = {
      'upload': '上传',
      'delete': '删除',
      'device': '设备',
      'error': '错误',
      'info': '信息',
    };
    final colors = {
      'upload': AppTheme.successColor,
      'delete': Colors.orange,
      'device': AppTheme.infoColor,
      'error': AppTheme.errorColor,
      'info': AppTheme.textSecondaryColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[type] ?? AppTheme.textSecondaryColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        labels[type] ?? type,
        style: TextStyle(
          fontSize: 10,
          color: colors[type] ?? AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (IconData, Color) _getLogIcon(String status, String type) {
    switch (status) {
      case 'success':
        return (Icons.check_circle, AppTheme.successColor);
      case 'error':
        return (Icons.error, AppTheme.errorColor);
      case 'warning':
        return (Icons.warning, AppTheme.warningColor);
      default:
        switch (type) {
          case 'upload':
            return (Icons.cloud_upload, AppTheme.primaryColor);
          case 'delete':
            return (Icons.delete_outline, Colors.orange);
          case 'device':
            return (Icons.devices, AppTheme.infoColor);
          default:
            return (Icons.info, AppTheme.infoColor);
        }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

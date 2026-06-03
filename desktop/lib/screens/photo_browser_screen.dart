import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photosync_desktop/services/server_service.dart';
import 'package:photosync_desktop/theme/app_theme.dart';

class PhotoBrowserScreen extends StatefulWidget {
  final DesktopServer desktopServer;

  const PhotoBrowserScreen({Key? key, required this.desktopServer})
      : super(key: key);

  @override
  State<PhotoBrowserScreen> createState() => _PhotoBrowserScreenState();
}

class _PhotoBrowserScreenState extends State<PhotoBrowserScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _photos = [];
  Map<String, dynamic> _stats = {};
  bool _groupByUser = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final grouped = await widget.desktopServer.getPhotosGrouped();
    final stats = await widget.desktopServer.getStats();
    if (mounted) {
      setState(() {
        _photos = grouped;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这张照片吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await widget.desktopServer.deletePhoto(id);
    if (!mounted) return;

    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片已删除')),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('照片浏览'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildStatsBar(),
                _buildViewToggle(),
                Expanded(child: _buildPhotoList()),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.dividerColor)),
              ),
              child: _buildStatsPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _stats['total'] ?? 0;
    final daily = (_stats['daily'] as List<dynamic>?) ?? [];
    final todayCount = daily.isNotEmpty && daily.first['date'] == _todayString()
        ? daily.first['count'] as int? ?? 0
        : 0;

    final monthly = (_stats['monthly'] as List<dynamic>?) ?? [];
    final thisMonth = _currentMonth();
    final monthCount = monthly.isNotEmpty && monthly.first['month'] == thisMonth
        ? monthly.first['count'] as int? ?? 0
        : 0;

    final yearly = (_stats['yearly'] as List<dynamic>?) ?? [];
    final thisYear = DateTime.now().year.toString();
    final yearCount = yearly.isNotEmpty && yearly.first['year'] == thisYear
        ? yearly.first['count'] as int? ?? 0
        : 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          _buildStatCard('总照片', '$total', Icons.photo_library),
          const SizedBox(width: AppTheme.spacingMD),
          _buildStatCard('今日', '$todayCount', Icons.today),
          const SizedBox(width: AppTheme.spacingMD),
          _buildStatCard('本月', '$monthCount', Icons.calendar_month),
          const SizedBox(width: AppTheme.spacingMD),
          _buildStatCard('本年', '$yearCount', Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('全部照片')),
          ButtonSegment(value: true, label: Text('按用户查看')),
        ],
        selected: {_groupByUser},
        onSelectionChanged: (Set<bool> selected) {
          setState(() => _groupByUser = selected.first);
        },
      ),
    );
  }

  Widget _buildPhotoList() {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: AppTheme.textLightColor),
            const SizedBox(height: AppTheme.spacingMD),
            Text('暂无照片', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('从手机端同步照片后会显示在这里',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_groupByUser) {
      return _buildGroupedByUser();
    }
    return _buildGroupedByYear();
  }

  Widget _buildGroupedByYear() {
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (final photo in _photos) {
      final year = photo['year'] as String? ?? '未知';
      final month = photo['month'] as String? ?? '未知';
      grouped.putIfAbsent(year, () => {});
      grouped[year]!.putIfAbsent(month, () => []);
      grouped[year]![month]!.add(photo);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: grouped.length,
      itemBuilder: (context, yearIndex) {
        final year = grouped.keys.elementAt(yearIndex);
        final months = grouped[year]!;
        return ExpansionTile(
          key: ValueKey('year-$year'),
          title: Text('$year年 (${_countPhotos(months)}张)'),
          initiallyExpanded: yearIndex == 0,
          children: months.entries.map((monthEntry) {
            return ExpansionTile(
              key: ValueKey('month-$year-${monthEntry.key}'),
              title: Text('${monthEntry.key}月 (${monthEntry.value.length}张)'),
              children: [
                _buildPhotoGrid(monthEntry.value),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGroupedByUser() {
    final Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>
        grouped = {};
    for (final photo in _photos) {
      final user = photo['user'] as String? ?? '未知用户';
      final year = photo['year'] as String? ?? '未知';
      final month = photo['month'] as String? ?? '未知';
      grouped.putIfAbsent(user, () => {});
      grouped[user]!.putIfAbsent(year, () => {});
      grouped[user]![year]!.putIfAbsent(month, () => []);
      grouped[user]![year]![month]!.add(photo);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: grouped.length,
      itemBuilder: (context, userIndex) {
        final user = grouped.keys.elementAt(userIndex);
        final years = grouped[user]!;
        return ExpansionTile(
          key: ValueKey('user-$user'),
          title: Text('$user (${_countPhotosDeep(years)}张)'),
          initiallyExpanded: userIndex == 0,
          children: years.entries.map((yearEntry) {
            return ExpansionTile(
              key: ValueKey('user-year-$user-${yearEntry.key}'),
              title:
                  Text('${yearEntry.key}年 (${_countPhotos(yearEntry.value)}张)'),
              children: yearEntry.value.entries.map((monthEntry) {
                return ExpansionTile(
                  key: ValueKey(
                      'user-month-$user-${yearEntry.key}-${monthEntry.key}'),
                  title:
                      Text('${monthEntry.key}月 (${monthEntry.value.length}张)'),
                  children: [_buildPhotoGrid(monthEntry.value)],
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPhotoGrid(List<Map<String, dynamic>> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppTheme.spacingSM,
        mainAxisSpacing: AppTheme.spacingSM,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final filePath = photo['path'] as String?;
        final photoId = photo['id'] as String;
        final exists = filePath != null && File(filePath).existsSync();

        return GestureDetector(
          onTap: exists ? () => _showPhotoDetail(photo) : null,
          onSecondaryTap: () => _deletePhoto(photoId),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.smallRadius),
              color: AppTheme.dividerColor.withValues(alpha: 0.3),
            ),
            child: exists
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                    child: Image.file(
                      File(filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPhotoPlaceholder(photo, broken: true),
                    ),
                  )
                : _buildPhotoPlaceholder(photo, broken: true),
          ),
        );
      },
    );
  }

  Widget _buildPhotoPlaceholder(Map<String, dynamic> photo,
      {bool broken = false}) {
    final filename = photo['filename'] as String? ?? '';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            broken ? Icons.broken_image : Icons.image,
            color: broken ? AppTheme.errorColor : AppTheme.textLightColor,
          ),
          const SizedBox(height: 4),
          Text(
            filename,
            style: TextStyle(
              fontSize: 10,
              color: broken ? AppTheme.errorColor : AppTheme.textLightColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (broken)
            const Text(
              '文件缺失',
              style: TextStyle(fontSize: 9, color: Colors.red),
            ),
        ],
      ),
    );
  }

  void _showPhotoDetail(Map<String, dynamic> photo) {
    final filePath = photo['path'] as String?;
    if (filePath == null || !File(filePath).existsSync()) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(filePath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  // Delay to let dialog dismiss animation complete
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) _deletePhoto(photo['id'] as String);
                  });
                },
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${photo['filename']} · ${photo['user']} · ${photo['year']}-${photo['month']}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    final daily = (_stats['daily'] as List<dynamic>?) ?? [];
    final monthly = (_stats['monthly'] as List<dynamic>?) ?? [];
    final yearly = (_stats['yearly'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        Text('每日同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSM),
        ...daily
            .take(7)
            .map((d) => _buildStatsRow(d['date'] as String, d['count'] as int)),
        const Divider(height: 32),
        Text('每月同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSM),
        ...monthly.take(6).map(
            (m) => _buildStatsRow(m['month'] as String, m['count'] as int)),
        const Divider(height: 32),
        Text('每年同步', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSM),
        ...yearly
            .map((y) => _buildStatsRow(y['year'] as String, y['count'] as int)),
      ],
    );
  }

  Widget _buildStatsRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text('$count 张',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  int _countPhotos(Map<String, List<Map<String, dynamic>>> months) {
    return months.values.fold(0, (sum, photos) => sum + photos.length);
  }

  int _countPhotosDeep(
      Map<String, Map<String, List<Map<String, dynamic>>>> years) {
    return years.values.fold(0, (sum, months) => sum + _countPhotos(months));
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

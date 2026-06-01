import 'dart:developer';

import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photosync_common/services/auth_service.dart';

/// 照片检查结果
class SyncCheckResult {
  final List<AssetEntity> photos;
  final String diagnostics;
  final bool permissionDenied;

  SyncCheckResult(this.photos, this.diagnostics,
      {this.permissionDenied = false});
}

/// 同步服务
/// 负责获取待同步的照片列表，支持按日期过滤
class SyncService {
  /// 是否仅同步当天照片
  bool syncTodayOnly;
  final AuthService _authService = AuthService();

  SyncService({this.syncTodayOnly = false});

  /// 获取当前用户ID
  String? get userId => _authService.userId;

  /// 获取待同步照片（旧API，兼容已有调用）
  Future<List<AssetEntity>> getPhotosToSync() async {
    final result = await checkPhotosToSync();
    return result.photos;
  }

  /// 判断时间是否在指定日期范围内
  bool _isInTodayRange(DateTime time, DateTime todayStart, DateTime todayEnd) {
    return time.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
        time.isBefore(todayEnd);
  }

  /// 获取待同步照片（带诊断信息）
  Future<SyncCheckResult> checkPhotosToSync() async {
    final buffer = StringBuffer();

    try {
      // 使用 photo_manager 请求权限
      log('SyncService: requesting photo permission...');
      PermissionState pmState =
          await PhotoManager.requestPermissionExtend();
      log('SyncService: photo_manager state = $pmState, isAuth = ${pmState.isAuth}');
      buffer.writeln('相册权限状态: $pmState');

      // 如果权限被拒绝，尝试用 permission_handler 再次请求
      if (!pmState.isAuth) {
        log('SyncService: photo_manager denied, trying permission_handler...');
        final phStatus = await Permission.photos.request();
        log('SyncService: permission_handler photos status = $phStatus');
        buffer.writeln('permission_handler 状态: $phStatus');

        if (phStatus.isGranted) {
          // permission_handler 显示已授权，但 photo_manager 仍拒绝
          // 可能是需要重启应用才能生效
          buffer.writeln('\n⚠️ 检测到权限状态不一致');
          buffer.writeln('系统设置显示已授权，但 photo_manager 仍返回拒绝。');
          buffer.writeln('请尝试完全关闭 App 后重新打开，再点击同步。');
          return SyncCheckResult([], buffer.toString(),
              permissionDenied: true);
        }

        buffer.writeln('\n⚠️ 相册访问权限未开启');
        buffer.writeln(
            '注意：「从系统相册选择」使用的是系统自带选择器，不需要此权限；');
        buffer.writeln(
            '但「自动同步当天照片」需要直接读取相册，必须开启该权限。');
        buffer.writeln('\n请在系统设置中为 PhotoSync 开启「照片和视频」访问权限。');
        return SyncCheckResult([], buffer.toString(),
            permissionDenied: true);
      }

      if (pmState == PermissionState.limited) {
        buffer.writeln(
            '\n⚠️ 您选择了"仅允许访问部分照片"，可能导致新照片不可见。');
        buffer.writeln(
            '如需同步所有照片，请在系统设置中改为"全部允许"。');
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      log('SyncService: found ${albums.length} albums');
      buffer.writeln('\n找到 ${albums.length} 个相册');

      if (albums.isEmpty) {
        log('SyncService: no albums found');
        buffer.writeln('未找到任何相册');
        return SyncCheckResult([], buffer.toString());
      }

      // 获取全部照片
      final album = albums[0];
      final assetCount = await album.assetCountAsync;
      log('SyncService: album "${album.name}" has $assetCount assets');
      buffer.writeln('相册 "${album.name}" 共 $assetCount 张照片');

      final List<AssetEntity> allPhotos = await album.getAssetListPaged(
        page: 0,
        size: 10000,
      );
      log('SyncService: loaded ${allPhotos.length} photos from album');
      buffer.writeln('已加载 ${allPhotos.length} 张照片');

      // 显示当前系统时间，帮助诊断时区问题
      final now = DateTime.now();
      buffer.writeln('\n当前系统时间: ${now.toString()}');

      if (!syncTodayOnly) {
        log('SyncService: returning all ${allPhotos.length} photos (syncTodayOnly=false)');
        buffer.writeln('模式: 同步所有照片');
        return SyncCheckResult(allPhotos, buffer.toString());
      }

      // 仅保留当天拍摄的照片
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      log('SyncService: filtering for today: $todayStart ~ $todayEnd');
      buffer.writeln('过滤日期范围:');
      buffer.writeln('  开始: ${todayStart.toString()}');
      buffer.writeln('  结束: ${todayEnd.toString()}');

      int todayCount = 0;
      int recentCount = 0;
      final filtered = allPhotos.where((photo) {
        final createTime = photo.createDateTime;
        final modifiedTime = photo.modifiedDateTime;

        // 同时检查 createDateTime 和 modifiedDateTime
        final isToday = _isInTodayRange(createTime, todayStart, todayEnd) ||
            _isInTodayRange(modifiedTime, todayStart, todayEnd);

        if (isToday) {
          todayCount++;
          log(
              'SyncService: photo "${photo.title}" create=$createTime modified=$modifiedTime -> TODAY ✓');
        }

        // 记录最近5张照片的详细信息用于诊断
        if (recentCount < 5) {
          recentCount++;
          buffer.writeln('\n照片$recentCount: "${photo.title}"');
          buffer.writeln('  创建时间: ${createTime.toString()}');
          buffer.writeln('  修改时间: ${modifiedTime.toString()}');
          buffer.writeln('  是否当天: ${isToday ? "是" : "否"}');
        }

        return isToday;
      }).toList();

      log('SyncService: ${filtered.length}/${allPhotos.length} photos are from today');
      buffer.writeln('\n当天照片: $todayCount 张 / 总计 ${allPhotos.length} 张');

      if (filtered.isEmpty && allPhotos.isNotEmpty) {
        buffer.writeln('\n可能原因:');
        buffer.writeln('1. 照片的拍摄时间/修改时间不在今天范围内');
        buffer.writeln('2. 手机系统时间设置不正确');
        buffer.writeln(
            '3. Android 13+ 的"仅允许访问部分照片"权限限制了可见照片');
        buffer.writeln('4. 刚拍摄的照片可能还未被系统索引，请等待几秒后重试');
      }

      return SyncCheckResult(filtered, buffer.toString());
    } catch (e, st) {
      log('SyncService error: $e', stackTrace: st);
      buffer.writeln('发生错误: $e');
      return SyncCheckResult([], buffer.toString());
    }
  }

  /// 获取当天照片数量（用于 UI 展示）
  Future<int> getTodayPhotoCount() async {
    final result = await checkPhotosToSync();
    return result.photos.length;
  }
}

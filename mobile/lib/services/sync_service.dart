import 'package:photo_manager/photo_manager.dart';
import 'package:photosync_common/services/auth_service.dart';

/// 同步服务
/// 负责获取待同步的照片列表，支持按日期过滤
class SyncService {
  /// 是否仅同步当天照片
  bool syncTodayOnly;
  final AuthService _authService = AuthService();

  SyncService({this.syncTodayOnly = false});

  /// 获取当前用户ID
  String? get userId => _authService.userId;

  /// 获取所有照片（支持日期过滤）
  Future<List<AssetEntity>> getPhotosToSync() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      return [];
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      return [];
    }

    // 获取全部照片
    final List<AssetEntity> allPhotos = await albums[0].getAssetListPaged(
      page: 0,
      size: 10000,
    );

    if (!syncTodayOnly) {
      return allPhotos;
    }

    // 仅保留当天拍摄的照片
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return allPhotos.where((photo) {
      final createTime = photo.createDateTime;
      return createTime.isAfter(todayStart) && createTime.isBefore(todayEnd);
    }).toList();
  }

  /// 获取当天照片数量（用于 UI 展示）
  Future<int> getTodayPhotoCount() async {
    final photos = await getPhotosToSync();
    return photos.length;
  }
}

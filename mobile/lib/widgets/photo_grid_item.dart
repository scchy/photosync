import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../theme/app_theme.dart';

class PhotoGridItem extends StatelessWidget {
  final AssetEntity photo;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PhotoGridItem({
    Key? key,
    required this.photo,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 照片缩略图
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            child: FutureBuilder<Uint8List?>(
              future: photo.thumbnailDataWithSize(
                const ThumbnailSize(300, 300),
                quality: 90,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                }
                return Container(
                  color: AppTheme.dividerColor,
                  child: const Center(
                    child: Icon(Icons.image, color: AppTheme.textLightColor),
                  ),
                );
              },
            ),
          ),

          // 选择遮罩
          if (isSelectionMode)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
            ),

          // 选择指示器
          if (isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),

          // 视频标识
          if (photo.type == AssetType.video)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

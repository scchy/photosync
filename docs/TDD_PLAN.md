# PhotoSync TDD 开发计划

## TDD 核心流程
每个功能遵循：
1. **Red**: 写测试（预期失败）
2. **Green**: 写最小实现（让测试通过）
3. **Refactor**: 重构优化

## 实施优先级（按依赖顺序）

### Phase 1: 核心通信层（基础依赖）

#### 1.1 UDP 设备发现服务
- **测试目标**: `DiscoveryService`
  - 测试1: 启动服务后能广播发现消息
  - 测试2: 能正确解析响应消息并识别设备
  - 测试3: 设备离线后能从列表移除
- **实现文件**: `common/lib/services/discovery_service.dart`
- **状态**: 框架已有，需完善测试和修复

#### 1.2 HTTP 文件传输服务
- **测试目标**: `TransferService`
  - 测试1: 能构建正确的上传请求
  - 测试2: 能处理上传进度回调
  - 测试3: 能检查服务器文件存在性
- **实现文件**: `common/lib/services/transfer_service.dart`
- **状态**: 框架已有，需完善测试和修复

#### 1.3 桌面端 HTTP 接收服务
- **测试目标**: `DesktopServer`
  - 测试1: 启动后监听指定端口
  - 测试2: 能接收 multipart 文件上传
  - 测试3: 能正确存储文件到日期目录
  - 测试4: 能查询同步状态
- **实现文件**: `desktop/lib/services/server_service.dart`
- **状态**: 基础框架已有，multipart 解析需完善

### Phase 2: 数据层（通信层完成后）

#### 2.1 照片模型
- **测试目标**: `Photo` 模型
  - 测试1: 能正确序列化/反序列化 JSON
  - 测试2: 同步状态枚举正确工作
- **实现文件**: `common/lib/models/photo.dart`
- **状态**: 框架已有，需验证

#### 2.2 设备模型
- **测试目标**: `Device` 模型
  - 测试1: 能正确序列化/反序列化 JSON
- **实现文件**: `common/lib/models/device.dart`
- **状态**: 框架已有，需验证

#### 2.3 文件存储管理
- **测试目标**: `StorageManager`
  - 测试1: 能按日期创建目录结构
  - 测试2: 能生成缩略图
  - 测试3: 能计算磁盘可用空间
- **新文件**: `desktop/lib/services/storage_manager.dart`

### Phase 3: 手机端 UI（数据层完成后）

#### 3.1 相册页面
- **测试目标**: `GalleryScreen`
  - 测试1: 能加载相册照片
  - 测试2: 长按进入选择模式
  - 测试3: 选择照片后显示同步按钮
  - 测试4: 同步进度正确更新
- **实现文件**: `mobile/lib/screens/gallery_screen.dart`
- **状态**: 框架已有，需完善

#### 3.2 设备发现页面
- **测试目标**: `DevicesScreen`
  - 测试1: 扫描时显示动画
  - 测试2: 发现设备后显示卡片
  - 测试3: 点击设备显示选项菜单
- **实现文件**: `mobile/lib/screens/devices_screen.dart`
- **状态**: 框架已有，需完善

#### 3.3 设置页面
- **测试目标**: `SettingsScreen`
  - 测试1: 切换自动同步开关
  - 测试2: 选择同步质量
- **实现文件**: `mobile/lib/screens/settings_screen.dart`
- **状态**: 框架已有，需完善

### Phase 4: 同步引擎（UI完成后）

#### 4.1 增量同步
- **测试目标**: `IncrementalSync`
  - 测试1: 能计算本地文件哈希
  - 测试2: 能对比服务器已存在文件
  - 测试3: 只传输缺失文件
- **新文件**: `common/lib/services/incremental_sync.dart`

#### 4.2 断点续传
- **测试目标**: `ResumableTransfer`
  - 测试1: 传输中断后能恢复
  - 测试2: 分片上传正确合并
- **新文件**: `common/lib/services/resumable_transfer.dart`

#### 4.3 自动同步（WiFi 检测）
- **测试目标**: `AutoSyncManager`
  - 测试1: 连接到 WiFi 时触发检测
  - 测试2: 发现新照片时自动同步
  - 测试3: 非 WiFi 时不自动同步
- **新文件**: `mobile/lib/services/auto_sync_manager.dart`

### Phase 5: 桌面端 UI（同步引擎完成后）

#### 5.1 照片浏览界面
- **测试目标**: `PhotoBrowserScreen`
  - 测试1: 按时间轴显示照片
  - 测试2: 点击照片查看大图
  - 测试3: 支持缩放和滑动
- **新文件**: `desktop/lib/screens/photo_browser_screen.dart`

#### 5.2 设备管理界面
- **测试目标**: `DeviceManagerScreen`
  - 测试1: 显示已配对设备列表
  - 测试2: 能移除设备配对
- **新文件**: `desktop/lib/screens/device_manager_screen.dart`

#### 5.3 同步日志界面
- **测试目标**: `SyncLogScreen`
  - 测试1: 显示同步历史记录
  - 测试2: 支持按日期筛选
- **新文件**: `desktop/lib/screens/sync_log_screen.dart`

### Phase 6: 集成测试（最后）

#### 6.1 端到端测试
- 测试1: 手机端发现桌面端
- 测试2: 选择照片并同步到桌面
- 测试3: 桌面端能查看同步的照片
- 测试4: 断网后重连自动同步

#### 6.2 构建验证
- 测试1: `flutter build apk` 成功
- 测试2: `flutter build linux` 成功

## 测试策略

### 单元测试
- 使用 `flutter_test` 和 `mockito`
- 每个服务类独立测试
- 模拟网络请求和文件系统

### Widget 测试
- 使用 `WidgetTester`
- 测试用户交互流程
- 验证 UI 状态变化

### 集成测试
- 使用 `integration_test`
- 端到端场景验证
- 真实网络环境测试

## 开发顺序

按以下顺序逐个实施，每个都遵循 TDD 流程：

1. `Device` 模型测试 → 实现
2. `Photo` 模型测试 → 实现
3. `DiscoveryService` 测试 → 重构现有代码
4. `TransferService` 测试 → 重构现有代码
5. `DesktopServer` 测试 → 重构现有代码
6. `StorageManager` 测试 → 实现
7. `GalleryScreen` 测试 → 重构现有代码
8. `IncrementalSync` 测试 → 实现
9. `AutoSyncManager` 测试 → 实现
10. 桌面端 UI 测试 → 实现
11. 集成测试 → 端到端验证

## 当前第一步

从最简单的开始：**Device 模型测试**

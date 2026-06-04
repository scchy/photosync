# PhotoSync

在同一 WiFi 下同步手机照片到桌面端大容量存储的 Flutter 应用。

## 功能

- **WiFi 设备发现**：手机自动发现同一局域网下的桌面端（支持扫码 + 手动输入 IP）
- **照片同步**：选择照片手动上传，或一键同步当天拍摄的照片
- **增量同步**：基于 SHA-256 哈希，只传输新文件
- **打开即同步**：App 启动时自动检测 WiFi 并同步当天照片
- **同步日志**：相册页面显示当天同步记录（时间、数量、设备）
- **桌面端浏览**：按用户/年/月分组浏览，支持展开/折叠
- **照片管理**：桌面端支持删除照片，自动清理空目录
- **同步统计**：今日/本月/本年同步数量实时统计
- **已保存设备**：手机端支持编辑/删除已保存的桌面端设备
- **Xiaomi HyperOS / MIUI 兼容**：处理系统相册权限检测差异

## 技术栈

- **Flutter** — 跨平台（Android + Linux 桌面）
- **HTTP 文件传输** — 基于 shelf + multipart
- **纯文件系统存储** — 桌面端无 SQLite，照片元数据实时扫描文件系统
- **SharedPreferences** — 设置持久化 + 设备存储 + 同步日志
- **Material Design 3** — 活力蓝绿主题

## 存储结构

桌面端采用纯文件系统存储，无需数据库：

```
{storageRoot}/
├── photos/
│   └── {userId}/
│       └── {yyyy}/
│           └── {mm}/
│               └── {filename}
├── hashes.json          # 照片哈希去重索引
└── logs/
    └── sync_{yyyymmdd}.jsonl   # 同步日志
```

## 项目结构

```
photosync/
├── common/              # 共享代码（模型 + 服务）
│   ├── lib/models/      # Device, Photo, SyncTask, User
│   └── lib/services/    # Auth, Discovery, Transfer, Settings, AutoSync, DeviceStorage
├── mobile/              # 手机端 Flutter 应用（Android）
│   ├── lib/screens/     # Gallery, Devices, Settings, Auth
│   ├── lib/services/    # SyncService, SyncLogService, TodaySyncService, SyncStatsService
│   └── lib/widgets/     # PhotoGridItem
├── desktop/             # 桌面端 Linux 应用
│   ├── lib/screens/     # PhotoBrowser, DeviceManager, SyncLog, Settings, Auth
│   └── lib/services/    # DesktopServer, StorageConfigService
├── integration_test/    # 集成测试
├── docs/                # 设计文档
└── build.sh             # 构建脚本
```

## 快速开始

### 环境要求

- Flutter SDK 3.27+
- Android SDK（手机端）
- Linux 开发环境（桌面端）
- Java 17

### 构建

```bash
# 一键构建（手机端 + 桌面端 + 测试）
./build.sh

# 手动构建手机端 APK
cd mobile
flutter build apk --release

# 手动构建桌面端 Linux
cd desktop
flutter build linux --release
```

### 运行

**手机端**：
```bash
cd mobile
flutter run
```

**桌面端**：
```bash
cd desktop
flutter run -d linux
```

## 默认设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| 自动同步 | ✅ 开启 | 打开 App 时自动同步 |
| 仅 WiFi 同步 | ✅ 开启 | 仅在 WiFi 下同步 |
| 仅同步当天 | ✅ 开启 | 只同步今天拍摄的照片 |
| 同步质量 | 原图 | 保持原始画质 |

## API 端点

```
POST   /api/upload           # 上传照片（multipart）
GET    /api/photos           # 获取照片列表
GET    /api/photos/grouped   # 按用户/年/月分组
DELETE /api/photos/<id>      # 删除照片
GET    /api/stats            # 同步统计
GET    /api/devices          # 已连接设备列表
POST   /api/device/connect   # 设备连接通知
GET    /api/health           # 健康检查
POST   /api/sync/check       # 哈希重复检查
```

## 开发

### 运行测试

```bash
# 公共模块测试
cd common && flutter test

# 手机端测试
cd mobile && flutter test

# 桌面端测试
cd desktop && flutter test

# 集成测试
flutter test integration_test/app_test.dart
```

### TDD 流程

项目按 TDD 方式开发，详见 `docs/TDD_PLAN.md`：
1. 写测试（Red）
2. 写最小实现（Green）
3. 重构优化（Refactor）

## CI / CD

GitHub Actions 自动执行：
- **Lint**: `flutter analyze`（common + mobile + desktop）
- **Test**: `flutter test`（全模块）
- **Build**: APK + Linux 桌面端
- **Release**: 自动版本迭代 + Release 附件

## 文档

- `docs/design.md` — 架构设计
- `docs/TDD_PLAN.md` — TDD 实施计划
- `docs/TDD_PROGRESS.md` — 进度跟踪

## 贡献

按 TDD 流程贡献，详见 `docs/TDD_PLAN.md`。

# PhotoSync

在同一 WiFi 下同步手机照片到桌面端大容量存储的 Flutter 应用。

> **当前版本**: v1.2.0+5

## 功能

- **WiFi 设备发现**：手机自动发现同一局域网下的桌面端（支持扫码 + 手动输入 IP）
- **照片同步**：选择照片手动上传，或一键同步当天拍摄的照片
- **增量同步**：基于 SHA-256 哈希，只传输新文件
- **断点续传**：大文件分片上传，中断后可续传
- **打开即同步**：App 启动时自动检测 WiFi，3 秒后自动同步当天照片
- **同步日志**：相册页面显示当天同步记录（时间、数量、设备）
- **桌面端浏览**：按用户/年/月分组浏览，支持展开/折叠
- **照片管理**：桌面端支持删除照片，自动清理空目录
- **同步统计**：今日/本月/本年同步数量实时统计
- **已保存设备**：手机端支持编辑/删除已保存的桌面端设备
- **Xiaomi HyperOS / MIUI 兼容**：处理系统相册权限检测差异，权限异常时仍可强制继续

## 技术栈

- **Flutter 3.27** — 跨平台（Android + Linux 桌面）
- **HTTP 文件传输** — 基于 shelf + multipart
- **纯文件系统存储** — 桌面端无 SQLite，照片元数据实时扫描文件系统
- **SharedPreferences** — 设置持久化 + 设备存储 + 同步日志
- **Material Design 3** — 活力蓝绿主题（主色 `#2563EB`，成功色 `#10B981`）

## 存储结构

桌面端采用纯文件系统存储，无需数据库：

```
{storageRoot}/
├── photos/
│   └── {userId}/
│       └── {yyyy}/
│           └── {mm}/
│               └── {filename}
├── hashes.json               # 照片哈希去重索引
└── logs/
    └── sync_{yyyymmdd}.jsonl # 同步日志（每天一个文件）
```

## 项目结构

```
photosync/
├── common/              # 共享代码（模型 + 服务）
│   ├── lib/models/      # Device, Photo, SyncTask, User
│   └── lib/services/    # Auth, Discovery, Transfer, Settings, AutoSync,
│                        # DeviceStorage, IncrementalSync, ResumableTransfer
├── mobile/              # 手机端 Flutter 应用（Android）
│   ├── lib/screens/     # Gallery, Devices, Settings, Auth, QRScan
│   ├── lib/services/    # SyncService, SyncLogService, TodaySyncService,
│                        # SyncStatsService, PermissionHelper
│   └── lib/widgets/     # PhotoGridItem
├── desktop/             # 桌面端 Linux 应用
│   ├── lib/screens/     # PhotoBrowser, DeviceManager, SyncLog, Settings, Auth
│   └── lib/services/    # DesktopServer, StorageConfigService, StorageManager,
│                        # ThumbnailCache
├── integration_test/    # 集成测试
├── docs/                # 设计文档
└── build.sh             # 构建脚本
```

## 快速开始

### 环境要求

- Flutter SDK 3.27+
- Dart SDK 3.6+
- Android SDK（手机端）
- Linux 开发环境（桌面端）
- Java 17（Android 构建）

### 构建

```bash
# 一键构建（手机端 + 桌面端 + 全量测试）
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

### 使用流程

1. 在电脑上启动桌面端，记录显示的 IP 地址和端口号
2. 在手机上打开 App，连接同一 WiFi
3. 在「设备」页面点击「添加设备」，扫码或手动输入电脑 IP
4. 在「相册」页面点击「同步当天照片」即可开始同步
5. 桌面端「照片浏览」页面可查看和管理已同步的照片

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
# 公共模块测试（47 个测试）
cd common && flutter test

# 手机端测试（9 个测试）
cd mobile && flutter test

# 桌面端测试（21 个测试）
cd desktop && flutter test

# 全量测试
cd common && flutter test && cd ../mobile && flutter test && cd ../desktop && flutter test
```

### TDD 流程

项目按 TDD 方式开发，详见 `docs/TDD_PLAN.md`：
1. 写测试（Red）
2. 写最小实现（Green）
3. 重构优化（Refactor）

## CI / CD

GitHub Actions 自动执行（`.github/workflows/ci.yml`）：

- **Lint** (`lint`): `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - common / mobile / desktop 三个模块分别分析
- **Test** (`test`): `flutter test`
  - 全模块单元测试，共 77 个测试用例
- **Build Mobile** (`build-mobile`): 构建 Android APK
  - 依赖 lint + test 通过后执行
  - 产出 `app-release.apk`
- **Build iOS** (`build-ios`): 构建 iOS（macOS runner）
- **Build Desktop** (`build-desktop`): 构建 Linux 桌面端
  - 依赖 lint + test 通过后执行
  - 产出可执行 bundle

## 文档

- `docs/design.md` — 架构设计
- `docs/TDD_PLAN.md` — TDD 实施计划
- `docs/TDD_PROGRESS.md` — 进度跟踪

## 已知问题

- iOS 构建需要 macOS + Xcode，CI 中已配置 macOS runner
- 桌面端缩略图生成依赖 `image` 库，极小 JPEG 可能生成失败（不影响照片存储）

## 贡献

按 TDD 流程贡献，详见 `docs/TDD_PLAN.md`。

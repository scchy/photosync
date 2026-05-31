# WiFi照片同步应用 — 设计文档

## 项目名称：PhotoSync（暂定）

## 功能概述
在同一WiFi网络下，手机端自动发现桌面端，选择并同步照片到桌面端大容量存储。

## 技术栈

### 手机端
- **Flutter** — 跨平台（Android + iOS）
- **photo_manager** — 读取系统相册
- **udp** — 局域网设备发现（UDP广播）
- **http** — 文件传输
- **provider/bloc** — 状态管理

### 桌面端（Linux）
- **Flutter Desktop** — 与手机端共享UI代码
- ** shelf** — HTTP服务器（接收照片）
- **udp** — 响应设备发现
- **sqlite** — 照片索引数据库

## 架构设计

```
┌─────────────────┐      WiFi LAN      ┌─────────────────┐
│   手机端 (Flutter) │  ←────────────→  │  桌面端 (Flutter) │
│  ┌───────────┐  │    UDP广播发现      │  ┌───────────┐  │
│  │ 相册读取   │  │  ←────────────→  │  │ HTTP服务   │  │
│  │ 照片选择   │  │    HTTP传输       │  │ 文件存储   │  │
│  │ 同步管理   │  │  ←────────────→  │  │ 数据库索引 │  │
│  └───────────┘  │                   │  └───────────┘  │
└─────────────────┘                   └─────────────────┘
```

## 核心功能模块

### 1. 局域网发现（Discovery）
- **手机端**：启动UDP广播（255.255.255.255:8888），发送设备信息
- **桌面端**：监听UDP广播，响应设备信息
- **协议**：JSON格式，包含设备名、IP、端口、设备类型

### 2. 照片读取（Gallery）
- 使用 `photo_manager` 读取系统相册
- 支持按时间排序、文件夹浏览
- 缩略图生成与缓存

### 3. 同步引擎（Sync）
- **手动同步**：用户选择照片 → 上传
- **自动同步**：连接WiFi后自动检测新照片并上传
- **增量同步**：只传输新增/修改的文件（基于哈希或时间戳）
- **断点续传**：大文件支持分片传输

### 4. 桌面端存储（Storage）
- 接收照片并按日期/月份组织文件夹
- SQLite数据库记录照片元数据（文件名、路径、大小、时间、手机来源）
- 提供照片浏览和搜索界面

## 通信协议

### 设备发现协议（UDP）
```json
// 广播消息
{
  "type": "discover",
  "device_name": "iPhone 15",
  "device_id": "uuid",
  "device_type": "mobile",
  "timestamp": 1234567890
}

// 响应消息
{
  "type": "response",
  "device_name": "HomePC",
  "device_id": "uuid",
  "device_type": "desktop",
  "ip": "192.168.1.100",
  "port": 8080,
  "storage_available": 1000000000
}
```

### 文件传输协议（HTTP）
```
POST /api/upload
Content-Type: multipart/form-data

file: <binary>
metadata: {
  "filename": "IMG_1234.jpg",
  "created_at": "2024-01-01T12:00:00Z",
  "device_id": "uuid",
  "album": "Camera"
}

Response: { "success": true, "file_id": "xxx", "path": "/storage/2024/01/IMG_1234.jpg" }
```

### 同步状态协议
```
GET /api/sync/status
Response: { "last_sync": "2024-01-01T12:00:00Z", "total_files": 1000 }

POST /api/sync/check
Body: { "file_hashes": ["hash1", "hash2"] }
Response: { "missing": ["hash3", "hash4"] }
```

## UI设计

### 手机端页面
1. **首页/相册** — 网格展示照片，支持选择模式
2. **设备页** — 发现的可同步设备列表，显示存储空间
3. **同步页** — 同步进度、历史记录、自动同步设置
4. **设置页** — 同步规则、网络设置、关于

### 桌面端页面
1. **首页** — 照片墙，时间轴浏览
2. **设备管理** — 已配对手机设备列表
3. **同步日志** — 传输历史
4. **设置** — 存储路径、自动同步、网络

## 设计原则
- **Material Design 3** — 简洁、清新
- **卡片式布局** — 照片展示用圆角卡片
- **柔和配色** — 白色/浅灰底色，蓝色/绿色强调色
- **流畅动画** — 页面切换、照片选择、同步进度
- **空状态设计** — 无照片/无设备时的友好提示

## 数据流

```
手机端发现桌面端 → 建立连接 → 读取相册 → 计算差异 → 传输文件 → 确认完成
     ↑                                                                  │
     └────────────────  同步状态更新  ←──────────────────────────────────┘
```

## 安全考虑
- 局域网内通信，不暴露到公网
- 可选：设备配对确认（首次连接需桌面端确认）
- 可选：传输加密（TLS/SSL）

## 开发计划

### Phase 1: 核心框架
- [ ] 创建Flutter项目（手机端 + Linux桌面端）
- [ ] 实现UDP设备发现
- [ ] 实现HTTP基础通信

### Phase 2: 手机端功能
- [ ] 相册读取与展示
- [ ] 照片选择功能
- [ ] 手动上传

### Phase 3: 桌面端功能
- [ ] HTTP文件接收服务
- [ ] 文件存储管理
- [ ] 照片浏览界面

### Phase 4: 同步引擎
- [ ] 增量同步
- [ ] 自动同步（WiFi连接检测）
- [ ] 断点续传

### Phase 5:  polish
- [ ] 高级UI动画
- [ ] 设置页面
- [ ] 错误处理与重试
- [ ] 性能优化

## 项目结构

```
photosync/
├── common/              # 共享代码（模型、协议、工具）
│   ├── lib/
│   │   ├── models/      # 数据模型
│   │   ├── protocol/    # 通信协议
│   │   └── utils/       # 工具类
│   └── pubspec.yaml
├── mobile/              # 手机端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/     # 页面
│   │   ├── widgets/     # 组件
│   │   └── services/    # 服务
│   └── pubspec.yaml
└── desktop/             # 桌面端（Linux）
    ├── lib/
    │   ├── main.dart
    │   ├── screens/
    │   ├── widgets/
    │   └── services/
    └── pubspec.yaml
```

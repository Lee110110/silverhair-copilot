# 银发族数字陪驾 (Silverhair Digital Co-Pilot)

帮助老年人使用智能手机的陪伴式辅助产品——老人照常用所有App，困难时一键获得帮助。

## 产品理念

**陪伴式辅助，而非简化式替代。** 不做"老人专用简化版App"，而是在老人使用任何App（微信、美团、设置等）时，子女可以实时在老人屏幕上画箭头、圈按钮来指引操作。

## MVP 核心功能

1. **SOS一键求助** — 老人按红色浮窗按钮，子女端 App 立即收到警报，可一键接受或直接拨打电话
2. **远程共屏标注** — 子女在老人屏幕上画箭头/圆圈/高亮指引操作，标注10秒自动淡出，不阻挡老人正常触摸
3. **亲情绑定** — 老人生成邀请码，子女输入后建立守护关系

## 项目结构

```
silverhair-copilot/
├── elderly_app/                    # Flutter + Kotlin Android App（老人端）
│   ├── android/.../kotlin/         # 原生Kotlin代码
│   │   ├── platform/               # Platform Channel处理器
│   │   │   ├── OverlayPlugin.kt          # SOS浮窗控制
│   │   │   ├── ScreenCapturePlugin.kt    # 屏幕采集桥接
│   │   │   ├── PhoneCallPlugin.kt        # 直接拨号
│   │   │   ├── AnnotationOverlayPlugin.kt # 标注渲染桥接
│   │   ├── service/                # 原生Android服务
│   │   │   ├── FloatingOverlayService.kt       # SOS浮窗（72dp红色圆圈，可拖拽）
│   │   │   ├── ScreenCaptureService.kt         # MediaProjection屏幕采集（2fps JPEG）
│   │   │   ├── AnnotationOverlayService.kt     # 标注渲染（TYPE_APPLICATION_OVERLAY + FLAG_NOT_TOUCHABLE）
│   ├── lib/                        # Flutter Dart代码
│   │   ├── main.dart               # 入口（Provider + 路由）
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart         # 适老化大字主题（红色系）
│   │   │   ├── network/
│   │   │   │   ├── ws_client.dart           # WebSocket管理（自动重连+心跳）
│   │   │   │   ├── api_client.dart          # REST客户端（JWT认证）
│   │   │   │   ├── protocol.dart            # 消息类型常量
│   │   │   ├── platform_channels/
│   │   │   │   ├── overlay_channel.dart           # SOS浮窗 MethodChannel
│   │   │   │   ├── screen_capture_channel.dart    # 屏幕采集 MethodChannel+EventChannel
│   │   │   │   ├── phone_call_channel.dart        # 电话拨打 MethodChannel
│   │   │   │   ├── annotation_overlay_channel.dart # 标注渲染 MethodChannel
│   │   ├── features/
│   │   │   ├── auth/               # 登录（手机号+短信验证码，role=elderly）
│   │   │   ├── home/               # 主页+权限设置引导+SOS共屏监听
│   │   │   ├── coscreen/           # 共屏会话（屏幕采集→WebSocket帧推送+标注接收→原生Overlay渲染）
│
├── child_app/                      # Flutter Android App（子女端）
│   ├── lib/
│   │   ├── main.dart               # 入口（Provider + 路由 + AuthWrapper）
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart         # 子女版主题（蓝色系，非适老化尺寸）
│   │   │   ├── network/
│   │   │   │   ├── ws_client.dart           # WebSocket管理（自动重连+心跳）
│   │   │   │   ├── api_client.dart          # REST客户端（JWT认证 + getList方法）
│   │   │   │   ├── protocol.dart            # 消息类型常量
│   │   ├── features/
│   │   │   ├── auth/               # 登录（手机号+短信验证码，role=child）
│   │   │   ├── home/               # 主页：SOS横幅+老人卡片+绑定入口
│   │   │   ├── family/             # 邀请码绑定老人
│   │   │   ├── sos/                # SOS轮询Provider（5秒间隔）
│   │   │   ├── coscreen/           # 共屏（接收帧画面+标注绘制+发送标注到老人端）
│
├── child-miniapp/                  # 微信小程序（子女端，已弃用，保留参考）
│   ├── miniprogram/
│   │   ├── pages/index/            # 主页：SOS横幅+老人列表+绑定
│   │   ├── pages/coscreen/         # 共屏标注（双层Canvas）
│
├── backend/                        # FastAPI + SQLite/PostgreSQL
│   ├── app/
│   │   ├── main.py                 # FastAPI入口（CORS+路由+自动建表）
│   │   ├── core/                   # 配置/安全/数据库
│   │   ├── models/models.py        # ORM模型（User/FamilyLink/SosEvent/AnnotationSession）
│   │   ├── schemas/                # Pydantic模型
│   │   │   ├── user.py             # 含PhoneLoginRequest（支持role参数）
│   │   │   ├── coscreen.py         # child_id可选，服务端自动填充
│   │   ├── api/v1/                 # REST路由
│   │   │   ├── auth.py             # 手机号+微信登录（支持role=elderly/child）
│   │   │   ├── users.py            # 用户信息
│   │   │   ├── family_links.py     # 亲情绑定（邀请码）
│   │   │   ├── sos.py              # SOS求助
│   │   │   ├── coscreen.py         # 共屏会话（/pending按角色过滤）
│   │   │   ├── websocket.py        # WebSocket端点+消息路由
│   │   ├── ws/                     # WebSocket处理
│   │   │   ├── connection_manager.py    # 连接注册+会话匹配+消息转发
│   │   │   ├── annotation_relay.py      # 标注消息转发+状态记录
│   │   │   ├── frame_relay.py           # 帧统计+流控+ACK处理
│   │   │   ├── sos_handler.py           # SOS推送通知
│   │   ├── utils/
│   │   │   ├── sms_notify.py       # 短信通知（开发期mock，验证码1234）
│   │   │   ├── wechat_login.py     # 微信code→openid（开发期mock）
│   ├── requirements.txt
│   ├── docker-compose.yml          # PostgreSQL + Redis + 后端
│   ├── Dockerfile
│   ├── .env.example
```

## 架构设计

### 老人端：Flutter ↔ Kotlin Platform Channel

| Channel名 | 类型 | 方向 | 用途 |
|-----------|------|------|------|
| `overlay_service` | MethodChannel | Dart→Kotlin | SOS浮窗显示/隐藏/权限检查 |
| `overlay_service` | MethodChannel | Kotlin→Dart | SOS按钮点击回调（反向调用） |
| `screen_capture` | MethodChannel+EventChannel | 双向 | 屏幕采集启动/停止 + JPEG帧流 |
| `annotation_overlay` | MethodChannel | Dart→Kotlin | 标注渲染（箭头/圆圈/高亮/文字） |
| `phone_call` | MethodChannel | Dart→Kotlin | 直接拨打子女电话 |

### 子女端：Flutter App（无原生服务）

子女端为纯 Flutter 应用，不需要 Kotlin 原生服务（无屏幕采集、无悬浮窗、无 Overlay）。共屏功能通过 WebSocket 接收帧画面并用 `Image.memory` 渲染，标注通过 `GestureDetector` + `CustomPaint` 实现本地绘制并发送到老人端。

### 关键架构决策

- **SOS浮窗用原生XML布局**，不跑第二个FlutterEngine（省30-50MB内存，低端老人手机扛不住）
- **标注渲染用原生Overlay画布**，`TYPE_APPLICATION_OVERLAY` 窗口确保标注在所有App之上可见，`FLAG_NOT_TOUCHABLE` 确保不阻挡老人操作
- **屏幕采集用JPEG帧（2fps）**，不用H.264视频流（兼容性好、开发简单、约100KB/s带宽）
- **标注坐标归一化（0.0-1.0）**，老人端渲染时乘以屏幕尺寸还原像素，确保不同分辨率下标注位置一致
- **子女端用独立Flutter App**而非微信小程序，支持后台SOS轮询、通知权限、更好的共屏体验
- **登录角色区分**，同一套手机号+短信登录API，通过 `role` 参数区分 `elderly` / `child`

### WebSocket 协议

所有消息JSON格式，统一 `type` 字段路由：

```json
{ "type": "<消息类型>", "session_id": "<uuid>", "timestamp": "<ISO8601>", "payload": { ... } }
```

| 消息类型 | 发送方 | 用途 |
|---------|--------|------|
| `session.join` | 老人/子女 | 加入共屏会话 |
| `session.ready` | 后端 | 双方已连接 |
| `session.end` | 任一方 | 结束会话 |
| `frame.screen` | 老人端 | 屏幕帧（base64 JPEG） |
| `frame.ack` | 子女端 | 帧确认（流控） |
| `annotation.start` | 子女端 | 开始绘制标注（含id/tool/color） |
| `annotation.stroke` | 子女端 | 标注笔画增量点（归一化坐标） |
| `annotation.end` | 子女端 | 完成标注 |
| `annotation.clear` | 子女端 | 清除指定标注 |
| `annotation.clear_all` | 子女端 | 清除所有标注 |
| `sos.alert` | 老人端 | SOS求助 |
| `sos.accept` | 子女端 | 接受SOS |
| `sos.cancel` | 老人端 | 取消SOS |
| `heartbeat.ping/pong` | 双方 | 保活（30s间隔） |

## 后端 API

**Base**: `/api/v1`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/login/phone` | 手机号+短信验证码登录（支持 `role` 参数：elderly/child） |
| POST | `/auth/login/wechat` | 微信openid登录 |
| POST | `/auth/sms/send` | 发送短信验证码 |
| POST | `/auth/refresh` | 刷新JWT |
| GET/PUT | `/users/me` | 用户信息 |
| POST | `/family-links/request` | 创建绑定请求（邀请码或手机号） |
| PUT | `/family-links/{id}/accept` | 接受绑定 |
| GET | `/family-links` | 绑定列表 |
| POST | `/sos/alert` | 发起SOS |
| PUT | `/sos/{id}/accept` | 接受SOS |
| PUT | `/sos/{id}/cancel` | 取消SOS |
| GET | `/sos/history` | SOS历史记录 |
| POST | `/coscreen/session` | 创建共屏会话（`child_id` 可选，服务端自动填充当前用户） |
| GET | `/coscreen/pending` | 待处理会话（按当前用户角色自动过滤） |
| GET | `/coscreen/session/{id}` | 会话状态 |
| PUT | `/coscreen/session/{id}/end` | 结束会话 |
| WS | `/ws/coscreen/{session_id}?token=<jwt>` | WebSocket端点 |

## 快速开始

### 后端

```bash
cd backend
pip install -r requirements.txt
# 开发期使用SQLite，无需额外配置数据库
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

开发期短信验证码固定为 `1234`，微信登录为 mock 模式。

### 老人端（Flutter）

```bash
cd elderly_app
flutter pub get
export JAVA_HOME="C:/Program Files/Android/Android Studio1/jbr"  # Windows
flutter run
```

需要在 Android 设备上运行（屏幕采集、浮窗等功能依赖 Android API）。

### 子女端（Flutter）

```bash
cd child_app
flutter pub get
export JAVA_HOME="C:/Program Files/Android/Android Studio1/jbr"  # Windows
flutter run
```

需要在 Android 设备上运行（与老人端共用同一模拟器或真机）。

### 子女端（微信小程序，已弃用）

用微信开发者工具打开 `child-miniapp` 目录。此版本已被 Flutter 子女端 App 替代，保留仅供参考。

## 端到端流程

### SOS 求助流程

1. 老人点击 SOS 悬浮按钮 → Kotlin 原生服务通过反向 MethodChannel 调用 Flutter
2. Flutter 调用 `POST /sos/alert` → 后端创建 SOS 事件并推送 WebSocket 通知
3. 子女端 5 秒轮询 `GET /sos/history?limit=1` → 检测到 `status=alerting`
4. 首页显示红色 SOS 横幅 → 子女点击"接受求助" → `PUT /sos/{id}/accept`
5. 接受后自动跳转共屏页面

### 共屏标注流程

1. 子女点击老人卡片的"共屏指引" → `POST /coscreen/session` → 创建 pending 会话
2. 老人端轮询 `GET /coscreen/pending` → 弹窗询问是否接受
3. 老人接受 → 双方 WebSocket 连接 → 老人端启动 MediaProjection 屏幕采集
4. 老人端将 JPEG 帧 base64 编码后通过 WebSocket 发送
5. 子女端 `Image.memory` 渲染帧画面，`GestureDetector` 捕获标注手势
6. 标注坐标归一化后通过 WebSocket 发送到老人端
7. 老人端原生 Overlay 服务渲染标注（10秒自动淡出）

## 技术栈

| 组件 | 技术 |
|------|------|
| 老人端 | Flutter + Kotlin (Platform Channel) |
| 子女端 | Flutter（纯 Dart，无原生服务） |
| 后端 | FastAPI + SQLite(开发) / PostgreSQL(生产) |
| 实时通信 | WebSocket |
| 认证 | JWT（手机号+短信，支持 elderly/child 角色） |
| 屏幕采集 | Android MediaProjection API |
| 浮窗/标注 | Android TYPE_APPLICATION_OVERLAY |
| 适老化UI | 28sp标题 / 22sp正文 / 56sp按钮 / 高对比色 / 暖黄背景 |

## 开发进度

### Week 1 (已完成)
- 后端骨架 + JWT认证 + 短信mock + 微信mock
- Flutter适老化主题 + 登录页 + 主页
- SOS原生浮窗服务（72dp红色圆圈、拖拽、前台服务）
- Flutter SOS集成 + 权限引导页
- 小程序骨架 + SOS接收页

### Week 2 (已完成)
- 屏幕采集原生服务（MediaProjection + 2fps JPEG帧）
- Flutter屏幕采集→WebSocket帧推送集成
- 后端WebSocket消息路由 + 帧转发 + 标注转发 + 心跳
- 小程序共屏标注页（双层Canvas + 标注工具栏）
- 老人端标注渲染Overlay（原生Canvas + 归一化坐标 + 10秒淡出）
- 三端端到端协议对齐（annotation id、坐标归一化、canvas尺寸）

### Week 3 (已完成)
- 子女端 Flutter App 替代微信小程序（蓝色主题、手机号+短信登录）
- 子女端首页：SOS横幅+老人卡片+邀请码绑定
- 子女端共屏：接收帧画面+标注绘制+发送标注到老人端
- 后端 auth 支持 role 参数（elderly/child）
- 后端 coscreen /pending 按角色过滤、session 创建 child_id 自动填充
- SOS 反向 MethodChannel（Kotlin→Dart）+ 后端 API 调用
- 老人端共屏请求监听（轮询 /pending + 接受弹窗）
- Android 16 (API 36) 兼容性修复

### Week 4 (进行中)
- WebSocket 断线重连韧性
- 帧率自适应带宽
- 标注UX打磨（撤销、延迟优化）
- 错误处理+日志+加载状态
- 通知权限申请（Android 13+）
- 网络异常提示+自动重连

### Week 5 (待开始)
- 生产部署（Docker化 + PostgreSQL + Redis背板）
- Android APK签名构建
- 安全审查
- Demo录制

## 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| MediaProjection授权弹窗老人不理解 | 预教育页面大字解释"允许子女看到屏幕来帮您" |
| OEM省电模式杀掉浮窗服务 | 电池优化豁免列表 + START_STICKY自动重启 |
| 标注Overlay阻挡老人操作 | FLAG_NOT_TOUCHABLE确保触摸穿透 |
| 网络延迟 | 帧率自适应RTT，低网速自动降帧 |
| Android 16 前台服务权限 | 声明 FOREGROUND_SERVICE_SPECIAL_USE 等必要权限 |

## 验证方式

1. **SOS流程**：老人按SOS → 后端收到 → 子女端 App 弹出红色横幅 → 接受 → 老人端状态变更
2. **共屏流程**：子女发起 → 老人授权 → 帧流到子女端 → 子女画箭头 → 老人屏幕出现箭头
3. **跨App测试**：老人在微信/美团/设置等不同App中操作时，标注正确显示在对应App之上
4. **网络韧性**：切换WiFi/4G时WebSocket自动重连
5. **边缘测试**：3台不同OEM设备（旗舰/中端/低端） + 权限拒绝场景
6. **双角色测试**：同一手机号不能同时登录老人端和子女端（不同手机号+不同role）
#   s i l v e r h a i r - c o p i l o t  
 
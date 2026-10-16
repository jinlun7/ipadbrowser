# PadBrowser 功能矩阵与桌面级体验差距分析 (Gap Analysis)

生成时间：2026-10-16  
基准定位：现代桌面级浏览器体验标准（macOS Safari / 桌面级多工作区浏览器）与 PadBrowser 当前实现状态比对。  
分析方法：基于代码符号级检测与架构实际核查。

---

## 一、当前工程指标

| 指标项 | 状态 / 数据 |
|---|---|
| **代码规模** | 30 个 Swift 源文件 / 5,421 行代码 |
| **语言规范** | Swift 6.0 现代并发与严格模式 |
| **核心技术栈** | SwiftUI、Observation 响应式框架、WebKit 原生技术栈、AuthenticationServices |
| **工程配置** | `TARGETED_DEVICE_FAMILY = 2`（iPad 独占）、部署目标 `iPadOS 18.0+` |
| **状态架构** | 集中式状态根 + 细粒度 `TabRuntime` 隔离 + 独立功能模块服务单例 |

---

## 二、能力覆盖全景

### 1. 浏览地基（Core Browsing Engine）

| 能力 | 状态 | 证据 / 说明 |
|---|---|---|
| 桌面版网页渲染 | ✅ 已具备 | `BrowserWebView.swift`：`preferredContentMode = .desktop` |
| 桌面级 User-Agent | ✅ 已具备 | `BrowserWebView.swift`：补齐 Safari 18.2 桌面签名，解决各大站点移动端误报 |
| 多空间（Spaces）系统 | ✅ 已具备 | `BrowserStore.swift`：按 `spaceID` 隔离标签、文件夹与固定站点 |
| 无痕空间物理隔离池 | ✅ 已具备 | `IncognitoDataStorePool.swift`：每个无痕空间维护独立 `nonPersistent()` 容器，销毁时数据全清 |
| Jetsam 崩溃自动恢复 | ✅ 已具备 | `WebContainer.swift`：捕获 `webViewWebContentProcessDidTerminate` 并结合滚动快照状态恢复 |
| 常驻活跃标签内存池 | ✅ 已具备 | `WebSurface.swift`：遵循 `maxResidentTabs`（4/8/12/16）进行 LRU 调度与回收 |
| 媒体播放用户手势保护 | ✅ 已具备 | `BrowserWebView.swift`：限制自动播放有声媒体，防后台发声 |
| 画中画与全屏元素 | ✅ 已具备 | `BrowserWebView.swift`：`allowsPictureInPictureMediaPlayback = true` |
| HTTP 基础/摘要认证 | ✅ 已具备 | `WebContainer.swift`：处理 `URLAuthenticationChallenge`，支持系统身份认证弹窗 |

### 2. 界面与交互系统（UI & Desktop Ergonomics）

| 能力 | 状态 | 说明 |
|---|---|---|
| 下沉式侧边栏（垂直标签） | ✅ 已具备 | `SidebarView.swift`：层级文件夹、可折叠管理，纯垂直标签模式最大化释放纵向高度 |
| 侧边栏拖拽调宽 | ✅ 已具备 | `SidebarResizeDivider.swift`：支持 220pt ~ 420pt 自由拖拽调宽 |
| 横向标签条（拖拽重排） | ✅ 已具备 | `TabStripView.swift`：经典横向标签条，支持手指与触控板拖拽重排标签 |
| 标签显示模式切换 | ✅ 已具备 | `SettingsStore.swift`：纯垂直标签（推荐）、智能联动、经典横向条三模切换 |
| 桌面级起始页 | ✅ 已具备 | `StartPageView.swift`：集成快速搜索、固定站点网格与最近书签 |
| 快捷书签栏 | ✅ 已具备 | `BookmarkBar.swift`：快速访问横栏，快捷键 <kbd>⌘⇧B</kbd> 切换 |
| 悬浮卡片美学 | ✅ 已具备 | `RootView.swift`：24pt Apple 连续超椭圆圆角（Continuous Corner Radius） |
| Liquid Glass 兼容层 | ✅ 已具备 | `LiquidGlass.swift`：iPadOS 26+ `glassEffect` 原生特性与 iPadOS 18+ `.ultraThinMaterial` 降级 |
| 快捷键体系 | ✅ 已具备 | `BrowserCommands.swift`：iPadOS 兼容的 `CommandMenu`，覆盖 15+ 常用快捷键 |
| 页面比例缩放 | ✅ 已具备 | `SettingsStore.swift`：支持 50% ~ 200% 页面级缩放，对应 <kbd>⌘+</kbd> / <kbd>⌘-</kbd> / <kbd>⌘0</kbd> |

### 3. 隐私与安全增强（Privacy & Security）

| 能力 | 状态 | 说明 |
|---|---|---|
| 内核级广告/追踪拦截 | ✅ **已实现** | `ContentBlockerManager.swift`：利用 WebKit 原生 `WKContentRuleList` 在内核底层进行拦截与 CSS display-none 样式净化，零第三方依赖 |
| 原生钥匙串密码填充 | ✅ **已实现** | `PasswordAutofillHelper.swift`：集成 `AuthenticationServices`，支持 Face ID / Touch ID 生物认证后安全注入 DOM 表单 |
| 用户脚本注入调度 | ✅ 已具备 | `UserScriptBridge.swift`：封装 `WKUserScript`，在 `atDocumentStart` / `atDocumentEnd` 阶段调度注入 |
| 脚本规则与匹配 | ✅ 已具备 | `UserScriptStore.swift`：支持 Tampermonkey 风格的 `@match` 动态域名匹配 |
| 书签系统与 HTML 导入 | ✅ 已具备 | `BookmarkStore.swift`：支持完整 Netscape Bookmark HTML 导入解析，自动去除循环与归一化 |
| 用户脚本管理 UI | ⚠️ 待补充 | 已具备后台 Store 与 Bridge 注入能力，目前缺少前台添加/编辑 `.user.js` 的用户界面 |
| Passkey 凭据支持 | ❌ 未实现 | 可通过 `ASAuthorizationPlatformPublicKeyCredentialProvider` 进一步支持 |
| 标准 Web Extension | ❌ 未实现 | 依赖 iPadOS 18.4+ 的 `WKWebExtensionController`，未集成 `.crx` / `.zip` 导入管线 |

### 4. 深度内容消费与生产力层（Content Processing）—— 当前主要差距

| 能力 | 状态 | 演进建议 |
|---|---|---|
| 沉浸式阅读模式 | ❌ 未实现 | 提取正文主体，纯文本/安全 DOM 重排渲染，支持字号与排版主题调整 |
| PencilKit 手写与网页批注 | ❌ 未实现 | 基于系统 `PencilKit` 画布悬浮层，支持在网页上直接批改并导出 |
| 整页长截图 | ❌ 未实现 | 利用 `WKWebView.takeSnapshot` 实现全文档高度长图拼接 |
| 整页长 PDF 导出 | ❌ 未实现 | 利用 `WKWebView.createPDF` 生成标准可交互矢量 PDF |
| 媒体视图（Media Inspector） | ❌ 未实现 | 类似桌面审查工具，自动提取当前页面高分辨率图片与视频瀑布流 |
| Markdown 网页导出 | ❌ 未实现 | 将页面正文内容安全转译为结构化 Markdown 笔记 |

### 5. 云端与进阶协同（Advanced Services）

| 能力 | 状态 | 说明 |
|---|---|---|
| iCloud 云同步与备份 | ❌ 未实现 | 依赖付费 Apple Developer 开发者账号与 iCloud Container 权限 |
| 划词系统翻译 | ❌ 未实现 | 可基于 iOS 17.4+ 的 `Translation` 框架轻量接入 |
| 网页变动监控 | ❌ 未实现 | 依赖后台任务 `BGTaskScheduler` 离线抓取对比 |
| AI 侧边栏/摘要助手 | ❌ 未实现 | 可作为可选扩展能力，接入主流 LLM API |

---

## 三、架构状态机与组件拓扑

PadBrowser 目前采用模块化状态设计，包含 5 个核心 Store 与 4 个核心能力服务：

```
[Store 状态驱动层]
├── BrowserStore          # 标签、空间、运行时状态与聚焦驱动
├── PersistenceStore      # JSON 会话冷启动恢复与落盘
├── SettingsStore         # UserDefaults 偏好设置
├── BookmarkStore         # 树状书签存储与 HTML 解析
└── CredentialStore       # 搜索引擎与 HTTP 认证凭据缓存

[核心能力服务 (Singletons)]
├── ContentBlockerManager # 原生广告拦截规则编译与动态挂载
├── IncognitoDataStorePool# 独立无痕 DataStore 容器池管理
├── PasswordAutofillHelper# 系统钥匙串与生物认证表单注入
└── UserScriptBridge      # 用户脚本挂载与消息桥
```

---

## 四、下一步演进路线建议

按「用户感知价值 × 实现投入」排序：

### 阶段一：扩展与内容交互闭环（P1）
1. **用户脚本管理界面**：为已有的 `UserScriptStore` 补充配置视图，支持直接粘贴 URL 或导入本地 `.user.js` 文件。
2. **沉浸式阅读模式（Reader View）**：
   - 提取正文主体（遵循安全沙盒原则，不执行抽取内容中的内联脚本）。
   - 提供简洁无干扰的排版界面与暗色背景模式。

### 阶段二：生产力导出与批注套件（P2）
1. **整页 PDF / 长截图导出**：调用 WebKit 原生 PDF / 快照生成 API，接入系统分享面板。
2. **PencilKit 手写批注**：为全屏网页引入透明涂鸦层，支持在网页上直接手写涂鸦与归档。

### 阶段三：现代扩展标准（P3）
1. **Web Extension 支持**：部署目标升级至 iPadOS 18.4+，通过 `WKWebExtensionController` 支持标准浏览器插件体系。

# PadBrowser

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2018.0+-007AFF?style=flat-square&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Observation-0055FF?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Target-iPad%20Only-teal?style=flat-square" alt="iPad Only" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

<p align="center">
  <strong>专为 iPad 大屏、妙控键盘与触控板打造的桌面级原生 Web 浏览器</strong>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <strong>简体中文</strong> •
  <a href="README_JA.md">日本語</a>
</p>

---

## 项目概述

现代 iPad 拥有高性能 Apple Silicon 芯片、高刷新率 Liquid Retina 屏幕以及外接键盘触控板等生产力硬件。然而，常规移动端浏览器在 iPad 上的交互往往局限于放大的移动端视口、拥挤的横向标签栏以及不完备的快捷键支持。

**PadBrowser** 采用 Swift 6 与 SwiftUI 原生开发，从底层架构出发重新设计 iPadOS 浏览体验。项目通过桌面级 WebKit 排版渲染、多空间工作区隔离、下沉式垂直标签系统、内核级网络过滤规则以及完整的硬件快捷键映射，为 iPad 提供稳定、纯净且高效的桌面级浏览环境。

---

## 核心特性

### 1. 原生桌面级 WebKit 引擎
- **桌面视口排版**：默认配置 `preferredContentMode = .desktop`，使 GitHub、Figma、Notion 等复杂 Web 应用程序完整呈现桌面端布局与功能。
- **完整的 Safari 桌面 UA 契约**：内建完整 macOS Safari Desktop User-Agent 签名，消除网站因移动标识引发的排版降级或“不支持的浏览器版本”提示。
- **媒体增强与画中画**：支持原生 HTML5 画中画（PiP）、元素全屏及行内播放，并对有声媒体实施自动播放限制，避免后台静默发声。
- **无线开发者检查器**：默认启用 `isInspectable = true`，支持通过 Mac 端 Safari 开发者工具远程审查与调试 iPad 页面 DOM 及网络请求。

### 2. 工作区空间（Spaces）与层级标签管理
- **多空间工作区**：支持创建相互独立的工作区（如“工程开发”、“深度调研”、“日常阅读”）。每个空间具备自闭环的标签树、嵌套文件夹与固定站点（Pinned Sites）。
- **物理级无痕空间隔离**：基于 `IncognitoDataStorePool` 为每个无痕空间分配独立的内存型 `WKWebsiteDataStore.nonPersistent()` 实例。同一无痕空间内保持会话连贯，跨空间严格物理隔离，且退出后数据即刻销毁。
- **下沉式侧边栏（垂直标签）**：支持 220 pt 至 420 pt 自由拖拽调宽，支持标签拖拽归类与无限嵌套文件夹，最大化保留网页纵向有效阅读区域。
- **双模标签形态**：保留经典横向标签条，支持触控板与手指拖拽平滑重排，可根据习惯随时切换。
- **现代桌面起始页**：集成聚合搜索、固定站点网格与最近书签，采用超椭圆悬浮卡片设计。

### 3. 内核级隐私保护与系统协同
- **原生规则编译与拦截**：采用 WebKit 原生 `WKContentRuleList` 在网络加载层直接过滤追踪器与广告域名，配合 CSS 选择器做版面净化，零第三方框架依赖，极低内存与 CPU 负载。
- **系统钥匙串密码填充**：集成 iPadOS `AuthenticationServices`（`ASAuthorizationPasswordProvider`），支持通过 Face ID / Touch ID 生物认证快速调取系统 iCloud 钥匙串并安全回填表单。
- **用户脚本通道（Userscript）**：内建轻量脚本加载系统，支持 Tampermonkey 风格的 `@match` 规则在页面加载周期（`atDocumentStart` / `atDocumentEnd`）安全注入。
- **通用书签导入**：支持标准 Netscape Bookmark HTML 格式解析，可完整导入主流桌面浏览器的多层级书签树并自动纠偏实体字符。

### 4. 键盘与触控板优先设计
- **完整快捷键映射**：内建 15+ 常用 macOS 标准快捷键（新建、关闭、恢复、历史回退、标签快速直达、页面缩放等）。
- **命令面板（<kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd>）**：类似专业效率工具的全局指令中心，支持全键盘过滤动作、执行命令或直达网址。
- **触控板边缘手势**：支持双指边缘滑动手势导航（后退 / 前进），具备平滑的惯性与边界回弹曲线。

### 5. 遵循 Apple HIG 的视觉质感
- **超椭圆悬浮画布**：主网页卡片采用匹配 iPad 物理显示屏弧度的 24 pt 连续超椭圆圆角（Continuous Corner Radius），配合细边框与柔和投影。
- **Liquid Glass 兼容层**：设计跨版本外观抽象层，在 iPadOS 26+ 环境下自动呈现原生 `glassEffect`，在 iPadOS 18 环境下平滑降级至 `.ultraThinMaterial`。
- **沉浸式全屏选项**：支持隐藏顶部系统状态栏，使网页内容充分延伸至屏幕边缘。

---

## 架构设计与工程亮点

PadBrowser 遵循单向数据流与细粒度响应式架构：

```text
PadBrowser/
├── PadBrowserApp.swift                # App 入口与场景级 Store 依赖注入
├── Models/                            # 领域实体模型
│   ├── BrowserTab.swift               # 标签页数据模型（UUID、URL、滚动偏移快照）
│   ├── BrowserSpace.swift             # 空间系统、文件夹层级与固定站点
│   └── Bookmark.swift                 # 树状书签模型与 Netscape HTML 解析器
├── Stores/                            # 状态驱动中心（SwiftUI Observation）
│   ├── BrowserStore.swift             # 全局状态根，细粒度 TabRuntime 隔离
│   ├── PersistenceStore.swift         # JSON 会话持久化与冷启动数据恢复
│   ├── SettingsStore.swift            # 基于 UserDefaults 的偏好配置
│   ├── BookmarkStore.swift            # 书签集合管理
│   └── CredentialStore.swift          # 搜索引擎定义与 HTTP 认证凭据缓存
├── Web/                               # WebKit 核心交互层
│   ├── BrowserWebView.swift           # WKWebView 定制子类（桌面 UA、PiP 等）
│   ├── WebContainer.swift             # UIViewRepresentable 容器桥与 Coordinator
│   ├── ContentBlockerManager.swift    # WKContentRuleList 规则编译与挂载引擎
│   ├── IncognitoDataStorePool.swift   # 非持久化数据存储分配池
│   ├── PasswordAutofillHelper.swift   # 系统钥匙串表单安全注入辅助器
│   ├── UserScriptBridge.swift         # 用户脚本装载与通信桥
│   └── UserScriptStore.swift          # 用户脚本内存仓库
├── Commands/                          # 快捷键系统
│   └── BrowserCommands.swift          # 基于 CommandMenu 的全平台桌面键盘映射
└── Views/                             # 界面呈现层
    ├── RootView.swift                 # 侧边栏与圆角主画布总体布局
    ├── WebSurface.swift               # WebView 挂载调度、常驻池管理与崩溃自愈
    ├── StartPageView.swift            # 现代桌面起始页
    ├── TabStripView.swift             # 横向标签条
    ├── Sidebar/                       # 空间切换、调宽分割线与垂直标签列表
    ├── Toolbar/                       # 智能地址栏（Omnibox）、导航操作与命令面板
    ├── Settings/                      # 偏好设置面板
    └── Compatibility/                 # Liquid Glass 视觉材质兼容封装
```

### 工程实现要点
1. **细粒度状态隔离（渲染性能保障）**：将网页加载进度、加载态及导航状态隔离于独立的 `@Observable class TabRuntime` 实例中，避免高频进度更新触发整个 `BrowserStore` 和视图树的重绘。
2. **WebKit 实例生命周期管理**：在 `WebContainer.dismantleUIView` 与 `Coordinator.deinit` 中显式卸载代理、终止加载并注销观察者，杜绝长期运行导致的内存泄漏。
3. **Jetsam 进程崩溃自愈**：捕获 WebKit 渲染进程异常终止事件（`webViewWebContentProcessDidTerminate`），结合最后一次保存的滚动偏移快照，实现无感知静默重建。
4. **常驻活跃标签内存池**：内置 LRU 标签调度池（支持设置 4 至 16 个常驻上限），在低内存 iPad 设备上平衡标签切换响应性与系统内存压力。

---

## 常用快捷键速查

| 快捷键 | 功能描述 |
|---|---|
| <kbd>⌘</kbd> + <kbd>T</kbd> | 新建标签页 |
| <kbd>⌘</kbd> + <kbd>W</kbd> | 关闭当前标签页 |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>W</kbd> | 关闭其他所有标签页 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>N</kbd> | 新建无痕空间标签页 |
| <kbd>⌘</kbd> + <kbd>L</kbd> | 聚焦地址栏（可直接输入搜索或网址） |
| <kbd>⌘</kbd> + <kbd>R</kbd> | 重新加载当前页面 |
| <kbd>⌘</kbd> + <kbd>[</kbd> / <kbd>]</kbd> | 历史记录后退 / 前进 |
| <kbd>⌘</kbd> + <kbd>1</kbd> ~ <kbd>9</kbd> | 快速切换至第 1 ~ 9 个标签页 |
| <kbd>⌘</kbd> + <kbd>⌃</kbd> + <kbd>S</kbd> | 显示 / 隐藏下沉式侧边栏 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd> | 呼出命令面板（Command Palette） |
| <kbd>⌘</kbd> + <kbd>D</kbd> | 将当前页面添加至书签 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>B</kbd> | 显示 / 隐藏顶部快捷书签栏 |
| <kbd>⌘</kbd> + <kbd>+</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | 放大 / 缩小 / 重置页面缩放比例（50% ~ 200%） |

---

## 编译与运行指南

### 环境要求
- **Xcode**：16.0 或更高版本
- **开发语言**：Swift 6.0
- **目标平台**：iPadOS 18.0+
- **架构要求**：arm64（真机）/ arm64（模拟器）

### 克隆与打开工程
```bash
git clone https://github.com/jinlun7/ipadbrowser.git
cd ipadbrowser
open PadBrowser.xcodeproj
```

### 代码签名配置
1. 在 Xcode 左侧导航栏中选中 `PadBrowser` 项目根节点。
2. 进入 **Signing & Capabilities** 页面。
3. 勾选 **Automatically manage signing**，并在 **Team** 下拉菜单中选择你的 Apple 开发团队（个人免费 Apple ID 亦可直接完成签名）。
4. 连接 iPad 真机或选择 iPadOS 18+ 模拟器（如 `iPad Pro 13-inch (M4)`）。
5. 按下 <kbd>⌘</kbd> + <kbd>R</kbd> 编译并运行。

### 命令行构建（可选）
```bash
xcodebuild -project PadBrowser.xcodeproj \
           -scheme PadBrowser \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           -configuration Debug \
           build
```

---

## 参与贡献

欢迎提交 Issue、功能讨论与 Pull Request。贡献代码时请注意：
1. 保持 Swift 6 严格并发安全检查（Strict Concurrency）。
2. 新增界面组件需在各尺寸 iPad（11 寸、13 寸以及 Split View 分屏模式）下完成布局稳定性验证。
3. 提交 PR 前请在模拟器或真机上确认交互流程正常。

---

## 开源许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

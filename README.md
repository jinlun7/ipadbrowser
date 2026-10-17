# PadBrowser

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2018.0+-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20Observation-0055FF?style=for-the-badge" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Device-iPad%20Only-teal?style=for-the-badge" alt="iPad Only" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <strong>专为 iPad 大屏、妙控键盘与触控板打造的桌面级原生浏览器</strong><br>
  <em>A modern, desktop-class iPadOS web browser engineered for productivity, keyboard-first ergonomics, and deep privacy.</em>
</p>

<p align="center">
  <a href="#-quick-overview-en">English Overview</a> •
  <a href="#-为什么需要-padbrowser">设计初衷</a> •
  <a href="#-核心特性">核心特性</a> •
  <a href="#-界面布局与架构设计">界面布局与架构</a> •
  <a href="#-常用快捷键速查">快捷键指南</a> •
  <a href="#-编译与运行指南">构建指南</a> •
  <a href="#-开源许可证">许可证</a>
</p>

---

## 🌐 Quick Overview (EN)

**PadBrowser** is an open-source, desktop-class web browser built from the ground up exclusively for iPadOS. Unlike conventional iPad browsers that merely scale up iPhone interfaces, PadBrowser unlocks the full computing potential of iPad Pro and Air hardware:

- 🖥️ **True Desktop Web Experience**: Enforces desktop viewport layouts (`preferredContentMode = .desktop`) and Safari macOS User-Agents, completely eliminating mobile redirects and "unsupported browser" warnings.
- 🗂️ **Workspaces (Spaces) & Vertical Tabs**: Arc-inspired workspace organization with nested folders, drag-and-drop tab management, and resizable sunken sidebar (220pt ~ 420pt).
- 🛡️ **Zero-Overhead Ad & Tracker Blocking**: Kernel-level content blocking via native WebKit `WKContentRuleList` with CSS cosmetic filtering.
- 🔒 **Physical Incognito Isolation**: Dedicated `WKWebsiteDataStore.nonPersistent()` pools per private space—cookies and sessions never touch disk and are destroyed on exit.
- ⌨️ **Keyboard & Trackpad First**: 15+ macOS-grade shortcut combinations (⌘T, ⌘W, ⌘L, ⌘1~9, ⌘⇧P Command Palette) and two-finger swipe navigation.
- 🎨 **Apple HIG Liquid Glass Aesthetic**: 24pt continuous corner radius matching iPad physical displays, with seamless forward-compatibility for iPadOS 26+ `glassEffect` and iOS 18 `.ultraThinMaterial`.

---

## 💡 为什么需要 PadBrowser？

iPad 已经拥有了强大的 M 系列桌面级芯片、绝佳的 Liquid Retina 高刷屏，以及堪比笔记本的妙控键盘与触控板。然而，绝大多数 iPad 上的浏览器依然只是**“放大版 iPhone 浏览器”**：

| 痛点场景 | 传统移动/平板浏览器 | PadBrowser 桌面级体验 |
|---|---|---|
| **复杂 Web 应用访问** | 经常被强制降级至排版拥挤的移动版网页 | **100% 完整桌面版排版**，全功能运行 GitHub、Figma、Notion、Bilibili 等 |
| **纵向屏幕空间浪费** | 顶部横向标签栏 + 书签栏 + 状态栏，吃掉近 1/4 高度 | **纯垂直标签侧边栏**（可折叠隐藏），全屏纵向空间完整留给网页主体 |
| **多任务与上下文切换** | 所有标签混在一起，工作与个人浏览杂乱无章 | **多空间（Spaces）工作区**，工作、生活、无痕标签与固定站点物理隔离 |
| **无痕浏览隐私保障** | 多个无痕标签共享全局临时容器，隔离并不彻底 | **独立 DataStore 容器池**，按空间物理级隔离 Cookie 与 LocalStorage |
| **键盘与触控板协同** | 依赖手指点击，快捷键残缺不全 | **全键盘快捷键体系（⌘T/W/L/R/1-9）** 与 ⌘⇧P 命令中心，手指不离键盘 |

---

## ✨ 核心特性详解

### 🖥️ 1. 原生桌面级排版与 WebKit 深度调优
- **强制桌面排版**：全面开启 `preferredContentMode = .desktop`，网页直接按照桌面显示器视口规则排版渲染。
- **Safari 桌面级 UA 签名**：内建完整 Safari macOS Desktop User-Agent 签名，彻底解决大型网站因缺少平台版本号报错“浏览器内核版本过低”的问题。
- **画中画与后台防扰**：开启 HTML5 原生画中画（PiP）支持，并限制后台未获用户手势的媒体自动出声。
- **开发者检查器**：支持 `isInspectable = true`，随时通过 Mac Safari 开发者菜单无线审查 iPad 上的页面 DOM 与控制台。

### 🗂️ 2. 空间（Spaces）与多维标签管理
- **独立工作区空间**：可自由创建「工作」、「开发」、「阅读」、「个人」等独立空间，每个空间拥有自闭环的标签列表与收藏夹。
- **硬隔离无痕空间**：基于 `IncognitoDataStorePool` 维护独立的内存型 `WKWebsiteDataStore` 容器，同一无痕空间内共享登录会话，跨空间严格物理隔离，关闭即彻底销毁。
- **纯垂直标签侧边栏**：下沉式侧边栏设计，支持 220pt ~ 420pt 自由拖拽调宽，支持无限嵌套文件夹与标签拖拽归类。
- **经典横向标签条支持**：保留经典横向标签模式，支持触控板与手指拖拽平滑重排。
- **桌面起始页**：集成搜索、快速访问固定站点与最近书签，采用层次化的现代超椭圆悬浮卡片设计。

### 🛡️ 3. 内核级隐私防护与系统级效率工具
- **WebKit 原生规则拦截**：基于 `WKContentRuleList` 底层预编译规则在网络加载阶段拦截高频广告与追踪器，配合 CSS 规则净化页面布局，零外部第三方框架依赖，极低内存与 CPU 负载。
- **系统钥匙串密码填充**：深度集成 iPadOS `AuthenticationServices`，支持 Face ID / Touch ID 生物识别快速调取 iCloud 钥匙串，安全注入表单凭据。
- **用户脚本引擎（Userscript）**：内建轻量用户脚本加载通道，支持 Tampermonkey 风格的 `@match` 规则在页面加载起始阶段（AtDocumentStart / AtDocumentEnd）注入增强脚本。
- **书签批量导入**：支持 Netscape Bookmark HTML 规范，可无缝将 Chrome、Safari、Edge 等主流浏览器的书签树一键导入。

### ⌨️ 4. 键盘触控板优先（Keyboard-First）
- **完整快捷键映射**：支持 15+ 常用 macOS 级别组合键（新建、关闭、后退、前进、快速聚焦、1~9 标签直达、页面缩放等）。
- **命令面板（⌘⇧P）**：类似 Raycast / Spotlight 的全键盘呼出指令中心，可快速过滤操作、执行命令或直达网址。
- **触控板双向手势**：支持边缘两指平滑滑动手势导航（前进/后退）及精准滚动惯性回弹。

---

## 📐 界面布局与架构设计

### 界面拓扑示意

```text
┌────────────────────────────────────────────────────────────────────────┐
│ ⌘⇧P 命令面板 │ 后退/前进 │ 智能地址栏 (⌘L) │ 书签栏 (⌘⇧B) │ 页面缩放 │ 设置 │
├─────────────────────────┬──────────────────────────────────────────────┤
│ 空间切换 (Spaces)       │                                              │
│ ├── 💼 工作空间         │             桌面级网页主画布 (Canvas)         │
│ ├── 🏠 个人日常         │         (24pt 连续超椭圆圆角 + 悬浮阴影)      │
│ └── 🛡️ 隔离无痕         │                                              │
│                         │   • 强制 preferredContentMode = .desktop     │
│ 垂直标签列表 (可拖拽调宽)│   • WebKit 原生 WKContentRuleList 广告拦截   │
│ ├── 📁 待读文件夹       │   • AuthenticationServices 钥匙串生物认证     │
│ ├── 📄 GitHub PR Review │   • 细粒度 TabRuntime 驱动，页面进度无卡顿   │
│ └── 📄 Figma Document   │   • Jetsam 进程崩溃自动捕获与无缝状态恢复     │
└─────────────────────────┴──────────────────────────────────────────────┘
```

### 目录与核心模块

```
ipadbrowser/
├── PadBrowserApp.swift                # App 入口与场景级状态机根注入
├── Models/                            # 核心业务实体模型
│   ├── BrowserTab.swift               # 标签页模型（UUID、URL、滚动偏移快照）
│   ├── BrowserSpace.swift             # 空间系统、文件夹与固定站点
│   └── Bookmark.swift                 # 树状书签模型与 Netscape HTML 解析器
├── Stores/                            # Observation 响应式驱动中心
│   ├── BrowserStore.swift             # 全局状态根，细粒度 TabRuntime 隔离
│   ├── PersistenceStore.swift         # JSON 会话冷启动恢复与落盘
│   ├── SettingsStore.swift            # 13+ 项外观/行为偏好（UserDefaults）
│   ├── BookmarkStore.swift            # 书签层级树维护
│   └── CredentialStore.swift          # 搜索引擎定义与 HTTP 认证凭据管理
├── Web/                               # WebKit 核心引擎层
│   ├── BrowserWebView.swift           # WKWebView 定制子类（桌面 UA、PiP 等）
│   ├── WebContainer.swift             # UIViewRepresentable 容器与 Coordinator
│   ├── ContentBlockerManager.swift    # WKContentRuleList 内核广告拦截
│   ├── IncognitoDataStorePool.swift   # 无痕空间数据存储隔离池
│   ├── PasswordAutofillHelper.swift   # 系统钥匙串与生物认证表单注入
│   ├── UserScriptBridge.swift         # WKUserScript 注入调度与通信桥
│   └── UserScriptStore.swift          # .user.js 规则与脚本存储
├── Commands/                          # 快捷键系统
│   └── BrowserCommands.swift          # iPadOS 兼容的 CommandMenu 桌面组合键响应
└── Views/                             # 现代化 UI 组件群
    ├── RootView.swift                 # 侧边栏 + 圆角主画布总体布局
    ├── WebSurface.swift               # WebView 挂载容器、常驻池调度与崩溃恢复
    ├── StartPageView.swift            # 现代桌面起始页
    ├── TabStripView.swift             # 横向标签条（支持拖拽排序）
    ├── Sidebar/                       # 侧边栏组件（空间切换、调宽分割线、书签）
    ├── Toolbar/                       # 顶部导航工具栏、地址栏与命令面板
    ├── Settings/                      # 偏好设置面板
    └── Compatibility/                 # Liquid Glass 视觉材质兼容封装
```

---

## ⌨️ 常用快捷键速查

| 快捷键 | 功能描述 |
|---|---|
| <kbd>⌘</kbd> + <kbd>T</kbd> | 新建标签页 |
| <kbd>⌘</kbd> + <kbd>W</kbd> | 关闭当前选中的标签页 |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>W</kbd> | 关闭其他所有标签页 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>N</kbd> | 快速新建无痕空间标签页 |
| <kbd>⌘</kbd> + <kbd>L</kbd> | 快速聚焦地址栏（可直接输入搜索或网址） |
| <kbd>⌘</kbd> + <kbd>R</kbd> | 重新加载当前页面 |
| <kbd>⌘</kbd> + <kbd>[</kbd> / <kbd>]</kbd> | 历史记录后退 / 前进 |
| <kbd>⌘</kbd> + <kbd>1</kbd> ~ <kbd>9</kbd> | 快捷切换至第 1 ~ 9 个标签页 |
| <kbd>⌘</kbd> + <kbd>⌃</kbd> + <kbd>S</kbd> | 展开 / 折叠下沉式侧边栏 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd> | 呼出命令面板（Command Palette） |
| <kbd>⌘</kbd> + <kbd>D</kbd> | 将当前页面添加至书签 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>B</kbd> | 显示 / 隐藏顶部快捷书签栏 |
| <kbd>⌘</kbd> + <kbd>+</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | 放大 / 缩小 / 重置页面缩放比例（50% ~ 200%） |

---

## 🚀 编译与运行指南

### 环境要求
- **Xcode**：16.0 或更高版本
- **开发语言**：Swift 6.0
- **目标平台**：iPadOS 18.0+（支持 iPad 实机与 Simulator 模拟器）
- **架构**：arm64 / Simulator arm64

### 1. 克隆代码
```bash
git clone https://github.com/jinlun7/ipadbrowser.git
cd ipadbrowser
```

### 2. 使用 Xcode 打开工程
```bash
open PadBrowser.xcodeproj
```

### 3. 配置代码签名（Signing）
1. 在 Xcode 左侧导航栏中选中根节点 `PadBrowser` project。
2. 切换至 **Signing & Capabilities** 标签页。
3. 勾选 **Automatically manage signing**，在 **Team** 下拉框中选择你的 Apple 开发团队（个人免费 Apple ID 亦可直接签名）。
4. 连接你的 iPad 真机（或在顶部运行设备中选择任一 iPadOS 18+ 模拟器，例如 `iPad Pro 13-inch (M4)`）。
5. 按下 <kbd>⌘</kbd> + <kbd>R</kbd> 编译并安装。

### 4. 命令行构建（可选）
```bash
xcodebuild -project PadBrowser.xcodeproj \
           -scheme PadBrowser \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           -configuration Debug \
           build
```

> **说明**：工程采用了 Xcode 同步根组（Synchronized Root Group）规范，在 `PadBrowser/` 目录内新增或移动 `.swift` 文件会自动纳入编译，无需手动修改工程文件。

---

## 🤝 参与贡献

欢迎提交 Issue、功能提议与 Pull Request！在贡献代码时请遵循：
1. 保持 Swift 6 并发安全范式（Actor 隔离与 Sendable 检查）。
2. 新增视图需确保 iPad 各大尺寸（11寸、13寸、Split View 分屏）下的布局稳健性与触控板手势连贯性。
3. 提交 PR 前请在模拟器与真机上完成完整交互验证。

---

## 📄 开源许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

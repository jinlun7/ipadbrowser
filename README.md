# PadBrowser

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2018.0+-blue?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/Xcode-16.0+-157EFB?style=flat-square&logo=xcode" alt="Xcode" />
  <img src="https://img.shields.io/badge/Device-iPad%20Only-teal?style=flat-square" alt="iPad Only" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

<p align="center">
  <strong>专为 iPad 大屏、妙控键盘与触控板打造的桌面级原生浏览器</strong>
</p>

---

## 📖 项目简介

**PadBrowser** 是一款面向 iPadOS 设计的现代化桌面级网页浏览器。区别于传统将移动端界面简单放大的平板浏览器，PadBrowser 从底层架构到交互细节均深度适配 iPad 的生产力形态——通过原生 WebKit 桌面渲染、多空间工作区隔离、下沉式侧边栏与垂直标签系统、全局键盘快捷键支持以及硬件级隐私隔离，为 iPad 用户提供媲美 macOS 桌面端的专业浏览体验。

---

## ✨ 核心特性

### 🖥️ 桌面级浏览核心
- **原生桌面排版**：强制启用 `preferredContentMode = .desktop`，告别移动版网页的挤压排版，完整呈现桌面级复杂 Web 应用（GitHub、Figma、Notion、Bilibili 等）。
- **优化桌面 User-Agent**：内建完整 Safari Desktop UA 签名，根治大型网站因移动标识误报“浏览器内核版本过低”的问题。
- **媒体增强与画中画**：支持 HTML5 原生画中画（PiP）、全屏元素及行内媒体播放，限制后台静默自动播放，确保纯净的多任务视听体验。
- **开发者检查器**：原生支持 `isInspectable`，可在 Mac Safari 开发者菜单中一键调试 iPad 页面。

### 🗂️ 空间（Spaces）与多维标签管理
- **工作区空间系统**：支持创建多个独立空间（如「工作」、「生活」、「开发」），每个空间拥有独立的标签列表、嵌套文件夹与固定站点（Pinned Sites）。
- **硬隔离无痕空间**：基于独立 `WKWebsiteDataStore.nonPersistent()` 容器池，同一无痕空间内共享会话，不同空间之间物理级隔离 Cookie 与 LocalStorage，退出即销毁。
- **双模标签体系**：
  - **垂直标签侧边栏**：下沉式层级侧边栏，支持拖拽调节宽度（220pt ~ 420pt）与嵌套文件夹管理，彻底解放顶部纵向显示高度。
  - **横向标签条**：支持触控板与手指拖拽自由重排标签，提供平滑的切换动画。
- **智能起始页**：集成搜索、快速访问固定站点以及最近书签，采用层次化的现代卡片设计。

### ⌨️ 键盘与触控板优先（Keyboard-First）
- **完整桌面快捷键映射**：支持 ⌘T（新建标签）、⌘W（关闭标签）、⌘R（刷新）、⌘L（聚焦地址栏）、⌘1~⌘9（快速切标签）、⌘+ / ⌘- / ⌘0（页面缩放）等数十个标准组合键。
- **命令面板（⌘⇧P）**：类似 Spotlight / Raycast 的全键盘呼出指令中心，可快速过滤操作、执行命令或直达网址。
- **触控板双向手势**：支持边缘双向滑动手势导航（前进/后退）及精准滚动惯性回弹。

### 🛡️ 隐私防护与效率工具
- **内核级广告拦截**：基于 WebKit 原生 `WKContentRuleList`，在底层网络加载阶段拦截追踪器与高频广告域名，并结合 CSS 规则做外观净化，极低 CPU 与内存开销。
- **系统钥匙串密码填充**：深度集成 iPadOS `AuthenticationServices`，支持 Face ID / Touch ID 生物认证唤起系统 iCloud 钥匙串并安全注入登录表单。
- **用户脚本引擎（Userscript）**：内建类似 Tampermonkey 的轻量脚本注入系统，支持 `@match` 规则在页面加载起始阶段（AtDocumentStart / AtDocumentEnd）注入增强能力。
- **书签管理与导入**：树状书签结构，支持通用 Netscape Bookmark HTML 规范，可无缝从 Chrome、Safari、Edge 等主流浏览器批量导入书签。

### 🎨 现代 Apple HIG 与设计细节
- **iPad 原生超椭圆卡片**：主画布遵循 iPad 物理屏幕圆角半径（24pt Continuous Corner Radius），配合精致细边框与悬浮投影，呈现优雅的悬浮卡片感。
- **Liquid Glass 兼容层**：采用分层兼容架构，新系统自适应底层 Liquid Glass 玻璃材质（`glassEffect`），旧版本优雅回退至系统材质（`.ultraThinMaterial`），全方位适配深浅色模式与辅助功能对比度偏好。
- **全屏沉浸沉浸式视野**：支持自适应隐藏顶部系统状态栏，将 iPad 宝贵的纵向屏幕空间完整还给网页内容。

---

## 🛠️ 工程与架构设计

PadBrowser 遵循现代 Swift 6.0 与 SwiftUI 范式开发，重构了大量 WebKit 与状态管理的深水区设计：

```
PadBrowser/
├── PadBrowserApp.swift                # App 入口与场景级 Store 注入
├── Models/                            # 数据核心模型
│   ├── BrowserTab.swift               # 标签页模型（UUID、URL、滚动快照等）
│   ├── BrowserSpace.swift             # 空间系统、文件夹与固定站点模型
│   └── Bookmark.swift                 # 书签模型与 Netscape HTML 解析器
├── Stores/                            # 状态驱动中心（SwiftUI Observation）
│   ├── BrowserStore.swift             # 全局状态根，细粒度 TabRuntime 隔离
│   ├── PersistenceStore.swift         # JSON 会话持久化与冷启动恢复
│   ├── SettingsStore.swift            # 13+ 项外观/行为偏好（UserDefaults）
│   ├── BookmarkStore.swift            # 书签层级树维护
│   └── CredentialStore.swift          # 搜索引擎定义与 HTTP 凭据管理
├── Web/                               # WebKit 核心层
│   ├── BrowserWebView.swift           # WKWebView 定制子类（桌面 UA、PiP 等）
│   ├── WebContainer.swift             # UIViewRepresentable 容器与 Coordinator
│   ├── ContentBlockerManager.swift    # WKContentRuleList 内核广告拦截
│   ├── IncognitoDataStorePool.swift   # 无痕空间数据存储隔离池
│   ├── PasswordAutofillHelper.swift   # AuthenticationServices 原生钥匙串桥接
│   ├── UserScriptBridge.swift         # WKUserScript 注入调度与通信桥
│   └── UserScriptStore.swift          # .user.js 规则与脚本存储
├── Commands/                          # 快捷键系统
│   └── BrowserCommands.swift          # CommandMenu 桌面组合键响应
└── Views/                             # 现代化界面实现
    ├── RootView.swift                 # 侧边栏 + 圆角主画布总体布局
    ├── WebSurface.swift               # WebView 挂载容器、常驻池调度与崩溃恢复
    ├── StartPageView.swift            # 现代桌面起始页
    ├── TabStripView.swift             # 横向标签条（支持拖拽排序）
    ├── Sidebar/                       # 侧边栏组件群
    │   ├── SidebarView.swift          # 空间切换、文件夹与垂直标签树
    │   ├── SpaceSwitcher.swift        # 多空间快速切换器
    │   ├── BookmarkSidebarSection.swift # 侧边栏书签视图
    │   └── SidebarResizeDivider.swift # 拖拽调宽分割线
    ├── Toolbar/                       # 顶部导航工具栏
    │   ├── ToolbarView.swift          # 智能地址栏（Omnibox）与核心操作
    │   ├── BookmarkBar.swift          # 快捷书签栏
    │   └── CommandPanel.swift         # ⌘⇧P 快速命令面板
    ├── Settings/                      # 偏好设置界面
    │   └── SettingsView.swift         # 分类选项面板
    └── Compatibility/                 # 跨系统版本兼容
        └── LiquidGlass.swift          # Liquid Glass 视觉材质兼容封装
```

### 关键工程亮点

1. **细粒度运行时隔离（防止全树重绘）**：
   网页加载进度变化极高频（每秒数十次更新），PadBrowser 将进度、加载态、前进后退状态下放至独立的 `TabRuntime` 实例中，避免整个 `BrowserStore` 触发 SwiftUI 视图树全量无效化。
2. **WebKit 实例生命周期安全**：
   在 `WebContainer.dismantleUIView` 与 `Coordinator.deinit` 中显式清退代理、停止加载并注销 KVO 与通知监听，彻底杜绝内存泄漏。
3. **Jetsam 进程崩溃自动恢复**：
   监听 WebKit 渲染进程异常终止事件（`webViewWebContentProcessDidTerminate`），结合最后一次保存的滚动偏移快照与状态机，提供用户友好的轻量无缝重建。
4. **常驻活跃标签内存池（Resident Tabs Pool）**：
   支持在设置中自定义常驻内存中的 WebView 数量（4 / 8 / 12 / 16 个），采用 LRU 淘汰策略动态挂载与卸载视图，在低内存 iPad 上兼顾切换流畅度与防闪退。

---

## ⌨️ 常用快捷键速查

| 快捷键 | 功能 |
|---|---|
| <kbd>⌘</kbd> + <kbd>T</kbd> | 新建标签页 |
| <kbd>⌘</kbd> + <kbd>W</kbd> | 关闭当前标签页 |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>W</kbd> | 关闭其他标签页 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>N</kbd> | 新建无痕空间标签页 |
| <kbd>⌘</kbd> + <kbd>L</kbd> | 快速聚焦地址栏 |
| <kbd>⌘</kbd> + <kbd>R</kbd> | 重新加载当前页面 |
| <kbd>⌘</kbd> + <kbd>[</kbd> / <kbd>]</kbd> | 后退 / 前进 |
| <kbd>⌘</kbd> + <kbd>1</kbd> ~ <kbd>9</kbd> | 切换至第 1 ~ 9 个标签页 |
| <kbd>⌘</kbd> + <kbd>⌃</kbd> + <kbd>S</kbd> | 展开 / 折叠侧边栏 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd> | 呼出命令面板（Command Palette） |
| <kbd>⌘</kbd> + <kbd>D</kbd> | 将当前页面添加至书签 |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>B</kbd> | 显示 / 隐藏书签栏 |
| <kbd>⌘</kbd> + <kbd>+</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | 放大 / 缩小 / 重置页面缩放比例 |

---

## 🚀 编译与运行指南

### 环境要求
- **Xcode**：16.0 或更高版本
- **开发语言**：Swift 6.0
- **目标平台**：iPadOS 18.0+（仅支持 iPad 设备与模拟器）
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
3. 勾选 **Automatically manage signing**，在 **Team** 下拉框中选择你的 Apple 开发团队（个人免费 Apple ID 亦可）。
4. 连接你的 iPad 真机（或在顶部运行设备中选择任一 iPadOS 18+ 模拟器，如 `iPad Pro 13-inch (M4)`）。
5. 按下 <kbd>⌘</kbd> + <kbd>R</kbd> 编译并安装。

### 4. 命令行构建（可选）
```bash
xcodebuild -project PadBrowser.xcodeproj \
           -scheme PadBrowser \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           -configuration Debug \
           build
```

> **提示**：工程采用了 Xcode 同步根组（Synchronized Root Group）规范，在 `PadBrowser/` 目录内新增或移动 `.swift` 文件会自动纳入编译，无需手动修改工程文件。


---

## 🤝 参与贡献

欢迎提交 Issue、功能提议与 Pull Request！在贡献代码时请遵循：
1. 保持 Swift 6 并发安全范式（Actor 隔离与 Sendable 检查）。
2. 新增视图需确保 iPad 各大尺寸（11寸、13寸、Split View 分屏）下的布局稳健性。
3. 提交 PR 前请在模拟器与真机上完成完整交互验证。

---

## 📄 开源许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

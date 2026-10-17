# PadBrowser

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iPadOS%2018.0+-007AFF?style=flat-square&logo=apple&logoColor=white" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Observation-0055FF?style=flat-square" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Target-iPad%20Only-teal?style=flat-square" alt="iPad Only" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

<p align="center">
  <strong>A desktop-class web browser engineered exclusively for iPadOS, built for large displays, hardware keyboards, and trackpads.</strong>
</p>

<p align="center">
  <strong>English</strong> •
  <a href="README_CN.md">简体中文</a> •
  <a href="README_JA.md">日本語</a>
</p>

---

## Overview

Modern iPad hardware features high-performance Apple Silicon, high-refresh-rate Liquid Retina displays, and dedicated keyboard-trackpad accessories. However, standard mobile browsers often constrain iPad browsing to magnified mobile viewports, cluttered horizontal tab bars, and incomplete shortcut mappings.

**PadBrowser** rethinks browsing on iPadOS from first principles. Built natively in Swift 6 and SwiftUI, it introduces true desktop-grade WebKit rendering, multi-space workspace isolation, vertical tab management, kernel-level content blocking, and complete hardware keyboard navigation.

---

## Core Capabilities

### 1. True Desktop WebKit Engine
- **Uncompromised Desktop Viewports**: Configured with `preferredContentMode = .desktop` by default, rendering complex web applications (such as GitHub, Figma, Notion, and Bilibili) exactly as they appear on a desktop operating system.
- **Mac Safari User-Agent Contract**: Emits a complete macOS Safari User-Agent string, preventing websites from erroneously serving degraded mobile layouts or displaying "unsupported browser" banners.
- **Media Playback & Picture-in-Picture**: Supports native HTML5 Picture-in-Picture (PiP), element fullscreen, and inline playback, with autoplay restrictions on audible media to prevent unintended background audio.
- **Remote Web Inspector**: Enables `isInspectable = true` for seamless debugging via Safari Web Inspector on a connected Mac.

### 2. Workspaces (Spaces) & Hierarchical Tab System
- **Contextual Spaces**: Organize browsing into distinct workspaces (e.g., *Engineering*, *Research*, *Personal*). Each space maintains its own isolated tab hierarchies, nested folders, and pinned sites.
- **Strict Incognito Isolation**: Each incognito space provisions an independent, in-memory `WKWebsiteDataStore.nonPersistent()` instance. Sessions and cookies are shared within the same private space but strictly isolated across spaces and destroyed on teardown.
- **Sunken Resizable Sidebar**: Provides an ergonomic vertical tab tree with drag-and-drop tab organization and width adjustment (220 pt to 420 pt), reclaiming vertical display real estate for page content.
- **Classic Tab Strip Mode**: Allows users who prefer horizontal tabs to switch to an animated, drag-and-drop horizontal strip.
- **Start Page**: Features unified quick-search, pinned site grids, and recent bookmarks with layered continuous-corner card styling.

### 3. Kernel-Level Privacy & Security
- **Native WebKit Rule Compilation**: Powered by `WKContentRuleList`, tracker domains and high-frequency advertisements are intercepted at the WebKit network layer with complementary CSS cosmetic filtering—incurring zero third-party dependency overhead.
- **System Keychain Autofill**: Integrates with iPadOS `AuthenticationServices` (`ASAuthorizationPasswordProvider`) to summon iCloud Keychain with Touch ID / Face ID verification and safely inject credentials into web forms.
- **Userscript Pipeline**: Includes an embedded userscript engine that evaluates Tampermonkey-compatible `@match` patterns and schedules script injection at `atDocumentStart` and `atDocumentEnd`.
- **Netscape Bookmark Ingestion**: Features a standalone HTML bookmark parser supporting recursive folder trees and standard entity normalization from Chrome, Safari, and Firefox exports.

### 4. Hardware-First Ergonomics
- **Desktop Keyboard Mapping**: Supports full keyboard navigation with 15+ standard macOS key combinations, eliminating constant screen tapping.
- **Command Palette (<kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd>)**: Quick launcher inspired by desktop productivity tools for immediate URL dispatch and action filtering.
- **Two-Finger Trackpad Gestures**: Smooth edge swipe navigation for history traversal with fluid inertia and bounce curves.

### 5. Design System & Apple HIG Craftsmanship
- **Continuous Curvature Canvas**: The central browser canvas conforms to iPad display hardware corners using a 24 pt continuous rounded rectangle with subtle depth shadows and hairline borders.
- **Liquid Glass Compatibility Layer**: Features dynamic abstraction across OS generations, automatically binding to iPadOS 26+ native `glassEffect` while offering a graceful fallback to `.ultraThinMaterial` on iPadOS 18.
- **Immersive Fullscreen Mode**: Supports hiding the native status bar to maximize viewable canvas height during focused workflows.

---

## Architecture & Engineering Highlights

PadBrowser is constructed using a unidirectional, Observation-driven architecture:

```text
PadBrowser/
├── PadBrowserApp.swift                # App entrypoint and Scene-level Store injection
├── Models/                            # Domain entities
│   ├── BrowserTab.swift               # Tab model (UUID, URL, scroll offset snapshots)
│   ├── BrowserSpace.swift             # Spaces, folder hierarchy, and pinned sites
│   └── Bookmark.swift                 # Tree bookmark structure and Netscape parser
├── Stores/                            # Reactive state roots (SwiftUI Observation)
│   ├── BrowserStore.swift             # Central state root with granular TabRuntime isolation
│   ├── PersistenceStore.swift         # Atomic JSON session persistence and cold-boot restore
│   ├── SettingsStore.swift            # Preferences storage via UserDefaults
│   ├── BookmarkStore.swift            # Bookmark collection management
│   └── CredentialStore.swift          # Search engine definitions and HTTP auth cache
├── Web/                               # WebKit orchestration layer
│   ├── BrowserWebView.swift           # Subclassed WKWebView with desktop configuration
│   ├── WebContainer.swift             # UIViewRepresentable bridge & Coordinator
│   ├── ContentBlockerManager.swift    # Compiled WKContentRuleList blocker engine
│   ├── IncognitoDataStorePool.swift   # Non-persistent storage allocation pool
│   ├── PasswordAutofillHelper.swift   # Biometric Keychain form injection helper
│   ├── UserScriptBridge.swift         # UserScript loading and injection bridge
│   └── UserScriptStore.swift          # In-memory userscript metadata registry
├── Commands/                          # Hardware input handling
│   └── BrowserCommands.swift          # CommandMenu desktop keyboard binding system
└── Views/                             # Presentation layer
    ├── RootView.swift                 # Root split layout and main card canvas
    ├── WebSurface.swift               # Active tab pool dispatcher and crash recovery
    ├── StartPageView.swift            # Modern start page with quick access
    ├── TabStripView.swift             # Horizontal tab strip
    ├── Sidebar/                       # Workspace switcher, divider, and vertical tabs
    ├── Toolbar/                       # Address bar (Omnibox), navigation controls, command panel
    ├── Settings/                      # Preferences interface
    └── Compatibility/                 # Liquid Glass system abstraction
```

### Engineering Details
1. **Granular Reactivity (Render Performance)**: High-frequency progress updates (up to 60 events/sec) are delegated to isolated `@Observable class TabRuntime` instances rather than the global `BrowserStore`, avoiding full view tree re-evaluations.
2. **Defensive Lifecycle Management**: `WebContainer.dismantleUIView` explicitly nullifies delegates, terminates ongoing network tasks, and unregisters KVO / notification observers to eliminate WebKit memory leaks.
3. **Jetsam Process Recovery**: Automatically intercepts `webViewWebContentProcessDidTerminate` and seamlessly restores tab viewports utilizing persistent scroll offsets.
4. **Resident Active Tab Pool**: Enforces an LRU tab pool (`maxResidentTabs` configurable between 4 and 16) to balance instant switching responsiveness with iPadOS background memory limits.

---

## Keyboard Shortcuts

| Shortcut | Description |
|---|---|
| <kbd>⌘</kbd> + <kbd>T</kbd> | Open a new tab |
| <kbd>⌘</kbd> + <kbd>W</kbd> | Close current tab |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>⇧</kbd> + <kbd>W</kbd> | Close all other tabs |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>N</kbd> | Create a new private space tab |
| <kbd>⌘</kbd> + <kbd>L</kbd> | Focus address bar (Omnibox) |
| <kbd>⌘</kbd> + <kbd>R</kbd> | Reload current page |
| <kbd>⌘</kbd> + <kbd>[</kbd> / <kbd>]</kbd> | History Back / Forward |
| <kbd>⌘</kbd> + <kbd>1</kbd> ~ <kbd>9</kbd> | Switch to tab index 1 through 9 |
| <kbd>⌘</kbd> + <kbd>⌃</kbd> + <kbd>S</kbd> | Toggle sidebar visibility |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>P</kbd> | Open Command Palette |
| <kbd>⌘</kbd> + <kbd>D</kbd> | Bookmark current page |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>B</kbd> | Toggle bookmarks bar |
| <kbd>⌘</kbd> + <kbd>+</kbd> / <kbd>-</kbd> / <kbd>0</kbd> | Zoom in / Zoom out / Reset zoom level (50% ~ 200%) |

---

## Building from Source

### Prerequisites
- **Xcode**: 16.0 or higher
- **Language**: Swift 6.0
- **Target OS**: iPadOS 18.0+
- **Architecture**: arm64 (Device) / arm64 (Simulator)

### Clone & Open
```bash
git clone https://github.com/jinlun7/ipadbrowser.git
cd ipadbrowser
open PadBrowser.xcodeproj
```

### Code Signing
1. Select the root `PadBrowser` project node in Xcode.
2. Navigate to **Signing & Capabilities**.
3. Enable **Automatically manage signing** and select your Development Team (free personal Apple IDs are supported).
4. Select a connected iPad device or an iPadOS 18+ simulator (e.g., `iPad Pro 13-inch (M4)`).
5. Press <kbd>⌘</kbd> + <kbd>R</kbd> to build and run.

### Command-Line Build
```bash
xcodebuild -project PadBrowser.xcodeproj \
           -scheme PadBrowser \
           -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
           -configuration Debug \
           build
```

---

## Contributing

Contributions, feature discussions, and bug reports are welcome. When submitting changes:
1. Ensure full compatibility with Swift 6 strict concurrency checks.
2. Verify visual stability across different iPad screen sizes (11-inch, 13-inch, and Split View multitasking).
3. Test interaction workflows on hardware devices or simulators prior to opening a Pull Request.

---

## License

This project is licensed under the [MIT License](LICENSE).

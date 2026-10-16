import Foundation
import Observation
import SwiftUI

/// 外观与行为偏好。
///
/// 用 `UserDefaults` 而不是 JSON 文件：这类小而频繁读取的值，系统会自动处理
/// 同步和备份，也不需要自己做版本迁移。
@MainActor
@Observable
final class SettingsStore {

    static let shared = SettingsStore()

    // MARK: - 浏览器

    /// 地址栏判定为搜索词时使用的引擎。
    var searchEngine: SearchEngine { didSet { persist(searchEngine.rawValue, .searchEngine) } }

    /// 保持存活的标签页上限。超出后最久未使用的会被回收，切回来时重新加载。
    ///
    /// 暴露成设置项是因为这是个**真实的内存权衡**：调高换来切换标签秒开，
    /// 调低换来「渲染进程被系统回收」的弹窗变少。没有对所有人最优的值。
    var maxResidentTabs: Int { didSet { persist(maxResidentTabs, .maxResidentTabs) } }

    /// 冷启动时怎么恢复。
    var restoreSessionOnLaunch: Bool { didSet { persist(restoreSessionOnLaunch, .restoreSession) } }

    var startURLString: String { didSet { persist(startURLString, .startURL) } }

    // MARK: - 外观

    var themeMode: ThemeMode { didSet { persist(themeMode.rawValue, .theme) } }

    var hideStatusBar: Bool { didSet { persist(hideStatusBar, .hideStatusBar) } }

    var showBookmarkBar: Bool { didSet { persist(showBookmarkBar, .showBookmarkBar) } }

    var showTabStrip: Bool { didSet { persist(showTabStrip, .showTabStrip) } }

    /// 侧边栏宽度（支持拖拽调节，单位 pt）。
    var sidebarWidth: Double { didSet { persist(sidebarWidth, .sidebarWidth) } }

    static let minSidebarWidth: Double = 220.0
    static let maxSidebarWidth: Double = 420.0
    static let defaultSidebarWidth: Double = 280.0

    /// 标签页显示模式：纯垂直标签（推荐）、智能切换、经典横向条。
    var tabLayoutMode: TabLayoutMode { didSet { persist(tabLayoutMode.rawValue, .tabLayoutMode) } }

    // MARK: - 页面缩放

    /// 网页缩放比例（百分比，例如 100 代表 100%）。
    var pageZoomPercentage: Int { didSet { persist(pageZoomPercentage, .pageZoom) } }

    static let defaultPageZoom: Int = 100
    static let pageZoomLevels: [Int] = [50, 75, 85, 100, 115, 125, 150, 175, 200]

    func zoomIn() {
        if let next = Self.pageZoomLevels.first(where: { $0 > pageZoomPercentage }) {
            pageZoomPercentage = next
        }
    }

    func zoomOut() {
        if let prev = Self.pageZoomLevels.last(where: { $0 < pageZoomPercentage }) {
            pageZoomPercentage = prev
        }
    }

    func resetZoom() {
        pageZoomPercentage = Self.defaultPageZoom
    }

    // MARK: - 隐私

    var blocksAds: Bool { didSet { persist(blocksAds, .blocksAds) } }

    var revealsPasswordsOnFocus: Bool { didSet { persist(revealsPasswordsOnFocus, .revealPasswords) } }

    // MARK: - 可选项

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: "跟随系统"
            case .light:  "浅色"
            case .dark:   "深色"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light:  .light
            case .dark:   .dark
            }
        }
    }

    /// 常驻标签数的可选档位。
    enum ResidentTabOption: Int, CaseIterable, Identifiable {
        case four = 4, eight = 8, twelve = 12, sixteen = 16
        var id: Int { rawValue }
        var label: String { "\(rawValue) 个" }
        /// 附带的风险提示，让用户知道调高会更容易被系统回收。
        var note: String {
            switch self {
            case .four:    "最省内存，切换标签偶尔需要重新加载"
            case .eight:   "平衡，推荐"
            case .twelve:  "切换更跟手，内存压力较大"
            case .sixteen: "最快，内存开销最大，低内存 iPad 上可能频繁被系统回收"
            }
        }
    }

    /// 标签页显示模式。
    enum TabLayoutMode: String, CaseIterable, Identifiable {
        case vertical, auto, horizontal
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .vertical:   "纯垂直标签（侧边栏）"
            case .auto:       "智能切换"
            case .horizontal: "经典横向标签条"
            }
        }

        var note: String {
            switch self {
            case .vertical:   "推荐！彻底移除顶部标签条，全屏纵向空间留给网页"
            case .auto:       "侧边栏展开时仅使用垂直标签，侧边栏折叠时在顶部显露横向标签"
            case .horizontal: "顶部始终保留横向标签条"
            }
        }
    }

    // MARK: - 存储

    private enum Key: String {
        case searchEngine, maxResidentTabs, restoreSession, startURL, theme
        case showBookmarkBar, showTabStrip, blocksAds, revealPasswords, tabLayoutMode
        case hideStatusBar, sidebarWidth, pageZoom
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        func read<T>(_ key: Key, _ fallback: T) -> T {
            defaults.object(forKey: key.rawValue) as? T ?? fallback
        }

        self.searchEngine = SearchEngine(rawValue: read(Key.searchEngine, "")) ?? .duckduckgo
        let storedTabs = defaults.integer(forKey: Key.maxResidentTabs.rawValue)
        // integer(forKey:) 在 key 不存在时返回 0，所以要额外兜一道。
        self.maxResidentTabs = ResidentTabOption(rawValue: storedTabs)?.rawValue ?? 8
        self.restoreSessionOnLaunch = read(Key.restoreSession, true)
        self.startURLString = read(Key.startURL, "")
        self.themeMode = ThemeMode(rawValue: read(Key.theme, ThemeMode.system.rawValue)) ?? .system
        // 隐藏顶部状态栏（时间/日期/电量），全屏沉浸且最大化纵向高度
        self.hideStatusBar = read(Key.hideStatusBar, true)
        let storedWidth = defaults.double(forKey: Key.sidebarWidth.rawValue)
        self.sidebarWidth = (storedWidth >= Self.minSidebarWidth && storedWidth <= Self.maxSidebarWidth)
            ? storedWidth
            : Self.defaultSidebarWidth
        let storedZoom = defaults.integer(forKey: Key.pageZoom.rawValue)
        self.pageZoomPercentage = storedZoom > 0 ? storedZoom : Self.defaultPageZoom
        // 书签栏默认关闭，避免常驻吃掉 iPad 宝贵的纵向高度
        self.showBookmarkBar = read(Key.showBookmarkBar, false)
        self.showTabStrip = read(Key.showTabStrip, true)
        self.tabLayoutMode = TabLayoutMode(rawValue: read(Key.tabLayoutMode, TabLayoutMode.vertical.rawValue)) ?? .vertical
        self.blocksAds = read(Key.blocksAds, true)
        self.revealsPasswordsOnFocus = read(Key.revealPasswords, false)
    }

    private func persist(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    var preferredColorScheme: ColorScheme? { themeMode.colorScheme }
}

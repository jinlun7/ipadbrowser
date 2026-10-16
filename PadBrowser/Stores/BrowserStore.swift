import Foundation
import Observation

/// 全局状态根。所有视图只通过它读写状态，WebView 的回写也一律回到这里。
///
/// 设计要点：
/// - `tabs` 是一维数组，靠 `spaceID` 分组，避免多层嵌套导致的 diff 抖动；
/// - **运行时状态**（progress / isLoading / canGoBack）不参与持久化，
///   只在内存里存在，避免每次切后台都要序列化一堆瞬时值；
/// - 地址栏输入不直接改 `tabs[].url`，而是在提交时才改，这样
///   `updateUIView` 才不会在用户打字时误判为「需要重新加载」。
@MainActor
@Observable
final class BrowserStore {

    // MARK: - 持久化状态

    var spaces: [BrowserSpace]
    var currentSpaceID: UUID
    var tabs: [BrowserTab]
    var folders: [TabFolder]
    var pinnedSites: [PinnedSite]
    var selectedTabID: UUID?

    // MARK: - 仅运行时状态（不落盘）

    @ObservationIgnored private var tabRuntimes: [UUID: TabRuntime] = [:]
    @ObservationIgnored private var scrollOffsets: [UUID: Double] = [:]
    @ObservationIgnored private var scrollDebounceTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - 界面状态

    var sidebarVisible: Bool = true
    var commandPanelPresented: Bool = false
    var settingsPresented: Bool = false

    /// 地址栏判定用的搜索引擎。每次启动时从设置同步过来，
    /// 这样 `resolveAddressBarInput` 不需要再依赖 environment。
    var searchEngine: SearchEngine = .duckduckgo

    /// ⌘L 聚焦地址栏的信号。
    ///
    /// 用递增计数器而不是 Bool：连续按两次 ⌘L 时 Bool 已经回到 false，
    /// 第二次按压不会触发 `onChange`，地址栏就聚焦不了。计数器每次都变，
    /// `onChange` 一定会触发。
    var addressBarFocusRequest: Int = 0

    func requestAddressBarFocus() {
        addressBarFocusRequest += 1
    }

    // MARK: - 初始化

    init() {
        let defaultSpace = BrowserSpace(name: "个人", isIncognito: false, order: 0)
        self.spaces = [defaultSpace]
        self.currentSpaceID = defaultSpace.id
        self.tabs = []
        self.folders = []
        self.pinnedSites = []
        self.selectedTabID = nil
    }

    /// 每个标签的瞬时运行状态。
    ///
    /// 必须是独立的 `@Observable final class`，让消费端（进度条、加载菊花、前进后退）
    /// 的依赖细粒度绑定到「当前标签的对象」，而不是整个 BrowserStore 的字典属性。
    /// 否则任何一个标签进度更新（数十次/秒），都会导致整树全量重算。
    @MainActor
    @Observable
    final class TabRuntime {
        var isLoading: Bool = false
        var progress: Double = 0
        var canGoBack: Bool = false
        var canGoForward: Bool = false
        var loadError: String? = nil
        var didTerminate: Bool = false
        var terminationCount: Int = 0
    }

    // MARK: - 派生视图数据

    var currentSpace: BrowserSpace? {
        spaces.first { $0.id == currentSpaceID }
    }

    var currentSpaceIsIncognito: Bool {
        currentSpace?.isIncognito ?? false
    }

    /// 当前空间的标签，按创建顺序。
    var currentSpaceTabs: [BrowserTab] {
        tabs.filter { $0.spaceID == currentSpaceID }
    }

    /// 当前空间的根级标签（不在任何文件夹里的）。
    var rootTabs: [BrowserTab] {
        currentSpaceTabs.filter { $0.folderID == nil }
    }

    func tabs(inFolder folderID: UUID) -> [BrowserTab] {
        currentSpaceTabs.filter { $0.folderID == folderID }
    }

    var currentSpaceFolders: [TabFolder] {
        TabFolder.roots(in: folders, spaceID: currentSpaceID)
    }

    var currentSpacePinnedSites: [PinnedSite] {
        pinnedSites.filter { $0.spaceID == currentSpaceID }.sorted { $0.order < $1.order }
    }

    var selectedTab: BrowserTab? {
        guard let selectedTabID else { return nil }
        return tabs.first { $0.id == selectedTabID }
    }

    func runtime(for tabID: UUID) -> TabRuntime {
        if let existing = tabRuntimes[tabID] {
            return existing
        }
        let created = TabRuntime()
        tabRuntimes[tabID] = created
        return created
    }

    // MARK: - 生命周期

    /// 冷启动恢复。
    ///
    /// `settings` 传进来而不是从 `@Environment` 取，是因为这个方法在 App 的
    /// `.task` 里执行，那里的 view 拿不到 WindowGroup 的环境。
    func bootstrap(settings: SettingsStore) async {
        self.searchEngine = settings.searchEngine

        if settings.restoreSessionOnLaunch, let snapshot = PersistenceStore.shared.load() {
            spaces = snapshot.spaces.isEmpty ? spaces : snapshot.spaces
            currentSpaceID = spaces.contains(where: { $0.id == snapshot.currentSpaceID })
                ? snapshot.currentSpaceID
                : (spaces.first?.id ?? currentSpaceID)
            tabs = snapshot.tabs
            folders = snapshot.folders
            pinnedSites = snapshot.pinnedSites
            selectedTabID = snapshot.selectedTabID.flatMap { id in
                tabs.contains(where: { $0.id == id }) ? id : nil
            }
        }

        // 起始页：先看用户有没有自定义地址，没有就走内置起始页（url == nil）。
        if selectedTabID == nil {
            if let url = startURL(from: settings) {
                newTab(url: url)
            } else {
                newTab(url: nil)
            }
        }
    }

    private func startURL(from settings: SettingsStore) -> URL? {
        let raw = settings.startURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let normalized = raw.hasPrefix("http") ? raw : "https://\(raw)"
        return URL(string: normalized)
    }

    /// App 进入后台时调用。刷新滚动位置快照并落盘。
    func persistNow() {
        flushAllScrollOffsets()
        PersistenceStore.shared.save(
            BrowserSnapshot(
                spaces: spaces,
                currentSpaceID: currentSpaceID,
                tabs: tabs,
                folders: folders,
                pinnedSites: pinnedSites,
                selectedTabID: selectedTabID
            )
        )
    }

    // MARK: - 标签操作

    private static func faviconURL(for url: URL?) -> URL? {
        guard let host = url?.host(), !host.isEmpty else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    @discardableResult
    func newTab(url: URL?, activate: Bool = true) -> BrowserTab {
        let tab = BrowserTab(
            url: url,
            faviconURL: Self.faviconURL(for: url),
            spaceID: currentSpaceID,
            isIncognito: currentSpaceIsIncognito
        )
        tabs.append(tab)
        if activate { selectedTabID = tab.id }
        scheduleSave()
        return tab
    }

    func select(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        selectedTabID = tabID
        scheduleSave()
    }

    func close(_ tabID: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let spaceID = tabs[idx].spaceID
        let sameSpaceTabs = tabs.filter { $0.spaceID == spaceID }
        let spaceIndex = sameSpaceTabs.firstIndex(where: { $0.id == tabID })

        tabs.remove(at: idx)
        tabRuntimes.removeValue(forKey: tabID)
        scrollOffsets.removeValue(forKey: tabID)
        scrollDebounceTasks[tabID]?.cancel()
        scrollDebounceTasks[tabID] = nil

        if selectedTabID == tabID {
            // 优先选中同空间内相邻的标签（优先右侧，无右侧则选左侧）
            let remaining = sameSpaceTabs.filter { $0.id != tabID }
            if let spaceIndex, !remaining.isEmpty {
                let nextIndex = min(spaceIndex, remaining.count - 1)
                selectedTabID = remaining[nextIndex].id
            } else {
                selectedTabID = tabs.filter { $0.spaceID == currentSpaceID }.last?.id
            }
        }
        scheduleSave()
    }

    func closeOthers(keeping tabID: UUID) {
        let space = tabs.first { $0.id == tabID }?.spaceID ?? currentSpaceID
        for tab in tabs where tab.spaceID == space && tab.id != tabID {
            close(tab.id)
        }
    }

    func moveTab(_ tabID: UUID, toFolder folderID: UUID?) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        // 不允许把标签拖进别的空间所属的文件夹。
        if let folderID, folders.first(where: { $0.id == folderID })?.spaceID != tabs[idx].spaceID {
            return
        }
        tabs[idx].folderID = folderID
        scheduleSave()
    }

    func reorderTabs(_ orderedIDs: [UUID]) {
        let space = currentSpaceID
        // 先取出这个空间内、被拖动排序涉及的标签，按新顺序写回；
        // 同空间内不在 orderedIDs 里的标签（没参与拖动的）保持原有相对顺序追加在后面。
        var reordered: [BrowserTab] = []
        for id in orderedIDs {
            if let tab = tabs.first(where: { $0.id == id && $0.spaceID == space }) {
                reordered.append(tab)
            }
        }
        let touched = Set(orderedIDs)
        let untouchedInSpace = tabs.filter { $0.spaceID == space && !touched.contains($0.id) }
        let otherSpaces = tabs.filter { $0.spaceID != space }
        tabs = otherSpaces + reordered + untouchedInSpace
        scheduleSave()
    }

    func navigateSelected(to url: URL) {
        guard let id = selectedTabID,
              let idx = tabs.firstIndex(where: { $0.id == id })
        else {
            newTab(url: url)
            return
        }
        if tabs[idx].url == url {
            // 用户在地址栏重输/确认了当前相同的网址，直接重新加载该页面
            reload(for: id)
            return
        }
        tabs[idx].url = url
        tabs[idx].title = ""
        tabRuntimes[id]?.loadError = nil
        scheduleSave()
    }

    // MARK: - 空间操作

    func addSpace(name: String, incognito: Bool) {
        let space = BrowserSpace(name: name, isIncognito: incognito, order: spaces.count)
        spaces.append(space)
        currentSpaceID = space.id
        newTab(url: nil)
        scheduleSave()
    }

    func switchSpace(to id: UUID) {
        guard spaces.contains(where: { $0.id == id }) else { return }
        currentSpaceID = id
        // 切空间后自动选中该空间的第一个标签，没有就开一个。
        if let first = tabs.first(where: { $0.spaceID == id }) {
            selectedTabID = first.id
        } else {
            newTab(url: nil)
        }
        scheduleSave()
    }

    func removeSpace(_ id: UUID) {
        guard spaces.count > 1 else { return }
        IncognitoDataStorePool.shared.discard(for: id)
        let removingTabIDs = tabs.filter { $0.spaceID == id }.map(\.id)
        for tabID in removingTabIDs {
            tabRuntimes.removeValue(forKey: tabID)
            scrollOffsets.removeValue(forKey: tabID)
            scrollDebounceTasks[tabID]?.cancel()
            scrollDebounceTasks[tabID] = nil
        }
        spaces.removeAll { $0.id == id }
        tabs.removeAll { $0.spaceID == id }
        folders.removeAll { $0.spaceID == id }
        pinnedSites.removeAll { $0.spaceID == id }
        if currentSpaceID == id {
            currentSpaceID = spaces[0].id
            newTab(url: nil)
        }
        scheduleSave()
    }

    // MARK: - 文件夹与固定站点

    @discardableResult
    func addFolder(name: String, parentID: UUID?) -> TabFolder {
        let folder = TabFolder(
            name: name,
            spaceID: currentSpaceID,
            parentID: parentID,
            order: folders.count
        )
        folders.append(folder)
        scheduleSave()
        return folder
    }

    func removeFolder(_ id: UUID) {
        // 子文件夹和里面的标签一并上提到根级，不要静默丢数据。
        for idx in folders.indices where folders[idx].parentID == id {
            folders[idx].parentID = nil
        }
        folders.removeAll { $0.id == id }
        for idx in tabs.indices where tabs[idx].folderID == id {
            tabs[idx].folderID = nil
        }
        scheduleSave()
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        scheduleSave()
    }

    func pin(_ site: PinnedSite) {
        pinnedSites.append(site)
        scheduleSave()
    }

    func unpin(_ id: UUID) {
        pinnedSites.removeAll { $0.id == id }
        scheduleSave()
    }

    // MARK: - WebView 回写

    func updateTitle(_ title: String, for tabID: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard tabs[idx].title != title else { return }
        tabs[idx].title = title
        scheduleSave()
    }

    func updateURL(_ url: URL, for tabID: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard tabs[idx].url?.absoluteString != url.absoluteString else { return }
        tabs[idx].url = url
        tabs[idx].faviconURL = Self.faviconURL(for: url)
        scheduleSave()
    }

    func updateProgress(_ value: Double, for tabID: UUID) {
        let rt = runtime(for: tabID)
        guard abs(rt.progress - value) >= 0.005 else { return }
        rt.progress = value
    }

    func setLoading(_ loading: Bool, for tabID: UUID) {
        let rt = runtime(for: tabID)
        guard rt.isLoading != loading else { return }
        rt.isLoading = loading
        if !loading { rt.progress = 0 }
    }

    func updateNavigationState(canGoBack: Bool, canGoForward: Bool, for tabID: UUID) {
        let rt = runtime(for: tabID)
        guard rt.canGoBack != canGoBack || rt.canGoForward != canGoForward else { return }
        rt.canGoBack = canGoBack
        rt.canGoForward = canGoForward
    }

    func reportLoadFailure(_ error: Error, for tabID: UUID) {
        let rt = runtime(for: tabID)
        // -999 是用户主动取消导航，不算错误。
        let nsError = error as NSError
        let msg = (nsError.code == NSURLErrorCancelled) ? nil : nsError.localizedDescription
        guard rt.loadError != msg || rt.isLoading else { return }
        rt.loadError = msg
        rt.isLoading = false
    }

    @discardableResult
    func handleContentProcessTermination(for tabID: UUID) -> Bool {
        let rt = runtime(for: tabID)
        rt.terminationCount += 1
        rt.didTerminate = true
        // 只在首次崩溃时自动重试，若持续崩溃则停止自动重载，避免死循环闪烁与耗电
        return rt.terminationCount <= 1
    }

    func resetTerminationCount(for tabID: UUID) {
        let rt = runtime(for: tabID)
        rt.terminationCount = 0
        rt.didTerminate = false
    }

    func acknowledgeTermination(for tabID: UUID) {
        let rt = runtime(for: tabID)
        rt.didTerminate = false
        rt.terminationCount = 0
    }

    func clearLoadError(for tabID: UUID) {
        runtime(for: tabID).loadError = nil
    }

    /// 记录滚动位置。仅在内存字典保存活跃偏移，停止滚动 300ms 后才写入快照，
    /// 避免拖动滚动条时高频触发 @Observable 变更引发全树重绘与 Task 频繁分配。
    func recordScroll(_ offset: Double, for tabID: UUID) {
        scrollOffsets[tabID] = offset
        if scrollDebounceTasks[tabID] == nil {
            scrollDebounceTasks[tabID] = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                self?.flushScrollOffset(for: tabID)
            }
        }
    }

    private func flushScrollOffset(for tabID: UUID) {
        scrollDebounceTasks.removeValue(forKey: tabID)
        guard let offset = scrollOffsets[tabID] else { return }
        if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
            if abs(tabs[idx].lastKnownScrollY - offset) > 1.0 {
                tabs[idx].lastKnownScrollY = offset
            }
        }
    }

    func flushAllScrollOffsets() {
        for (tabID, offset) in scrollOffsets {
            if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
                tabs[idx].lastKnownScrollY = offset
            }
        }
    }

    func restoreOffset(for tabID: UUID) -> Double {
        scrollOffsets[tabID] ?? tabs.first { $0.id == tabID }?.lastKnownScrollY ?? 0
    }

    func goBack(for tabID: UUID) { requestNavigation(.back, for: tabID) }
    func goForward(for tabID: UUID) { requestNavigation(.forward, for: tabID) }
    func reload(for tabID: UUID) {
        clearLoadError(for: tabID)
        requestNavigation(.reload, for: tabID)
    }
    func stopLoading(for tabID: UUID) { requestNavigation(.stop, for: tabID) }

    /// 必须是 String 原始值型：导航信号要通过 NotificationCenter 的
    /// `[String: Any]` userInfo 传递，枚举不能直接塞进去。
    enum NavigationAction: String, Equatable { case back, forward, reload, stop }

    /// 后退/前进这类操作直接通过通知中心广播给对应的 WebContainer.Coordinator 执行。
    private func requestNavigation(_ action: NavigationAction, for tabID: UUID) {
        NotificationCenter.default.post(
            name: .pbPerformNavigation,
            object: nil,
            userInfo: ["tabID": tabID, "action": action.rawValue]
        )
    }

    // MARK: - 地址栏解析

    /// 把用户输入解析成 URL。看起来像域名就走搜索，否则直接当 URL。
    func resolveAddressBarInput(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), url.scheme != nil {
            return url
        }

        // 含空格、或者没有点号的，一律当搜索词。
        if text.contains(" ") || !text.contains(".") {
            return searchEngine.url(for: text)
        }

        if let url = URL(string: "https://\(text)") {
            return url
        }
        return searchEngine.url(for: text)
    }

    func credential(for space: URLProtectionSpace) -> URLCredential? {
        CredentialStore.shared.credential(for: space)
    }

    func storeCredential(_ credential: URLCredential, for space: URLProtectionSpace) {
        CredentialStore.shared.store(credential, for: space)
    }

    // MARK: - 持久化调度

    private var saveTask: Task<Void, Never>?

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }
}

extension Notification.Name {
    static let pbPerformNavigation = Notification.Name("pbPerformNavigation")
}

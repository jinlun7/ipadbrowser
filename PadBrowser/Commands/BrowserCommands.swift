import SwiftUI

/// 键盘快捷键。
///
/// 这是「桌面级浏览器」这个定位的**核心**：没有 ⌘T / ⌘W，桌面级就只是个说法。
///
/// 实现上的坑：`.commands` 修饰符拿不到 `WindowGroup` 内容视图的 `@Environment`。
/// 所以 store 必须在 **App 层**用 `@State` 持有，再同时喂给 `.commands` 和
/// `.environment(...)`。如果把 store 只放在 WindowGroup 里面，菜单里的
/// 按钮会因为拿不到状态而失效（或者直接编译不过，因为 Commands 不是 View）。
@MainActor
struct BrowserCommands: Commands {

    let store: BrowserStore
    let bookmarks: BookmarkStore
    let settings: SettingsStore

    var body: some Commands {
        // ⚠️ 这里全部用 CommandMenu 而不是 CommandGroup(after:)。
        // CommandGroup 的 `.newItem` / `.sidebar` 这些 placement 是 macOS 专有的，
        // 在 iPadOS 上用有大概率报 availability 错误。CommandMenu 是全平台安全的。
        CommandMenu("文件") {
            Button("新建无痕标签页") {
                store.addSpace(name: "无痕", incognito: true)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("新建窗口") {
                // iPadOS 上多窗口由 WindowGroup 管理，这里退回到新建标签。
                store.newTab(url: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("标签页") {
            Button("新建标签页") { store.newTab(url: nil) }
                .keyboardShortcut("t", modifiers: .command)

            Button("关闭当前标签页") { closeSelected() }
                .keyboardShortcut("w", modifiers: .command)

            Button("关闭其他标签页") {
                if let id = store.selectedTabID { store.closeOthers(keeping: id) }
            }
            .keyboardShortcut("w", modifiers: [.command, .option, .shift])
            .disabled(store.selectedTabID == nil)

            Divider()

            Button("重新加载") { reload() }
                .keyboardShortcut("r", modifiers: .command)

            Button("前进") { forward() }
                .keyboardShortcut("]", modifiers: .command)

            Button("后退") { back() }
                .keyboardShortcut("[", modifiers: .command)
        }

        CommandMenu("浏览") {
            Button("聚焦地址栏") { store.requestAddressBarFocus() }
                .keyboardShortcut("l", modifiers: .command)

            Button("显示/隐藏侧边栏") {
                withAnimation { store.sidebarVisible.toggle() }
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("命令面板") { store.commandPanelPresented = true }
                .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("把当前页面设为默认起始页") {
                if let url = store.selectedTab?.url {
                    settings.startURLString = url.absoluteString
                }
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(store.selectedTab?.url == nil)
        }

        CommandMenu("视图") {
            Button("放大") { settings.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)

            Button("缩小") { settings.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)

            Button("实际大小 (\(settings.pageZoomPercentage)%)") { settings.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
        }

        CommandMenu("书签") {
            Button("添加当前页面为书签") { bookmarkCurrentPage() }
                .keyboardShortcut("d", modifiers: .command)

            Button(settings.showBookmarkBar ? "隐藏书签栏" : "显示书签栏") {
                withAnimation { settings.showBookmarkBar.toggle() }
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button("新建书签文件夹") {
                _ = bookmarks.addFolder(name: "新文件夹")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Divider()

            // ⌘1…⌘9 直达标签页。
            //
            // 这里**故意写死 9 个 Button**，而不是 ForEach(1...9)：
            // `CommandsBuilder` 只保证接受 `Commands`，而 ForEach 产出的是 `View`，
            // 不同 SDK 上能否过 buildBlock 并不确定。写死虽然啰嗦，但一定能编译。
            tabShortcut(1)
            tabShortcut(2)
            tabShortcut(3)
            tabShortcut(4)
            tabShortcut(5)
            tabShortcut(6)
            tabShortcut(7)
            tabShortcut(8)
            tabShortcut(9)
        }
    }

    /// 生成第 n 个标签的快捷菜单项。
    @ViewBuilder
    private func tabShortcut(_ index: Int) -> some View {
        let tabs = store.currentSpaceTabs
        let tab = index <= tabs.count ? tabs[index - 1] : nil
        Button("切换到标签 \(index)") {
            if let tab { store.select(tab.id) }
        }
        .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
        .disabled(tab == nil)
    }

    // MARK: - 动作

    private func closeSelected() {
        if let id = store.selectedTabID { store.close(id) }
    }

    private func reload() {
        if let id = store.selectedTabID { store.reload(for: id) }
    }

    private func back() {
        if let id = store.selectedTabID { store.goBack(for: id) }
    }

    private func forward() {
        if let id = store.selectedTabID { store.goForward(for: id) }
    }

    private func bookmarkCurrentPage() {
        guard let tab = store.selectedTab, let url = tab.url else { return }
        bookmarks.toggle(url, title: tab.displayTitle)
    }
}

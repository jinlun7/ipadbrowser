import SwiftUI

@main
struct PadBrowserApp: App {
    /// 三个 store 都在 **App 层**用 `@State` 持有。
    ///
    /// 这不是随手写的：`.commands` 拿不到 WindowGroup 内容视图的 `@Environment`，
    /// 键盘快捷键要操作 store，就必须在这里同时喂给 `.commands` 和 `.environment`。
    /// 只把 store 放在 WindowGroup 里的话，菜单按钮会失效。
    @State private var store = BrowserStore()
    @State private var settings = SettingsStore()
    @State private var bookmarks = BookmarkStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(bookmarks)
                .preferredColorScheme(settings.preferredColorScheme)
                .task {
                    await store.bootstrap(settings: settings)
                }
        }
        .commands {
            BrowserCommands(store: store, bookmarks: bookmarks, settings: settings)
        }
    }
}

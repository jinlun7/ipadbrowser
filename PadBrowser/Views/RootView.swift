import SwiftUI

/// 主界面：左边可收起的侧边栏，右边标签条 + 工具栏 + 网页区。
struct RootView: View {

    @Environment(BrowserStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    private var shouldShowTabStrip: Bool {
        switch settings.tabLayoutMode {
        case .vertical:
            return false
        case .auto:
            return !store.sidebarVisible
        case .horizontal:
            return settings.showTabStrip
        }
    }

    var body: some View {
        @Bindable var store = store
        @Bindable var settings = settings

        HStack(spacing: 0) {
            if store.sidebarVisible {
                SidebarView()
                    .frame(width: CGFloat(settings.sidebarWidth))
                    .transition(.move(edge: .leading))

                SidebarResizeDivider(width: $settings.sidebarWidth)
            }

            mainCanvas
                .padding(.top, settings.hideStatusBar ? 10 : (store.sidebarVisible ? 6 : 4))
                .safeAreaPadding(.top, settings.hideStatusBar ? 0 : nil)
                .padding(.bottom, 10)
                .padding(.trailing, 10)
                .padding(.leading, store.sidebarVisible ? 4 : 10)
        }
        .animation(.easeInOut(duration: 0.22), value: store.sidebarVisible)
        .background(Color(uiColor: .systemGroupedBackground))
        .ignoresSafeArea(.all, edges: .vertical)
        .statusBarHidden(settings.hideStatusBar)
        // 切后台 / 息屏前把滚动位置和标签快照落盘，下次冷启动才能还原。
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.persistNow()
            }
        }
        .sheet(isPresented: $store.commandPanelPresented) {
            CommandPanel()
        }
        .sheet(isPresented: $store.settingsPresented) {
            SettingsView()
        }
    }

    private var mainCanvas: some View {
        VStack(spacing: 0) {
            ToolbarView()

            Rectangle()
                .fill(Color(.separator).opacity(0.18))
                .frame(height: 0.5)

            if settings.showBookmarkBar {
                BookmarkBar()
                Rectangle()
                    .fill(Color(.separator).opacity(0.18))
                    .frame(height: 0.5)
            }
            if shouldShowTabStrip {
                TabStripView()
                Rectangle()
                    .fill(Color(.separator).opacity(0.18))
                    .frame(height: 0.5)
            }
            WebSurface()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
        }
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 12,
            x: 0,
            y: 3
        )
    }
}

import SwiftUI

/// 网页区宿主。
///
/// 单独抽出来的原因有两个：
/// 1. WebView 必须挂在**稳定的视图身份**上，这里用 `.id(tab.id)`。
/// 2. 多标签存活管理：通过 ZStack + LRU 保持活跃标签存活，避免切标签重新加载。
struct WebSurface: View {

    @Environment(BrowserStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    @State private var activeTabIDs: Set<UUID> = []
    @State private var activeTabLRU: [UUID] = []

    var body: some View {
        ZStack {
            if store.currentSpaceTabs.isEmpty {
                EmptyStateView()
            } else {
                ForEach(store.currentSpaceTabs.filter { activeTabIDs.contains($0.id) }) { tab in
                    let isSelected = tab.id == store.selectedTabID
                    if tab.url == nil {
                        StartPageView(tabID: tab.id)
                            .opacity(isSelected ? 1 : 0)
                            .allowsHitTesting(isSelected)
                    } else {
                        WebContainer(
                            tab: tab,
                            store: store,
                            isSelected: isSelected,
                            pageZoom: settings.pageZoomPercentage,
                            blocksAds: settings.blocksAds
                        )
                        .id(tab.id)
                        .opacity(isSelected ? 1 : 0)
                        .allowsHitTesting(isSelected)
                    }
                }

                if let tab = store.selectedTab, tab.url != nil {
                    ProgressHeader(
                        progress: store.runtime(for: tab.id).progress,
                        visible: store.runtime(for: tab.id).isLoading
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    if let error = store.runtime(for: tab.id).loadError {
                        LoadFailureView(error: error) {
                            store.reload(for: tab.id)
                        }
                    }

                    if store.runtime(for: tab.id).didTerminate {
                        ProcessTerminatedBanner(tabID: tab.id)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            if let id = store.selectedTabID {
                markActive(id)
            }
        }
        .onChange(of: store.selectedTabID) { _, newID in
            if let newID {
                markActive(newID)
            }
        }
        .onChange(of: store.currentSpaceID) { _, _ in
            activeTabIDs.removeAll()
            activeTabLRU.removeAll()
            if let id = store.selectedTabID {
                markActive(id)
            }
        }
    }

    private func markActive(_ id: UUID) {
        let currentIDs = Set(store.currentSpaceTabs.map(\.id))
        var lru = activeTabLRU.filter { currentIDs.contains($0) && $0 != id }
        lru.insert(id, at: 0)

        // 常驻上限从设置里读，默认 8。这个数字是内存与体验的权衡，
        // 没有对所有设备都最优的值，所以交给用户在设置里调。
        let limit = max(1, settings.maxResidentTabs)
        if lru.count > limit {
            lru = Array(lru.prefix(limit))
        }
        activeTabLRU = lru
        activeTabIDs = Set(lru)
    }
}

/// 顶部细进度条。
struct ProgressHeader: View {
    let progress: Double
    let visible: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.clear)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 2)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: visible)
        .allowsHitTesting(false)
    }
}

/// 网页加载失败的错误界面。断网、DNS解析失败或打错网址时展示。
struct LoadFailureView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("无法载入页面")
                .font(.title2.weight(.medium))
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("重新加载", action: onRetry)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// WebView 内核进程被系统回收后的提示条。
struct ProcessTerminatedBanner: View {
    let tabID: UUID
    @Environment(BrowserStore.self) private var store

    var body: some View {
        let rt = store.runtime(for: tabID)
        let isLooping = rt.terminationCount > 1

        VStack {
            HStack(spacing: 12) {
                Image(systemName: isLooping ? "exclamationmark.triangle.fill" : "arrow.clockwise.heart")
                    .foregroundStyle(isLooping ? .yellow : .accentColor)
                Text(isLooping ? "该页面内存占用过高，已停止自动恢复" : "该页面的渲染进程已被系统回收，正在尝试恢复")
                    .font(.subheadline)
                Spacer()
                if isLooping {
                    Button("重新尝试") {
                        store.reload(for: tabID)
                        store.acknowledgeTermination(for: tabID)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("知道了") {
                    store.acknowledgeTermination(for: tabID)
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .background(.regularMaterial)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct EmptyStateView: View {
    @Environment(BrowserStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("没有打开的标签页")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("新建标签页") { store.newTab(url: nil) }
                .buttonStyle(.borderedProminent)
        }
    }
}

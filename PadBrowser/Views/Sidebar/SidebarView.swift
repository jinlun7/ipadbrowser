import SwiftUI
import UIKit

/// 左侧栏：空间切换 → 固定站点 → 书签 → 文件夹 → 标签列表。
struct SidebarView: View {

    @Environment(BrowserStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @State private var editingFolderName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SpaceSwitcher()
                    PinnedSitesGrid()
                    bookmarkSection
                    folderSection
                    rootTabSection
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            bottomBar
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - 顶部搜索与控制栏

    private var topHeader: some View {
        HStack(spacing: 8) {
            Button {
                store.requestAddressBarFocus()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("搜索或输入网址")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                )
            }
            .buttonStyle(.plain)
            .help("聚焦地址栏 ⌘L")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.sidebarVisible = false
                }
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("收起侧边栏 ⌘⌃S")
        }
        .padding(.horizontal, 12)
        .padding(.top, settings.hideStatusBar ? 10 : 0)
        .safeAreaPadding(.top)
        .padding(.bottom, 4)
    }

    // MARK: - 底部常驻栏

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(0.2))
                .frame(height: 0.5)

            Button {
                store.newTab(url: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("新建标签页")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .safeAreaPadding(.bottom)
        }
    }

    // MARK: - 书签

    @ViewBuilder
    private var bookmarkSection: some View {
        BookmarkSidebarSection()
    }

    // MARK: - 文件夹

    @ViewBuilder
    private var folderSection: some View {
        if !store.currentSpaceFolders.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader(title: "文件夹", action: {
                    store.addFolder(name: "新文件夹", parentID: nil)
                })

                ForEach(store.currentSpaceFolders) { folder in
                    FolderRow(folder: folder)
                }
            }
        }
    }

    // MARK: - 根级标签

    private var rootTabSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(store.rootTabs) { tab in
                TabRow(tab: tab)
            }
        }
    }
}

// MARK: - 子组件

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// 可展开的文件夹。展开后直接列出里面的标签，标签可以再拖回根级。
struct FolderRow: View {
    let folder: TabFolder

    @Environment(BrowserStore.self) private var store
    @State private var isExpanded = false
    @State private var isEditingName = false
    @State private var draftName = ""

    private var containedTabs: [BrowserTab] { store.tabs(inFolder: folder.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 12)
                }
                .buttonStyle(.borderless)

                if isEditingName {
                    TextField("名称", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                        .onSubmit { commitRename() }
                        #if os(macOS)
                        .onExitCommand { isEditingName = false }
                        #endif
                } else {
                    Text(folder.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            draftName = folder.name
                            isEditingName = true
                        }
                }

                Spacer()

                Text("\(containedTabs.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background {
                if isExpanded {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
            }
            // 拖标签进文件夹
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                store.moveTab(id, toFolder: folder.id)
                return true
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(containedTabs) { tab in
                        TabRow(tab: tab)
                            .padding(.leading, 10)
                    }
                }
            }
        }
        .contextMenu {
            Button("重命名") {
                draftName = folder.name
                isEditingName = true
            }
            Button("删除文件夹", role: .destructive) {
                store.removeFolder(folder.id)
            }
        }
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.renameFolder(folder.id, to: trimmed)
        }
        isEditingName = false
    }
}

struct TabRow: View {
    let tab: BrowserTab

    @Environment(BrowserStore.self) private var store
    @State private var isHovering = false

    private var isSelected: Bool { store.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(url: tab.faviconURL, letter: tab.displayTitle.first.map(String.init))
                .frame(width: 16, height: 16)

            Text(tab.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)

            if store.runtime(for: tab.id).isLoading {
                ProgressView().controlSize(.mini)
            }

            Spacer(minLength: 0)

            if isHovering || isSelected {
                Button {
                    store.close(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1.5)
            } else if isHovering {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.select(tab.id) }
        .onHover { isHovering = $0 }
        // 让标签可以被拖动排序或拖进文件夹
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first,
                  let sourceID = UUID(uuidString: raw),
                  sourceID != tab.id
            else { return false }

            var orderedIDs = store.currentSpaceTabs.map(\.id)
            guard let fromIndex = orderedIDs.firstIndex(of: sourceID),
                  let toIndex = orderedIDs.firstIndex(of: tab.id)
            else { return false }

            orderedIDs.remove(at: fromIndex)
            orderedIDs.insert(sourceID, at: toIndex)
            withAnimation(.easeInOut(duration: 0.2)) {
                store.reorderTabs(orderedIDs)
            }
            return true
        }
        .contextMenu {
            Button("关闭") { store.close(tab.id) }
            Button("关闭其他") { store.closeOthers(keeping: tab.id) }
            Divider()
            Button("移到根级") { store.moveTab(tab.id, toFolder: nil) }
        }
    }
}

/// Favicon 内存图片缓存，避免标签行与网格反复解码相同图标
@MainActor
final class FaviconCache {
    static let shared = FaviconCache()
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 250
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// 站点 Favicon：支持加载真实图标，加载失败或无图标时用域名首字母占位。
struct FaviconView: View {
    let url: URL?
    let letter: String?

    @State private var loadedImage: UIImage?

    private var iconURL: URL? {
        guard let url else { return nil }
        if ["ico", "png", "svg", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
            return url
        }
        guard let host = url.host(), !host.isEmpty else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            } else if let iconURL {
                placeholder
                    .task(id: iconURL) {
                        if let cached = FaviconCache.shared.image(for: iconURL) {
                            loadedImage = cached
                            return
                        }
                        guard let (data, response) = try? await URLSession.shared.data(from: iconURL),
                              (response as? HTTPURLResponse)?.statusCode == 200,
                              let image = UIImage(data: data) else {
                            return
                        }
                        FaviconCache.shared.insert(image, for: iconURL)
                        loadedImage = image
                    }
            } else {
                placeholder
            }
        }
        .frame(width: 16, height: 16)
        .onAppear {
            if let iconURL, loadedImage == nil {
                loadedImage = FaviconCache.shared.image(for: iconURL)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 16, height: 16)
            .overlay {
                Text((letter ?? "?").uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
    }
}

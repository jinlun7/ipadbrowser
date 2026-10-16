import SwiftUI

/// 顶部工具栏：导航按钮 + 地址栏 + 收藏 + 设置。
struct ToolbarView: View {

    @Environment(BrowserStore.self) private var store
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            if !store.sidebarVisible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.sidebarVisible = true }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .help("展开侧边栏 ⌘⌃S")
            }

            navButton("chevron.backward", enabled: currentCanGoBack, help: "后退") {
                if let id = store.selectedTabID { store.goBack(for: id) }
            }
            navButton("chevron.forward", enabled: currentCanGoForward, help: "前进") {
                if let id = store.selectedTabID { store.goForward(for: id) }
            }
            if currentIsLoading {
                navButton("xmark", enabled: true, help: "停止") {
                    if let id = store.selectedTabID { store.stopLoading(for: id) }
                }
            } else {
                navButton("arrow.clockwise", enabled: true, help: "刷新") {
                    if let id = store.selectedTabID { store.reload(for: id) }
                }
            }

            AddressBar()

            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isCurrentPageBookmarked ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(isCurrentPageBookmarked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.selectedTab?.url == nil)
            .help(isCurrentPageBookmarked ? "从书签中移除 ⌘D" : "添加为书签 ⌘D")

            Button {
                PasswordAutofillHelper.shared.triggerPasswordAutofillForActiveTab()
            } label: {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.selectedTab?.url == nil)
            .help("从 iCloud 钥匙串填充密码")

            if let url = store.selectedTab?.url {
                ShareLink(item: url, subject: Text(store.selectedTab?.displayTitle ?? "")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("分享此网页")
            } else {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(true)
            }

            navButton("gearshape", enabled: true, help: "设置") {
                store.settingsPresented = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(uiColor: .systemBackground))
    }

    private var isCurrentPageBookmarked: Bool {
        guard let url = store.selectedTab?.url else { return false }
        return bookmarks.isBookmarked(url) != nil
    }

    private func toggleBookmark() {
        guard let tab = store.selectedTab, let url = tab.url else { return }
        bookmarks.toggle(url, title: tab.displayTitle)
    }

    private var currentCanGoBack: Bool {
        guard let id = store.selectedTabID else { return false }
        return store.runtime(for: id).canGoBack
    }

    private var currentCanGoForward: Bool {
        guard let id = store.selectedTabID else { return false }
        return store.runtime(for: id).canGoForward
    }

    private var currentIsLoading: Bool {
        guard let id = store.selectedTabID else { return false }
        return store.runtime(for: id).isLoading
    }

    private func navButton(
        _ systemName: String,
        enabled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }
}

/// 地址栏。
///
/// **关键**：输入框的 `@State text` 只在获得焦点或内容被外部重置时同步自当前 URL，
/// 提交之前绝不回写 `store.tabs[].url`。否则每敲一个字符都会让
/// `WebContainer.updateUIView` 判定「URL 变了」并重新加载页面。
struct AddressBar: View {

    @Environment(BrowserStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @FocusState private var isFocused: Bool
    @State private var text: String = ""
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 6) {
            if store.currentSpaceIsIncognito {
                Image(systemName: "eye.slash.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("无痕空间")
            } else if let url = store.selectedTab?.url, url.scheme == "https" {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            TextField("搜索或输入网址", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        isEditing = true
                        text = store.selectedTab?.url?.absoluteString ?? ""
                    } else {
                        isEditing = false
                        syncFromSelection()
                    }
                }
                .onChange(of: store.selectedTabID) { _, _ in
                    if !isFocused { syncFromSelection() }
                }
                .onChange(of: store.selectedTab?.url) { _, _ in
                    if !isFocused { syncFromSelection() }
                }
                .onChange(of: settings.revealsPasswordsOnFocus) { _, _ in
                    if !isFocused { syncFromSelection() }
                }
                // ⌘L：store 里的计数器每次自增，连续按也能反复触发。
                .onChange(of: store.addressBarFocusRequest) { _, _ in
                    isFocused = true
                }
                .onAppear {
                    syncFromSelection()
                }

            if isFocused && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
        )
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
            }
        }
    }

    private func syncFromSelection() {
        guard !isEditing else { return }
        guard let url = store.selectedTab?.url else {
            text = ""
            return
        }
        if settings.revealsPasswordsOnFocus {
            text = url.host() ?? url.absoluteString
        } else {
            text = url.absoluteString
        }
    }

    private func commit() {
        defer { isFocused = false }
        guard let url = store.resolveAddressBarInput(text) else { return }
        if store.selectedTabID == nil {
            store.newTab(url: url)
        } else {
            store.navigateSelected(to: url)
        }
    }
}

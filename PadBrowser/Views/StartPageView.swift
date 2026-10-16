import SwiftUI

/// 新标签页起始页。
///
/// 当标签页尚未加载任何网址（`tab.url == nil`）时展示。
/// 包含大搜索框、当前空间的固定站点快捷访问网格以及快捷操作。
struct StartPageView: View {

    let tabID: UUID
    @Environment(BrowserStore.self) private var store

    @State private var query: String = ""
    @State private var isAddingSite: Bool = false
    @State private var newSiteTitle: String = ""
    @State private var newSiteURL: String = ""
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // 头部：空间信息与标志
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((store.currentSpaceIsIncognito ? Color.orange : Color.accentColor).opacity(0.12))
                            .frame(width: 84, height: 84)
                            .blur(radius: 12)

                        Image(systemName: store.currentSpaceIsIncognito ? "eye.slash.circle.fill" : "safari.fill")
                            .font(.system(size: 54))
                            .foregroundStyle((store.currentSpaceIsIncognito ? Color.orange : Color.accentColor).gradient)
                    }

                    HStack(spacing: 6) {
                        Text(store.currentSpace?.name ?? "新标签页")
                            .font(.system(size: 24, weight: .bold))
                        if store.currentSpaceIsIncognito {
                            Text("无痕")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // 居中 Liquid Glass 胶囊大搜索框
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("在 \(store.searchEngine.displayName) 搜索或输入网址…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
                        .onSubmit(commitSearch)

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 52)
                .glassCapsule()
                .overlay {
                    if isSearchFocused {
                        Capsule()
                            .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                    }
                }
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

                // 固定站点网格（Liquid Glass 卡片）
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                            Text("固定站点与快捷方式")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            isAddingSite = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("添加")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.currentSpacePinnedSites) { site in
                            Button {
                                store.navigateSelected(to: site.url)
                            } label: {
                                VStack(spacing: 8) {
                                    FaviconView(url: site.url, letter: site.title.first.map(String.init))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .fill(Color(uiColor: .systemBackground))
                                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
                                        )

                                    Text(site.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .frame(width: 88, height: 76)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("在新标签打开") {
                                    store.newTab(url: site.url)
                                }
                                Button("取消固定", role: .destructive) {
                                    store.unpin(site.id)
                                }
                            }
                        }

                        // 添加按钮方块
                        Button {
                            isAddingSite = true
                        } label: {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }

                                Text("新建快捷")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 88, height: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .glassSurface(cornerRadius: 22)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)

                // 快捷提示（徽章样式）
                HStack(spacing: 12) {
                    shortcutTag("⌘T", label: "新标签")
                    shortcutTag("⌘W", label: "关闭标签")
                    shortcutTag("⌘⇧P", label: "命令面板")
                    shortcutTag("⌘+", label: "放大")
                    shortcutTag("⌘-", label: "缩小")
                }
                .padding(.top, 4)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack {
                Color(uiColor: .systemBackground)
                RadialGradient(
                    colors: [
                        (store.currentSpaceIsIncognito ? Color.orange : Color.accentColor).opacity(0.05),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 400
                )
            }
        }
        .sheet(isPresented: $isAddingSite) {
            addSiteSheet
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func shortcutTag(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private var addSiteSheet: some View {
        NavigationStack {
            Form {
                Section("站点信息") {
                    TextField("网站名称", text: $newSiteTitle)
                    TextField("https://example.com", text: $newSiteURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("添加固定站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isAddingSite = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let trimmed = newSiteURL.trimmingCharacters(in: .whitespaces)
                        let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                        if let url = URL(string: normalized) {
                            let title = newSiteTitle.trimmingCharacters(in: .whitespaces)
                            store.pin(PinnedSite(
                                title: title.isEmpty ? (url.host() ?? "站点") : title,
                                url: url,
                                spaceID: store.currentSpaceID,
                                order: store.currentSpacePinnedSites.count
                            ))
                            newSiteTitle = ""
                            newSiteURL = ""
                            isAddingSite = false
                        }
                    }
                    .disabled(newSiteURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(240)])
    }

    private func commitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let url = store.resolveAddressBarInput(trimmed) {
            store.navigateSelected(to: url)
        }
    }
}

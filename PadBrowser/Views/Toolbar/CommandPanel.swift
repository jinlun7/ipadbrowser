import SwiftUI

/// 命令面板（⌘⇧P）。输入即过滤，回车执行。
///
/// 这块对应的是「一个面板，打开一切」的交互：新建标签、开关侧边栏、
/// 切换空间、打开地址、退出阅读等，都从这里进。
struct CommandPanel: View {

    @Environment(BrowserStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private struct Command: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let symbol: String
        let run: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                // 既可以搜命令，也可以直接输网址
                TextField("输入命令或网址…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit { executeFirst() }
            }
            .padding(16)

            Rectangle()
                .fill(Color(.separator).opacity(0.35))
                .frame(height: 0.5)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredCommands) { command in
                        Button {
                            command.run()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.symbol)
                                    .frame(width: 22)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.title)
                                    Text(command.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 340)
        }
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(radius: 24)
        )
        .padding(40)
        .onAppear { isFocused = true }
    }

    // MARK: - 命令表

    private var filteredCommands: [Command] {
        let all = buildCommands()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(text)
                || $0.detail.localizedCaseInsensitiveContains(text)
        }
    }

    private func buildCommands() -> [Command] {
        var commands: [Command] = [
            Command(title: "新建标签页", detail: "在当前空间开一个空白标签",
                    symbol: "plus.rectangle.on.rectangle") { store.newTab(url: nil) },
            Command(title: "切换侧边栏", detail: store.sidebarVisible ? "收起" : "展开",
                    symbol: "sidebar.leading") { withAnimation { store.sidebarVisible.toggle() } },
            Command(title: "密码自动填充", detail: "唤起系统 iCloud 钥匙串填充当前网页表单",
                    symbol: "key.fill") { PasswordAutofillHelper.shared.triggerPasswordAutofillForActiveTab() },
            Command(title: "放大网页 (⌘+)", detail: "当前缩放: \(settings.pageZoomPercentage)%",
                    symbol: "plus.magnifyingglass") { settings.zoomIn() },
            Command(title: "缩小网页 (⌘-)", detail: "当前缩放: \(settings.pageZoomPercentage)%",
                    symbol: "minus.magnifyingglass") { settings.zoomOut() },
            Command(title: "重置网页缩放 (⌘0)", detail: "恢复至 100%",
                    symbol: "arrow.counterclockwise") { settings.resetZoom() }
        ]

        for space in store.spaces {
            commands.append(
                Command(title: "切换到「\(space.name)」", detail: space.isIncognito ? "无痕空间" : "普通空间",
                        symbol: space.isIncognito ? "eye.slash" : "circle") {
                    store.switchSpace(to: space.id)
                }
            )
        }

        for site in store.currentSpacePinnedSites {
            commands.append(
                Command(title: "打开 \(site.title)", detail: site.url.absoluteString,
                        symbol: "globe") {
                    store.newTab(url: site.url)
                }
            )
        }

        if let tab = store.selectedTab {
            commands.append(
                Command(title: "刷新「\(tab.displayTitle)」", detail: tab.url?.absoluteString ?? "",
                        symbol: "arrow.clockwise") { store.reload(for: tab.id) }
            )
        }

        // 直接输网址也能用
        let text = query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty, let url = store.resolveAddressBarInput(text) {
            commands.insert(
                Command(title: "打开 \(url.absoluteString)", detail: "在当前标签打开",
                        symbol: "arrow.up.forward") {
                    if store.selectedTabID == nil {
                        store.newTab(url: url)
                    } else {
                        store.navigateSelected(to: url)
                    }
                },
                at: 0
            )
        }

        return commands
    }

    private func executeFirst() {
        if let first = filteredCommands.first {
            first.run()
            dismiss()
        }
    }
}

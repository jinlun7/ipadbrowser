import SwiftUI
import UniformTypeIdentifiers

/// 设置页。以 sheet 形式呈现，不单独做一个 scene——
/// 浏览器的主界面应该占满屏幕，设置是从侧边滑出来的次级界面。
struct SettingsView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BrowserStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var isConfirmingClear = false
    @State private var importMessage: String?

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                browserSection(settings: $settings)
                appearanceSection(settings: $settings)
                tabsSection(settings: $settings)
                bookmarksSection(bookmarks: bookmarks)
                privacySection(settings: $settings)
                userScriptsSection()
                dataSection()
                aboutSection()
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.html],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(
            "导入书签",
            isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            ),
            presenting: importMessage
        ) { _ in
            Button("好", role: .cancel) { importMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - 浏览器

    private func browserSection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker("搜索引擎", selection: settings.searchEngine) {
                ForEach(SearchEngine.allCases) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }

            Picker("启动时", selection: settings.restoreSessionOnLaunch) {
                Text("恢复上次的标签页").tag(true)
                Text("总是打开新起始页").tag(false)
            }

            LabeledContent("起始页地址") {
                HStack(spacing: 6) {
                    TextField("留空则用起始页", text: settings.startURLString)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !settings.startURLString.wrappedValue.isEmpty {
                        Button {
                            settings.startURLString.wrappedValue = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                .frame(maxWidth: 240)
            }
        } header: {
            Text("浏览器")
        } footer: {
            Text("地址栏里输入域名会直接打开；包含空格或没有点号时会作为搜索词，交给上面的搜索引擎。")
        }
    }

    // MARK: - 标签页

    private func tabsSection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker("标签页布局", selection: settings.tabLayoutMode) {
                ForEach(SettingsStore.TabLayoutMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.tabLayoutMode.wrappedValue.note)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("常驻标签数", selection: settings.maxResidentTabs) {
                ForEach(SettingsStore.ResidentTabOption.allCases) { option in
                    Text(option.label).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if let option = SettingsStore.ResidentTabOption(rawValue: settings.maxResidentTabs.wrappedValue) {
                Text(option.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("侧边栏宽度")
                    Spacer()
                    Text("\(Int(settings.sidebarWidth.wrappedValue)) pt")
                        .foregroundStyle(.secondary)
                    Button("重置") {
                        settings.sidebarWidth.wrappedValue = SettingsStore.defaultSidebarWidth
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Slider(
                    value: settings.sidebarWidth,
                    in: SettingsStore.minSidebarWidth...SettingsStore.maxSidebarWidth,
                    step: 10
                )
            }
        } header: {
            Text("标签页")
        } footer: {
            Text("在 iPad 横屏下推荐使用「纯垂直标签」，侧边栏即是标签列表。可直接按住屏幕中的侧边栏分割条自由拖拽宽度，双击快速复原默认。")
        }
    }

    // MARK: - 外观

    private func appearanceSection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            Picker("主题", selection: settings.themeMode) {
                ForEach(SettingsStore.ThemeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("网页缩放")
                Spacer()
                if settings.pageZoomPercentage.wrappedValue != SettingsStore.defaultPageZoom {
                    Button("重置") {
                        settings.pageZoomPercentage.wrappedValue = SettingsStore.defaultPageZoom
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .padding(.trailing, 4)
                }
                Picker("", selection: settings.pageZoomPercentage) {
                    ForEach(SettingsStore.pageZoomLevels, id: \.self) { level in
                        Text("\(level)%").tag(level)
                    }
                }
                .labelsHidden()
            }

            Toggle("隐藏状态栏（时间与电量）", isOn: settings.hideStatusBar)
            Toggle("显示书签栏", isOn: settings.showBookmarkBar)
        } header: {
            Text("外观与显示")
        } footer: {
            Text("支持通过快捷键 ⌘+ 放大、⌘- 缩小、⌘0 复原默认缩放；在 iPad 上隐藏原生状态栏可最大化纵向浏览面积。")
        }
    }

    // MARK: - 书签

    private func bookmarksSection(bookmarks: BookmarkStore) -> some View {
        Section {
            LabeledContent("已保存", value: "\(bookmarks.bookmarks.count) 条")
            LabeledContent("文件夹", value: "\(bookmarks.folders.count) 个")

            Button {
                isImporting = true
            } label: {
                Label("从其他浏览器导入…", systemImage: "square.and.arrow.down")
            }

            Button("清空全部书签", role: .destructive) {
                isConfirmingClear = true
            }
            .disabled(bookmarks.bookmarks.isEmpty)
        } header: {
            Text("书签")
        } footer: {
            Text("Chrome、Edge、Safari、Firefox 导出的书签 HTML 都是同一个格式，可以直接导入并保留完整目录结构。")
        }
        .confirmationDialog(
            "确定要删除全部 \(bookmarks.bookmarks.count) 条书签吗？",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("删除全部", role: .destructive) {
                bookmarks.removeAll()
                importMessage = "已清空书签"
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 隐私

    private func privacySection(settings: Bindable<SettingsStore>) -> some View {
        Section {
            Toggle("拦截广告与追踪脚本", isOn: settings.blocksAds)
            Toggle("地址栏聚焦时显示完整网址", isOn: settings.revealsPasswordsOnFocus)
        } header: {
            Text("隐私与安全")
        } footer: {
            Text("拦截广告基于 WebKit 原生规则内核；浏览历史只保存在这台设备上。")
        }
    }

    // MARK: - 用户脚本

    private func userScriptsSection() -> some View {
        Section {
            let scripts = UserScriptStore.shared.entries
            if scripts.isEmpty {
                Text("暂无已安装的用户脚本")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scripts) { script in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(script.name)
                                .font(.system(size: 14, weight: .medium))
                            Text(script.matches.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { script.isEnabled },
                            set: { UserScriptStore.shared.setEnabled($0, for: script.id) }
                        ))
                        .labelsHidden()
                    }
                }
            }
        } header: {
            Text("用户脚本")
        } footer: {
            Text("在指定网址匹配并注入自定义 JavaScript 脚本增强网页功能。")
        }
    }

    // MARK: - 数据

    private func dataSection() -> some View {
        Section("数据") {
            LabeledContent("当前空间标签", value: "\(store.currentSpaceTabs.count) 个")
            LabeledContent("空间数量", value: "\(store.spaces.count) 个")
        }
    }

    // MARK: - 关于

    private func aboutSection() -> some View {
        Section("关于") {
            LabeledContent("版本", value: appVersion)
            LabeledContent("引擎", value: "WKWebView（系统 WebKit）")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = "读取失败：\(error.localizedDescription)"

        case .success(let urls):
            guard let url = urls.first else { return }
            // fileImporter 给的是安全作用域 URL，必须显式开始访问，
            // 否则在 App Group / 沙盒外来源的文件上读不到内容。
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let result = bookmarks.importNetscapeHTML(text)
                importMessage = "导入 \(result.bookmarkCount) 条书签、\(result.folderCount) 个文件夹"
                    + (result.skippedInvalidURL > 0 ? "，跳过 \(result.skippedInvalidURL) 条无效链接" : "")
            } catch {
                importMessage = "解析失败：\(error.localizedDescription)"
            }
        }
    }
}

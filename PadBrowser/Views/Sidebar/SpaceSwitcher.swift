import SwiftUI

/// 空间切换器。每个空间有独立的标签、文件夹和固定站点。
struct SpaceSwitcher: View {

    @Environment(BrowserStore.self) private var store
    @State private var isAddingSpace = false
    @State private var newSpaceName = ""
    @State private var newSpaceIncognito = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(store.spaces) { space in
                    SpaceChip(
                        name: space.name,
                        isIncognito: space.isIncognito,
                        isActive: space.id == store.currentSpaceID
                    ) {
                        store.switchSpace(to: space.id)
                    }
                    .contextMenu {
                        if store.spaces.count > 1 {
                            Button("删除空间", role: .destructive) {
                                store.removeSpace(space.id)
                            }
                        }
                    }
                }

                Button {
                    isAddingSpace = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
            }

            if isAddingSpace {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("空间名称", text: $newSpaceName)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )

                    Toggle("无痕空间", isOn: $newSpaceIncognito)
                        .font(.subheadline)
                        .padding(.horizontal, 2)

                    HStack(spacing: 8) {
                        Button {
                            let name = newSpaceName.trimmingCharacters(in: .whitespaces)
                            store.addSpace(name: name.isEmpty ? "新空间" : name,
                                           incognito: newSpaceIncognito)
                            newSpaceName = ""
                            newSpaceIncognito = false
                            isAddingSpace = false
                        } label: {
                            Text("创建")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            newSpaceName = ""
                            newSpaceIncognito = false
                            isAddingSpace = false
                        } label: {
                            Text("取消")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
        }
    }
}

struct SpaceChip: View {
    let name: String
    let isIncognito: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isIncognito ? "eye.slash.fill" : (isActive ? "folder.fill" : "folder"))
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isActive {
                    Capsule()
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                }
            }
            .foregroundStyle(isActive ? (isIncognito ? Color.orange : Color.primary) : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

/// 固定站点网格。点一下就在当前空间开一个新标签。
struct PinnedSitesGrid: View {

    @Environment(BrowserStore.self) private var store
    @State private var isAdding = false
    @State private var draftTitle = ""
    @State private var draftURL = ""

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 8)]

    var body: some View {
        if !store.currentSpacePinnedSites.isEmpty || isAdding {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "固定站点", action: { isAdding = true })

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(store.currentSpacePinnedSites) { site in
                    Button {
                        store.newTab(url: site.url)
                    } label: {
                        VStack(spacing: 4) {
                            FaviconView(url: site.url, letter: site.title.first.map(String.init))
                                .frame(width: 28, height: 28)
                            Text(site.title)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("取消固定", role: .destructive) {
                            store.unpin(site.id)
                        }
                    }
                }
            }

            if isAdding {
                VStack(spacing: 8) {
                    HStack {
                        TextField("名称", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )

                    HStack {
                        TextField("https://example.com", text: $draftURL)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )

                    HStack(spacing: 8) {
                        Button {
                            let trimmed = draftURL.trimmingCharacters(in: .whitespaces)
                            let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
                            if let url = URL(string: normalized) {
                                let title = draftTitle.trimmingCharacters(in: .whitespaces)
                                store.pin(PinnedSite(
                                    title: title.isEmpty ? (url.host() ?? "站点") : title,
                                    url: url,
                                    spaceID: store.currentSpaceID,
                                    order: store.currentSpacePinnedSites.count
                                ))
                                draftTitle = ""
                                draftURL = ""
                                isAdding = false
                            }
                        } label: {
                            Text("添加")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            draftTitle = ""
                            draftURL = ""
                            isAdding = false
                        } label: {
                            Text("取消")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
        }
    }
}
}


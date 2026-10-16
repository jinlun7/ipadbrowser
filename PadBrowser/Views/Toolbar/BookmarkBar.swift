import SwiftUI

/// 书签栏：地址栏下方的一条横栏，只显示根级书签。
///
/// 不显示文件夹——横条的空间本来就紧，文件夹留给侧边栏。
/// 点一下在当前标签打开，右键（或长按）弹出菜单。
struct BookmarkBar: View {

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BrowserStore.self) private var store
    @State private var isEditingFolders = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(bookmarks.bookmarkBarItems) { bookmark in
                    Button {
                        open(bookmark)
                    } label: {
                        HStack(spacing: 5) {
                            FaviconView(url: bookmark.url,
                                        letter: bookmark.title.first.map(String.init))
                            Text(bookmark.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("在新标签页打开") {
                            store.newTab(url: bookmark.url)
                        }
                        Button("用无痕标签打开") {
                            openIncognito(bookmark)
                        }
                        Divider()
                        Button("复制链接") {
                            UIPasteboard.general.url = bookmark.url
                        }
                        Divider()
                        Button("删除书签", role: .destructive) {
                            bookmarks.remove(bookmark.id)
                        }
                    }
                }

                if bookmarks.bookmarkBarItems.isEmpty {
                    Text("暂无书签（按 ⌘D 添加）")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                }

                Spacer(minLength: 0)

                Button {
                    isEditingFolders = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .help("管理书签文件夹")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $isEditingFolders) {
            BookmarkFolderManager()
                .frame(minWidth: 480, minHeight: 420)
        }
    }

    private func open(_ bookmark: Bookmark) {
        if store.selectedTabID == nil {
            store.newTab(url: bookmark.url)
        } else {
            store.navigateSelected(to: bookmark.url)
        }
    }

    private func openIncognito(_ bookmark: Bookmark) {
        if let incognitoSpace = store.spaces.first(where: { $0.isIncognito }) {
            store.switchSpace(to: incognitoSpace.id)
            store.newTab(url: bookmark.url)
        } else {
            store.addSpace(name: "无痕", incognito: true)
            store.newTab(url: bookmark.url)
        }
    }
}

/// 书签文件夹管理。
struct BookmarkFolderManager: View {

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(\.dismiss) private var dismiss
    @State private var newFolderName = ""

    var body: some View {
        @Bindable var bookmarks = bookmarks

        NavigationStack {
            List {
                Section("新建") {
                    HStack {
                        TextField("文件夹名称", text: $newFolderName)
                        Button("添加") {
                            let name = newFolderName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            _ = bookmarks.addFolder(name: name)
                            newFolderName = ""
                        }
                        .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !bookmarks.rootFolders.isEmpty {
                    Section("文件夹") {
                        ForEach(bookmarks.rootFolders) { folder in
                            FolderManagementRow(folder: folder)
                        }
                    }
                }

                Section {
                    if bookmarks.bookmarks(in: nil).isEmpty {
                        Text("根级还没有书签")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bookmarks.bookmarks(in: nil)) { bookmark in
                            BookmarkManagementRow(bookmark: bookmark)
                        }
                    }
                } header: {
                    Text("根级书签（会显示在书签栏）")
                }
            }
            .navigationTitle("书签文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct FolderManagementRow: View {
    let folder: BookmarkFolder
    @Environment(BookmarkStore.self) private var bookmarks
    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            if isRenaming {
                TextField("名称", text: $draftName)
                    .onSubmit { commit() }
            } else {
                Text(folder.name)
            }

            Spacer()

            Text("\(BookmarkTree.recursiveCount(of: folder.id, folders: bookmarks.folders, bookmarks: bookmarks.bookmarks))")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                draftName = folder.name
                isRenaming = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                bookmarks.removeFolder(folder.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func commit() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { bookmarks.renameFolder(folder.id, to: trimmed) }
        isRenaming = false
    }
}

private struct BookmarkManagementRow: View {
    let bookmark: Bookmark
    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        HStack {
            FaviconView(url: bookmark.url, letter: bookmark.title.first.map(String.init))
            Text(bookmark.title).lineLimit(1)
            Spacer()
            Button(role: .destructive) {
                bookmarks.remove(bookmark.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

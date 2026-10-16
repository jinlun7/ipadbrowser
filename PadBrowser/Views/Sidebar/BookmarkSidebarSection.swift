import SwiftUI

/// 侧边栏里的书签树。
///
/// 和 `FixedSites`（固定站点）的区别：固定站点是「空间内的快捷入口」，
/// 书签是跨空间共享的持久数据。
struct BookmarkSidebarSection: View {

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BrowserStore.self) private var store
    @State private var isExpanded = true

    var body: some View {
        let roots = bookmarks.bookmarks(in: nil)
        let rootFolders = bookmarks.rootFolders
        let totalCount = roots.count + rootFolders.count

        if totalCount > 0 {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 12)
                            Text("书签")
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                            Text("\(totalCount)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        _ = bookmarks.addFolder(name: "新文件夹")
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 4)

                if isExpanded {
                    ForEach(roots) { bookmark in
                        BookmarkRow(bookmark: bookmark)
                    }

                    ForEach(rootFolders) { folder in
                        BookmarkFolderRow(folder: folder)
                    }
                }
            }
        }
    }
}

private struct BookmarkRow: View {

    let bookmark: Bookmark

    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(BrowserStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(url: bookmark.url, letter: bookmark.title.first.map(String.init))
            Text(bookmark.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                bookmarks.remove(bookmark.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.selectedTabID == nil {
                store.newTab(url: bookmark.url)
            } else {
                store.navigateSelected(to: bookmark.url)
            }
        }
        .contextMenu {
            Button("在新标签页打开") { store.newTab(url: bookmark.url) }
            Button("复制链接") { UIPasteboard.general.url = bookmark.url }
            Divider()
            Button("删除书签", role: .destructive) { bookmarks.remove(bookmark.id) }
        }
        // iOS 27 起 swipeActions 不再局限于 List，自定义行也能左滑。
        // 旧系统上这个修饰符会静默失效，所以内容菜单必须保留。
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                bookmarks.remove(bookmark.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

private struct BookmarkFolderRow: View {

    let folder: BookmarkFolder

    @Environment(BookmarkStore.self) private var bookmarks
    @State private var isExpanded = true

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

                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(folder.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(BookmarkTree.recursiveCount(of: folder.id, folders: bookmarks.folders, bookmarks: bookmarks.bookmarks))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())

            if isExpanded {
                ForEach(bookmarks.bookmarks(in: folder.id)) { bookmark in
                    BookmarkRow(bookmark: bookmark)
                }
                ForEach(bookmarks.children(of: folder.id)) { child in
                    BookmarkFolderRow(folder: child)
                }
            }
        }
        .contextMenu {
            Button("删除文件夹", role: .destructive) {
                bookmarks.removeFolder(folder.id)
            }
        }
    }
}

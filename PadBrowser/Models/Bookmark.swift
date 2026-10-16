import Foundation

/// 一条书签。文件夹树用 `folderID` 表达，`nil` 表示在根级。
struct Bookmark: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var folderID: UUID?
    var order: Int
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        folderID: UUID? = nil,
        order: Int = 0,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folderID = folderID
        self.order = order
        self.dateAdded = dateAdded
    }
}

/// 书签文件夹，同样支持嵌套。
struct BookmarkFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var parentID: UUID?
    var order: Int

    init(id: UUID = UUID(), name: String, parentID: UUID? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.order = order
    }
}

enum BookmarkTree {
    static func roots(folders: [BookmarkFolder]) -> [BookmarkFolder] {
        folders.filter { $0.parentID == nil }.sorted { $0.order < $1.order }
    }

    static func children(of folderID: UUID, in folders: [BookmarkFolder]) -> [BookmarkFolder] {
        folders.filter { $0.parentID == folderID }.sorted { $0.order < $1.order }
    }

    static func bookmarks(in folderID: UUID?, from bookmarks: [Bookmark]) -> [Bookmark] {
        bookmarks.filter { $0.folderID == folderID }.sorted { $0.order < $1.order }
    }

    /// 某文件夹下直接包含的条目数（书签 + 子文件夹）。
    static func directCount(of folderID: UUID, folders: [BookmarkFolder], bookmarks: [Bookmark]) -> Int {
        children(of: folderID, in: folders).count
            + BookmarkTree.bookmarks(in: folderID, from: bookmarks).count
    }

    /// 该文件夹及其所有后代里一共有多少条书签。
    static func recursiveCount(of folderID: UUID, folders: [BookmarkFolder], bookmarks: [Bookmark]) -> Int {
        var total = BookmarkTree.bookmarks(in: folderID, from: bookmarks).count
        for child in children(of: folderID, in: folders) {
            total += recursiveCount(of: child.id, folders: folders, bookmarks: bookmarks)
        }
        return total
    }

    /// 计算祖先链，用于面包屑显示。
    static func ancestors(of folderID: UUID, folders: [BookmarkFolder]) -> [BookmarkFolder] {
        var result: [BookmarkFolder] = []
        var current = folderID
        // 加个上限，防止导入的数据里出现环导致死循环。
        var guard_ = 0
        while let folder = folders.first(where: { $0.id == current }),
              let parent = folder.parentID,
              guard_ < 64 {
            result.append(folder)
            current = parent
            guard_ += 1
        }
        return result.reversed()
    }
}

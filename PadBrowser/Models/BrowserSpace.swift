import Foundation

/// 一个浏览空间。每个空间有自己独立的标签集合、文件夹和固定站点。
///
/// 无痕空间的实现方式是**独立的 `WKWebsiteDataStore.nonPersistent()` 实例**，
/// 而不是给标签打一个布尔标记然后共用默认 store——共用 store 的话
/// 无痕标签依然会把 Cookie 写进磁盘，隔离就是假的。
struct BrowserSpace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    /// 为 true 时，本空间内所有标签使用不落盘的数据容器。
    var isIncognito: Bool

    var order: Int

    init(id: UUID = UUID(), name: String, isIncognito: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.isIncognito = isIncognito
        self.order = order
    }
}

/// 可嵌套的标签文件夹。`parentID == nil` 表示位于侧边栏根级。
struct TabFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var spaceID: UUID
    var parentID: UUID?
    var order: Int

    init(
        id: UUID = UUID(),
        name: String,
        spaceID: UUID,
        parentID: UUID? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.spaceID = spaceID
        self.parentID = parentID
        self.order = order
    }

    /// 该文件夹的直接子文件夹。
    func children(of all: [TabFolder]) -> [TabFolder] {
        all.filter { $0.parentID == id && $0.spaceID == spaceID }
            .sorted { $0.order < $1.order }
    }

    /// 根级文件夹。
    static func roots(in all: [TabFolder], spaceID: UUID) -> [TabFolder] {
        all.filter { $0.spaceID == spaceID && $0.parentID == nil }
            .sorted { $0.order < $1.order }
    }
}

/// 侧边栏快捷网格里的固定站点入口。
struct PinnedSite: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var url: URL
    var spaceID: UUID
    var order: Int

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        spaceID: UUID,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.spaceID = spaceID
        self.order = order
    }
}

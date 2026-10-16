import Foundation

/// 一个标签页。
///
/// **关键设计**：`id` 是这个标签页唯一的身份来源。WebView 的 SwiftUI identity
/// 必须绑定 `id`，绝不能绑定 `url` 或标题——否则地址栏每敲一个字符都会触发
/// `updateUIView` 重建整个 `WKWebView`，表现为「打字时页面疯狂重载」。
///
/// `lastKnownScrollY` 与 `url` 一起构成 jetsam 恢复所需的最小状态：
/// iOS 内存吃紧时会杀掉后台标签页的 WebView 进程，回来时只有这两个值
/// 能把页面还原到离开时的位置。
struct BrowserTab: Identifiable, Codable, Hashable {
    let id: UUID

    var url: URL?
    var title: String
    var faviconURL: URL?

    /// 所属空间。切换空间时各空间的标签互不可见。
    var spaceID: UUID

    /// 无痕标签不写 Cookie / 网站数据到磁盘。
    var isIncognito: Bool

    /// 固定到侧边栏的标签显示在快捷网格里。
    var isPinned: Bool

    /// 归属的文件夹，nil 表示直接在标签列表根级。
    var folderID: UUID?

    var createdAt: Date
    var lastKnownScrollY: Double

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "",
        faviconURL: URL? = nil,
        spaceID: UUID,
        isIncognito: Bool = false,
        isPinned: Bool = false,
        folderID: UUID? = nil,
        createdAt: Date = .now,
        lastKnownScrollY: Double = 0
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.spaceID = spaceID
        self.isIncognito = isIncognito
        self.isPinned = isPinned
        self.folderID = folderID
        self.createdAt = createdAt
        self.lastKnownScrollY = lastKnownScrollY
    }

    /// 标签条上显示的文字。标题为空时退化用域名，避免出现一排空白标签。
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return url?.host() ?? "新标签页"
    }
}

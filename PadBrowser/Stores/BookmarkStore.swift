import Foundation
import Observation

/// 书签仓库 + 其他浏览器的书签导入。
@MainActor
@Observable
final class BookmarkStore {

    private(set) var bookmarks: [Bookmark] = []
    private(set) var folders: [BookmarkFolder] = []
    private(set) var lastImportSummary: String?

    private let storeURL: URL
    private var saveTask: Task<Void, Never>?

    @ObservationIgnored
    private var urlIndex: [String: Bookmark] = [:]

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        storeURL = base.appendingPathComponent("bookmarks.json")
        load()
    }

    // MARK: - 查询

    var rootBookmarks: [Bookmark] { BookmarkTree.bookmarks(in: nil, from: bookmarks) }
    var rootFolders: [BookmarkFolder] { BookmarkTree.roots(folders: folders) }

    func bookmarks(in folderID: UUID?) -> [Bookmark] {
        BookmarkTree.bookmarks(in: folderID, from: bookmarks)
    }

    func children(of folderID: UUID) -> [BookmarkFolder] {
        BookmarkTree.children(of: folderID, in: folders)
    }

    /// 书签栏只显示根级书签，不含文件夹——横条空间有限。
    var bookmarkBarItems: [Bookmark] { rootBookmarks }

    func isBookmarked(_ url: URL) -> Bookmark? {
        urlIndex[normalize(url)]
    }

    private func normalize(_ url: URL) -> String {
        var text = url.absoluteString
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }

    private func rebuildIndex() {
        var index: [String: Bookmark] = [:]
        index.reserveCapacity(bookmarks.count)
        for b in bookmarks {
            index[normalize(b.url)] = b
        }
        urlIndex = index
    }

    // MARK: - 增删改

    @discardableResult
    func add(title: String, url: URL, folderID: UUID? = nil) -> Bookmark {
        let bookmark = Bookmark(
            title: title.isEmpty ? (url.host() ?? "书签") : title,
            url: url,
            folderID: folderID,
            order: bookmarks(in: folderID).count
        )
        bookmarks.append(bookmark)
        urlIndex[normalize(url)] = bookmark
        scheduleSave()
        return bookmark
    }

    func remove(_ id: UUID) {
        if let removed = bookmarks.first(where: { $0.id == id }) {
            urlIndex.removeValue(forKey: normalize(removed.url))
        }
        bookmarks.removeAll { $0.id == id }
        scheduleSave()
    }

    func toggle(_ url: URL, title: String) {
        if let existing = isBookmarked(url) {
            remove(existing.id)
        } else {
            add(title: title, url: url)
        }
    }

    func move(_ bookmarkID: UUID, toFolder folderID: UUID?) {
        guard let idx = bookmarks.firstIndex(where: { $0.id == bookmarkID }) else { return }
        bookmarks[idx].folderID = folderID
        bookmarks[idx].order = bookmarks(in: folderID).count
        urlIndex[normalize(bookmarks[idx].url)] = bookmarks[idx]
        scheduleSave()
    }

    @discardableResult
    func addFolder(name: String, parentID: UUID? = nil) -> BookmarkFolder {
        let siblings = parentID.map { children(of: $0) } ?? rootFolders
        let folder = BookmarkFolder(name: name, parentID: parentID, order: siblings.count)
        folders.append(folder)
        scheduleSave()
        return folder
    }

    /// 删除文件夹时，把里面的书签和子文件夹**上提到根级**，不静默丢数据。
    func removeFolder(_ id: UUID) {
        for idx in folders.indices where folders[idx].parentID == id {
            folders[idx].parentID = nil
        }
        folders.removeAll { $0.id == id }
        for idx in bookmarks.indices where bookmarks[idx].folderID == id {
            bookmarks[idx].folderID = nil
        }
        scheduleSave()
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        scheduleSave()
    }

    /// 清空全部书签和文件夹。只有设置页的「清空」按钮会调用。
    func removeAll() {
        bookmarks.removeAll()
        folders.removeAll()
        urlIndex.removeAll()
        scheduleSave()
    }

    // MARK: - 导入

    struct ImportResult {
        var bookmarkCount: Int
        var folderCount: Int
        var skippedInvalidURL: Int
    }

    /// 从 Netscape bookmark HTML 导入。Chrome / Safari / Edge / Firefox 导出的
    /// 都是这个格式，能完整保留目录树。
    ///
    /// 不用 `XMLParser`：这个格式的 HTML 是**不合法**的（`<DT>` `<p>` `<H3>` 全都
    /// 不闭合），XML 解析器会直接报错。只能自己扫。
    @discardableResult
    func importNetscapeHTML(_ text: String) -> ImportResult {
        var bookmarksOut: [Bookmark] = []
        var foldersOut: [BookmarkFolder] = []

        var folderOrder = 0
        var bookmarkOrder = 0
        var invalidCount = 0

        // 当前所处的文件夹栈。最底下是根级（nil）。
        var stack: [UUID?] = [nil]

        // `<H3>` 声明的文件夹，要等紧随其后的 `<DL>` 出现才真正生效。
        //
        // Netscape 格式的写法是「先 <H3> 声明名字，再 <DL> 装内容」，
        // 所以不能在看到 H3 时就去改栈顶——那样会让整棵树错位一级。
        var pendingFolder: UUID?

        var index = text.startIndex

        while index < text.endIndex {
            // 找下一个标签开始
            guard let openAngle = text[index...].firstIndex(of: "<") else { break }
            // 找标签名
            guard let nameEnd = text[openAngle...].firstIndex(where: { $0 == ">" || $0.isWhitespace })
            else { break }
            let tagName = String(text[text.index(after: openAngle)..<nameEnd]).uppercased()

            // 找到标签结束的 '>'
            guard let closeAngle = text[nameEnd...].firstIndex(of: ">") else { break }
            let attributes = String(text[nameEnd..<closeAngle])
            let afterTag = text.index(after: closeAngle)

            switch tagName {
            case "DL":
                // <DL> 没有成对闭合（只有 </DL> 或 </DL><p>），靠栈来配对。
                stack.append(pendingFolder)
                pendingFolder = nil

            case "/DL":
                if stack.count > 1 { stack.removeLast() }

            case "H3":
                let folderName = stripTags(String(text[afterTag...].prefix { $0 != "<" }))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let parent = stack.last ?? nil
                let folder = BookmarkFolder(
                    name: folderName.isEmpty ? "未命名文件夹" : decodeEntities(folderName),
                    parentID: parent,
                    order: folderOrder
                )
                folderOrder += 1
                foldersOut.append(folder)
                pendingFolder = folder.id

            case "A":
                let href = attribute("HREF", in: attributes)
                let rawTitle = String(text[afterTag...].prefix { $0 != "<" })
                let title = stripTags(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)

                guard let href, !href.isEmpty,
                      let url = normalizedURL(from: href) else {
                    invalidCount += 1
                    break
                }
                bookmarksOut.append(
                    Bookmark(
                        title: title.isEmpty ? (url.host() ?? "书签") : decodeEntities(title),
                        url: url,
                        folderID: stack.last ?? nil,
                        order: bookmarkOrder
                    )
                )
                bookmarkOrder += 1

            default:
                break
            }

            index = afterTag
        }

        guard !bookmarksOut.isEmpty || !foldersOut.isEmpty else {
            lastImportSummary = "没有解析出任何书签，确认选的是书签 HTML 文件"
            return ImportResult(bookmarkCount: 0, folderCount: 0, skippedInvalidURL: invalidCount)
        }

        let addedBookmarks = bookmarksOut.count
        let addedFolders = foldersOut.count

        // 合并进现有数据，根级条目排在已有内容之后。
        for folder in foldersOut {
            folders.append(folder)
        }
        for bookmark in bookmarksOut {
            bookmarks.append(bookmark)
        }
        rebuildIndex()

        var parts = ["导入 \(addedBookmarks) 条书签"]
        if addedFolders > 0 { parts.append("\(addedFolders) 个文件夹") }
        if invalidCount > 0 { parts.append("跳过 \(invalidCount) 条无效链接") }
        lastImportSummary = parts.joined(separator: "，")

        scheduleSave()
        return ImportResult(
            bookmarkCount: addedBookmarks,
            folderCount: addedFolders,
            skippedInvalidURL: invalidCount
        )
    }

    /// `javascript:`、`place:`、`data:` 这类不是真实网页地址，导进来点了也没用。
    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    /// 从标签属性串里取属性值。三种写法都要认：
    /// `HREF="x"`、`HREF='x'`、以及少数导出器用的裸值 `HREF=x`。
    private func attribute(_ name: String, in attributes: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = regex.firstMatch(in: attributes, range: nsRange) else { return nil }

        // 三个捕获组分别对应双引号、单引号、裸值，谁匹配上用谁。
        for index in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: index), in: attributes),
               !range.isEmpty {
                return decodeEntities(String(attributes[range]))
            }
        }
        return nil
    }

    /// Netscape 导出文件里 HTML 实体是转义过的，不还原会存进一堆 `&amp;`。
    private func decodeEntities(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " ")
        ]
        for (entity, plain) in replacements {
            result = result.replacingOccurrences(of: entity, with: plain)
        }
        return result
    }

    private func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    }

    // MARK: - 持久化

    private struct Payload: Codable {
        var bookmarks: [Bookmark]
        var folders: [BookmarkFolder]
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        bookmarks = payload.bookmarks
        folders = payload.folders
        rebuildIndex()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            let payload = Payload(bookmarks: self.bookmarks, folders: self.folders)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: self.storeURL, options: .atomic)
        }
    }
}

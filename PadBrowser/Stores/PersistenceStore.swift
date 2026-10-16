import Foundation

/// 落盘用的数据快照。
///
/// 起步阶段用 JSON 文件而不是 SwiftData：结构简单、迁移可控，
/// 而且这份快照就是 jetsam 恢复和「重装后一键恢复」的数据源。
/// 后期数据量上来了再换 SwiftData 不影响上层接口。
///
/// 全字段都是值类型（UUID / URL / String / Date / Bool / Double），
/// 因此隐式满足 `Sendable`，可以安全地在后台队列里传递。
struct BrowserSnapshot: Codable {
    var spaces: [BrowserSpace]
    var currentSpaceID: UUID
    var tabs: [BrowserTab]
    var folders: [TabFolder]
    var pinnedSites: [PinnedSite]
    var selectedTabID: UUID?
}

/// 单例读写器。
///
/// 并发处理方式：
/// - `@unchecked Sendable` + `NSLock` 保护内存缓存（`cached` / `didLoad`）；
/// - 真正的磁盘读写丢给一个串行 `DispatchQueue`，避免多个标签同时回写时互相覆盖；
/// - **后台闭包里只捕获值**（`snapshot` / `url`），绝不捕获 `self`。
///
/// 用 `NSLock` 而不是 `OSAllocatedUnfairLock`：后者需要额外 `import os`
/// 且带平台可用性限制，在只面向 iOS 的 target 里容易踩到 "Cannot find in scope"。
final class PersistenceStore: @unchecked Sendable {
    static let shared = PersistenceStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.padbrowser.persistence", qos: .utility)

    private let lock = NSLock()
    private var cached: BrowserSnapshot?
    private var didLoad = false

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("browser-state.json")
    }

    /// 读盘。会被主线程上的 `bootstrap()` 调用，所以先查内存缓存。
    func load() -> BrowserSnapshot? {
        lock.lock()
        let alreadyLoaded = didLoad
        let memoryCopy = cached
        lock.unlock()
        if alreadyLoaded { return memoryCopy }

        let fileURL = self.fileURL
        let decoded: BrowserSnapshot? = queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? JSONDecoder().decode(BrowserSnapshot.self, from: data)
        }

        lock.lock()
        cached = decoded
        didLoad = true
        lock.unlock()
        return decoded
    }

    /// 异步写盘。参数是值类型，调用方的后续修改不会影响这次写入。
    func save(_ snapshot: BrowserSnapshot) {
        lock.lock()
        cached = snapshot
        didLoad = true
        lock.unlock()

        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    func reset() {
        lock.lock()
        cached = nil
        didLoad = true
        lock.unlock()

        let url = fileURL
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

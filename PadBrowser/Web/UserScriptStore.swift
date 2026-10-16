import Foundation
import Observation

/// 用户脚本仓库。
///
/// 起步阶段先把存储接口和匹配逻辑打通，安装 UI 属于后续阶段。
/// 脚本来源全部是用户自己粘贴的 URL 或本地文件，**不内置任何脚本**。
@MainActor
@Observable
final class UserScriptStore {

    static let shared = UserScriptStore()

    struct Entry: Identifiable, Codable, Hashable {
        let id: UUID
        var name: String
        var source: String
        /// `@match` / `@include` 模式，等价于 uBlock 的匹配语法子集。
        var matches: [String]
        var isEnabled: Bool
        var installDate: Date
    }

    private(set) var entries: [Entry] = []

    private let storeURL: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        storeURL = base.appendingPathComponent("user-scripts.json")
        load()
    }

    func scripts(matching url: URL) -> [Entry] {
        return entries.filter { entry in
            entry.isEnabled && entry.matches.contains { Self.matches($0, url: url) }
        }
    }

    /// 支持三种写法：`*`（任意）、前缀 `https://example.com/*`、以及精确 URL。
    static func matches(_ pattern: String, url: URL) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return url.absoluteString.hasPrefix(prefix)
        }
        return pattern == url.absoluteString
    }

    func add(name: String, source: String, matches: [String]) {
        entries.append(
            Entry(id: UUID(), name: name, source: source, matches: matches,
                  isEnabled: true, installDate: .now)
        )
        save()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].isEnabled = enabled
        save()
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}

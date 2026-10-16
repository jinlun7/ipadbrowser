import Foundation
import WebKit

/// 无痕空间网站数据池。
///
/// 核心契约：每个**无痕空间**持有唯一独立的 `nonPersistent()` 实例，
/// 同一无痕空间下的多个标签页共享 Cookie、Session 与 LocalStorage；
/// 跨无痕空间或普通空间之间则严格物理隔离。
/// 当无痕空间被销毁或重置时，内存数据一并清空。
@MainActor
final class IncognitoDataStorePool {
    static let shared = IncognitoDataStorePool()

    private var pools: [UUID: WKWebsiteDataStore] = [:]

    private init() {}

    /// 获取特定空间的无痕数据存储实例
    func dataStore(for spaceID: UUID) -> WKWebsiteDataStore {
        if let existing = pools[spaceID] {
            return existing
        }
        let newStore = WKWebsiteDataStore.nonPersistent()
        pools[spaceID] = newStore
        return newStore
    }

    /// 销毁指定空间的无痕数据
    func discard(for spaceID: UUID) {
        guard let store = pools.removeValue(forKey: spaceID) else { return }
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
    }

    /// 清空所有无痕存储
    func discardAll() {
        for (_, store) in pools {
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {}
        }
        pools.removeAll()
    }
}

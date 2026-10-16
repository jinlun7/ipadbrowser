import Foundation

/// 地址栏判定用到的搜索引擎。
enum SearchEngine: String, CaseIterable, Identifiable {
    case duckduckgo
    case bing
    case google
    case brave
    case baidu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duckduckgo: "DuckDuckGo"
        case .bing:       "Bing"
        case .google:     "Google"
        case .brave:      "Brave Search"
        case .baidu:      "百度"
        }
    }

    /// 国内网络环境下 Google / Brave 基本不可达，默认放 DuckDuckGo。
    var isDefaultChoice: Bool { self == .duckduckgo }

    func url(for query: String) -> URL? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: queryItemName, value: query)
        ]
        return components?.url
    }

    private var endpoint: String {
        switch self {
        case .duckduckgo: "https://duckduckgo.com/"
        case .bing:       "https://www.bing.com/search"
        case .google:     "https://www.google.com/search"
        case .brave:      "https://search.brave.com/search"
        case .baidu:      "https://www.baidu.com/s"
        }
    }

    private var queryItemName: String {
        switch self {
        case .baidu: "wd"
        default:     "q"
        }
    }
}

/// HTTP Basic / Digest 的凭据缓存。
///
/// 只存内存，**不落盘**。真正要持久化密码时应该走 Keychain，
/// 这里保留接口是为了先把 `WKNavigationDelegate` 的认证链路打通。
@MainActor
final class CredentialStore {
    static let shared = CredentialStore()

    private var cache: [String: URLCredential] = [:]

    private init() {}

    private func key(for space: URLProtectionSpace) -> String {
        "\(space.protocol ?? "")://\(space.host):\(space.port)/\(space.realm ?? "")"
    }

    func credential(for space: URLProtectionSpace) -> URLCredential? {
        cache[key(for: space)]
    }

    func store(_ credential: URLCredential, for space: URLProtectionSpace) {
        cache[key(for: space)] = credential
    }

    func remove(for space: URLProtectionSpace) {
        cache.removeValue(forKey: key(for: space))
    }
}

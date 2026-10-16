import Foundation
import WebKit

/// 原生广告与追踪脚本拦截管理器。
///
/// 利用 WebKit 原生的 `WKContentRuleList` 在内核底层进行拦截与样式隐藏，
/// 不依赖外部第三方库，内存与 CPU 开销极低。
@MainActor
final class ContentBlockerManager {
    static let shared = ContentBlockerManager()

    private let ruleListIdentifier = "PadBrowserContentRuleList"
    private var ruleList: WKContentRuleList?
    private var isCompiling = false

    private init() {
        Task {
            await prepareRuleList()
        }
    }

    /// 预编译或加载缓存的广告拦截规则列表。
    func prepareRuleList() async {
        guard ruleList == nil, !isCompiling else { return }
        isCompiling = true
        defer { isCompiling = false }

        guard let store = WKContentRuleListStore.default() else { return }

        // 尝试从磁盘加载已编译的规则列表
        let existing: WKContentRuleList? = await withCheckedContinuation { continuation in
            store.lookUpContentRuleList(forIdentifier: ruleListIdentifier) { list, _ in
                continuation.resume(returning: list)
            }
        }
        if let existing {
            self.ruleList = existing
            return
        }

        // 首次启动：编译内置的精简广告规则与样式注入
        let json = makeRulesJSON()
        let compiled: WKContentRuleList? = await withCheckedContinuation { continuation in
            store.compileContentRuleList(forIdentifier: ruleListIdentifier, encodedContentRuleList: json) { list, _ in
                continuation.resume(returning: list)
            }
        }
        if let compiled {
            self.ruleList = compiled
        }
    }

    /// 动态挂载或卸载拦截规则到指定的 WKUserContentController
    func apply(to controller: WKUserContentController, enabled: Bool) {
        if let ruleList {
            controller.remove(ruleList)
        }
        guard enabled, let ruleList else { return }
        controller.add(ruleList)
    }

    /// 检查并保证规则已加载后挂载
    func ensureApplied(to controller: WKUserContentController, enabled: Bool) {
        if let ruleList {
            apply(to: controller, enabled: enabled)
        } else {
            Task {
                await prepareRuleList()
                apply(to: controller, enabled: enabled)
            }
        }
    }

    private func makeRulesJSON() -> String {
        """
        [
            {
                "trigger": {
                    "url-filter": ".*",
                    "resource-type": ["image", "style-sheet", "script", "font", "raw", "svg-document", "media", "popup"],
                    "if-domain": [
                        "*doubleclick.net",
                        "*google-analytics.com",
                        "*googlesyndication.com",
                        "*googletagmanager.com",
                        "*googletagservices.com",
                        "*ads.google.com",
                        "*pagead2.googlesyndication.com",
                        "*cpro.baidustatic.com",
                        "*pos.baidu.com",
                        "*tanx.com",
                        "*alimama.com",
                        "*adservice.google.com",
                        "*adnxs.com",
                        "*advertising.com",
                        "*taboola.com",
                        "*outbrain.com",
                        "*adroll.com",
                        "*scorecardresearch.com"
                    ]
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .advertisement, [id^='google_ads'], [class*='adsbygoogle'], div[class*='-ad-'], [id*='-ad-'], div[id*='cpro_'], .ad-banner, .banner-ad, [data-ad-client]"
                }
            }
        ]
        """
    }
}

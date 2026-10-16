import Foundation
import UIKit
import WebKit

/// 浏览器自己的 WKWebView 子类。
///
/// 存在的意义不是覆写什么行为，而是**把「一个标签页」这个概念锚定到一个
/// WebView 实例上**：WebView 的存活周期 = 标签的存活周期。所有状态回写
/// 都通过 tabID 回到 store，WebView 自己不持有业务状态。
final class BrowserWebView: WKWebView {

    let tabID: UUID
    let spaceID: UUID
    let isIncognito: Bool
    let scriptBridge: UserScriptBridge

    init(tabID: UUID, spaceID: UUID, isIncognito: Bool, scriptBridge: UserScriptBridge) {
        self.tabID = tabID
        self.spaceID = spaceID
        self.isIncognito = isIncognito
        self.scriptBridge = scriptBridge
        super.init(frame: .zero, configuration: Self.makeConfiguration(
            spaceID: spaceID,
            isIncognito: isIncognito,
            bridge: scriptBridge
        ))
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) 不支持") }

    // MARK: - 配置

    private static func makeConfiguration(
        spaceID: UUID,
        isIncognito: Bool,
        bridge: UserScriptBridge
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // 无痕空间使用按空间共享的 nonPersistent 容器：同一无痕空间共享 Cookie/Session，跨空间严格隔离
        config.websiteDataStore = isIncognito
            ? IncognitoDataStorePool.shared.dataStore(for: spaceID)
            : .default()

        // 桌面级体验的核心：默认请求桌面版布局，而不是被压成手机版。
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        // 画中画需要这个开关，且必须由用户手势触发，不能在加载完成时自动启。
        config.allowsPictureInPictureMediaPlayback = true

        // 不自动播放有声媒体，避免后台突然出声。
        config.mediaTypesRequiringUserActionForPlayback = .all

        config.allowsInlineMediaPlayback = true

        // 装用户脚本 + 注册桥
        let controller = bridge.userContentController()
        config.userContentController = controller

        config.preferences.isElementFullscreenEnabled = true
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        if #available(iOS 17.0, *) {
            config.preferences.inactiveSchedulingPolicy = .suspend
        }

        return config
    }

    private func commonInit() {
        navigationDelegate = nil      // 由 WebContainer.Coordinator 接管
        allowsBackForwardNavigationGestures = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        isOpaque = false
        backgroundColor = .systemBackground
        if #available(iOS 17.0, *) {
            // iPad 上默认就是可滚动内容，禁用自动放大回弹更接近桌面浏览器手感。
            scrollView.keyboardDismissMode = .interactive
        }
        allowsLinkPreview = true
        isInspectable = true

        // 桌面级 User-Agent：补全 Safari 专有标识（Version/xxx Safari/xxx），
        // 避免 B站、Google、微博等网站因缺少版本号判定为"浏览器版本过低"。
        customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"
    }

    // MARK: - 状态回写

    /// 当前滚动位置。jetsam 恢复时用。
    var scrollOffset: Double {
        let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        return y.isFinite ? max(0, y) : 0
    }

    /// 是否真的挂在窗口里。JS 弹窗（alert/confirm）只在可见时弹，
    /// 否则后台标签发起的弹窗会没人接，continuation 永远不 resume。
    var isVisible: Bool {
        window != nil && !isHidden && alpha > 0.01 && superview != nil
    }

    func restoreScroll(to offset: Double) {
        guard offset > 0 else { return }
        // 等布局稳定后再滚，否则内容还没撑开高度，setContentOffset 无效。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            self.scrollView.setContentOffset(
                CGPoint(x: 0, y: max(0, offset - self.scrollView.adjustedContentInset.top)),
                animated: false
            )
        }
    }

    /// 用当前页面状态刷新配置（无痕切换、页面导航、脚本重载后调用）。
    func applyUserScripts(for targetURL: URL? = nil) {
        let checkURL = targetURL ?? url
        let controller = configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(scriptBridge.makeBootstrapScript())
        for script in scriptBridge.userScripts(matching: checkURL) {
            controller.addUserScript(script)
        }
        controller.removeScriptMessageHandler(forName: scriptBridge.handlerName)
        controller.add(scriptBridge, name: scriptBridge.handlerName)
    }

    /// 触发原生 iCloud 密码自动填充
    func triggerPasswordAutofill() {
        PasswordAutofillHelper.shared.triggerPasswordAutofill(for: self)
    }
}

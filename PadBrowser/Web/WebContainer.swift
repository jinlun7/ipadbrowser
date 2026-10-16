import SwiftUI
import WebKit

/// 网页区宿主包装视图。
/// 关键作用：在标签进入后台时调用 `detach()` 把 `BrowserWebView` 从视图层级移除，
/// 从而触发 WebKit 的 `inactiveSchedulingPolicy = .suspend`（挂起定时器与 JS 引擎，彻底停掉后台耗电）；
/// 选中时再调用 `attach()` 放回层级，同时保留 DOM、JS 状态和滚动位置，无需重新加载。
final class WebHostView: UIView {
    private weak var currentWebView: BrowserWebView?

    func attach(_ webView: BrowserWebView) {
        if currentWebView === webView && webView.superview === self { return }
        currentWebView?.removeFromSuperview()
        currentWebView = webView
        webView.frame = bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(webView)
    }

    func detach() {
        currentWebView?.removeFromSuperview()
        currentWebView = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentWebView?.frame = bounds
    }
}

/// 把 `BrowserWebView` 桥接进 SwiftUI。
///
/// 这里承载了整个 App 最容易出错的两个地方：
/// 1. `updateUIView` **不能**在父视图每次重绘时重新加载页面；
/// 2. `dismantleUIView` 必须显式解绑 delegate 并停掉 WebView，否则标签一多就泄漏。
struct WebContainer: UIViewRepresentable {

    let tab: BrowserTab
    let store: BrowserStore
    let isSelected: Bool
    let pageZoom: Int
    let blocksAds: Bool

    /// `UIViewRepresentable` 的 `Coordinator` 关联类型默认是 `()`。
    /// 只要声明了嵌套的 `Coordinator` 类，就必须提供 `makeCoordinator()`，
    /// 否则整个类型不再符合协议。
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, tabID: tab.id)
    }

    func makeUIView(context: Context) -> WebHostView {
        let hostView = WebHostView()
        let bridge = UserScriptBridge(tabID: tab.id)
        let webView = BrowserWebView(
            tabID: tab.id,
            spaceID: tab.spaceID,
            isIncognito: tab.isIncognito,
            scriptBridge: bridge
        )
        context.coordinator.attach(to: webView)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        webView.pageZoom = CGFloat(pageZoom) / 100.0

        ContentBlockerManager.shared.ensureApplied(to: webView.configuration.userContentController, enabled: blocksAds)

        if let url = tab.url {
            context.coordinator.lastLoadedURL = url
            webView.applyUserScripts(for: url)
            webView.load(URLRequest(url: url))
        }

        if isSelected {
            hostView.attach(webView)
        }
        return hostView
    }

    func updateUIView(_ hostView: WebHostView, context: Context) {
        context.coordinator.store = store

        guard let webView = context.coordinator.webView else { return }

        ContentBlockerManager.shared.apply(to: webView.configuration.userContentController, enabled: blocksAds)

        if isSelected {
            hostView.attach(webView)
            let expectedZoom = CGFloat(pageZoom) / 100.0
            if abs(webView.pageZoom - expectedZoom) > 0.001 {
                webView.pageZoom = expectedZoom
            }
        } else {
            hostView.detach()
        }

        // 关键：只在目标 URL **真的**变了才重新加载。
        // 父视图会因为标题、进度、选中态等任何变化重绘，如果在这里无条件
        // load，用户每敲一个地址栏字符都会把整个页面刷掉。
        guard let target = tab.url, target != context.coordinator.lastLoadedURL else { return }
        context.coordinator.lastLoadedURL = target
        webView.applyUserScripts(for: target)
        webView.load(URLRequest(url: target))
    }

    static func dismantleUIView(_ hostView: WebHostView, coordinator: Coordinator) {
        // 必须显式拆，否则 WKWebView 的 content process 会一直持有引用，
        // 表现为「开了几十个标签之后内存暴涨然后被系统杀掉」。
        hostView.detach()
        if let webView = coordinator.webView {
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: webView.scriptBridge.handlerName
            )
            webView.configuration.userContentController.removeAllUserScripts()
            webView.scrollView.delegate = nil
            webView.removeFromSuperview()
        }
        coordinator.detach()
    }

    // MARK: - Coordinator

    /// `@preconcurrency`：WKNavigationDelegate / WKUIDelegate 的 completionHandler
    /// 在 SDK 头文件里被标注了 `WK_SWIFT_UI_ACTOR`，Swift 6 严格并发下会报
    /// "nearly matches optional requirement"。这些方法本来就只在主线程调用，
    /// 所以直接让编译器按旧规则检查更省事。
    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        var store: BrowserStore
        let tabID: UUID

        /// 最近一次**主动**发起的加载目标。用来判断是否需要重新 load。
        var lastLoadedURL: URL?

        var webView: BrowserWebView?
        private var progressObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var scrollObservation: NSKeyValueObservation?
        private var navigationObserver: NSObjectProtocol?

        init(store: BrowserStore, tabID: UUID) {
            self.store = store
            self.tabID = tabID
        }

        func attach(to webView: BrowserWebView) {
            self.webView = webView

            webView.scriptBridge.onMessage = { [weak self] type, payload in
                guard self != nil else { return }
                if type == "copy", let text = payload["text"] as? String {
                    UIPasteboard.general.string = text
                }
            }

            // 进度用 KVO 拿。
            //
            // 注意：**不要**在闭包里读 `view.estimatedProgress` 这类 MainActor 隔离属性，
            // 那是 Sendable 闭包，会报并发警告。改从 `change.newValue` 取值——
            // 那是值类型，不触碰任何隔离状态。
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                guard let value = change.newValue, let self else { return }
                Task { @MainActor in self.store.updateProgress(value, for: self.tabID) }
            }

            loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
                guard let loading = change.newValue, let self else { return }
                Task { @MainActor in self.store.setLoading(loading, for: self.tabID) }
            }

            // 用 `observe(_:)` 而不是 `addObserver(_:forKeyPath:options:using:)`。
            // 后者是给 C 风格 context 指针用的重载，传闭包会编译失败。
            scrollObservation = webView.scrollView
                .observe(\.contentOffset, options: [.new]) { [weak self] _, change in
                    guard let offset = change.newValue?.y, let self else { return }
                    Task { @MainActor in self.store.recordScroll(offset, for: self.tabID) }
                }

            // 订阅导航信号。只有属于**本标签**的信号才响应。
            navigationObserver = NotificationCenter.default.addObserver(
                forName: .pbPerformNavigation,
                object: nil,
                queue: .main
            ) { [weak self] note in
                // 关键：`Notification` 不是 Sendable，**不能**把它带进
                // MainActor.assumeIsolated 的隔离区域，否则 Swift 6 会报
                // "sending 'note' risks causing data races"。
                //
                // 正确做法是在闭包里就地把它拆成 Sendable 的值类型
                // （UUID / String / 无负载枚举都是 Sendable），拆完再进隔离区。
                guard let rawID = note.userInfo?["tabID"] as? UUID,
                      let rawAction = note.userInfo?["action"] as? String
                else { return }
                let signalTabID = rawID
                guard let signalAction = BrowserStore.NavigationAction(rawValue: rawAction)
                else { return }

                // queue: .main 保证在主线程投递，但闭包本身是 Sendable 的，
                // 所以要显式声明隔离，否则读 MainActor 属性会报并发警告。
                MainActor.assumeIsolated {
                    guard let self,
                          let web = self.webView,
                          signalTabID == self.tabID
                    else { return }
                    switch signalAction {
                    case .back:    if web.canGoBack { web.goBack() }
                    case .forward: if web.canGoForward { web.goForward() }
                    case .reload:  web.reload()
                    case .stop:    web.stopLoading()
                    }
                }
            }
        }

        /// 清理所有观察者。由 `dismantleUIView` 调用。
        ///
        /// 刻意**不放在 `deinit`**：`deinit` 是 nonisolated 的，
        /// 在 `@MainActor` 类里访问隔离属性会报并发错误。
        /// 而且 dismantleUIView 才是真正保证会被调用的拆解点。
        func detach() {
            progressObservation?.invalidate()
            loadingObservation?.invalidate()
            scrollObservation?.invalidate()
            progressObservation = nil
            loadingObservation = nil
            scrollObservation = nil
            if let navigationObserver {
                NotificationCenter.default.removeObserver(navigationObserver)
                self.navigationObserver = nil
            }
            webView = nil
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // 处理微信/支付宝/电话/邮件/App Store 等非网页协议，唤起对应原生应用
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme != "http" && scheme != "https" && scheme != "about" && scheme != "data" && scheme != "blob" && scheme != "file" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }

            // target="_blank" 在 WKWebView 里默认什么都不会发生，必须手动接管。
            if navigationAction.targetFrame == nil {
                lastLoadedURL = url
                (webView as? BrowserWebView)?.applyUserScripts(for: url)
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            (webView as? BrowserWebView)?.applyUserScripts(for: url)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            store.clearLoadError(for: tabID)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            lastLoadedURL = url
            store.updateURL(url, for: tabID)
            (webView as? BrowserWebView)?.applyUserScripts(for: url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            store.resetTerminationCount(for: tabID)
            store.updateTitle(webView.title ?? "", for: tabID)
            store.updateNavigationState(
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                for: tabID
            )
            // 这里拿到的静态类型是 WKWebView，要用子类专有方法必须先转型。
            guard let browser = webView as? BrowserWebView else { return }
            store.recordScroll(browser.scrollOffset, for: tabID)
            browser.restoreScroll(to: store.restoreOffset(for: tabID))

            // 执行匹配当前 URL 的用户脚本
            if let currentURL = webView.url {
                for script in UserScriptStore.shared.scripts(matching: currentURL) {
                    browser.evaluateJavaScript(script.source, completionHandler: nil)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            store.reportLoadFailure(error, for: tabID)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            store.reportLoadFailure(error, for: tabID)
        }

        /// iOS 内存紧张时内核进程被杀。首次尝试自动恢复，若持续崩溃则停止自动重载避免无限死循环。
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard let url = webView.url ?? lastLoadedURL else { return }
            let shouldAutoReload = store.handleContentProcessTermination(for: tabID)
            if shouldAutoReload {
                webView.load(URLRequest(url: url))
            }
        }

        /// TLS 信任挑战。
        ///
        /// 默认走系统默认处理，**不静默信任自签名证书**。要给某些站点开例外，
        /// 应该做成显式的「为此站点记住」开关，而不是全局放开。
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                completionHandler(.performDefaultHandling, nil)
            case NSURLAuthenticationMethodHTTPBasic,
                 NSURLAuthenticationMethodHTTPDigest,
                 NSURLAuthenticationMethodNTLM:
                // 凭据交给 store 的 CredentialStore 查，查不到再弹原生输入框。
                if let credential = store.credential(for: challenge.protectionSpace) {
                    completionHandler(.useCredential, credential)
                } else {
                    promptForHTTPCredentials(for: challenge, in: webView, completionHandler: completionHandler)
                }
            default:
                completionHandler(.performDefaultHandling, nil)
            }
        }

        private func promptForHTTPCredentials(
            for challenge: URLAuthenticationChallenge,
            in webView: WKWebView,
            completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard let topVC = topViewController() else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            let host = challenge.protectionSpace.host
            let realm = challenge.protectionSpace.realm.map { " (\($0))" } ?? ""
            let alert = UIAlertController(
                title: "需要认证",
                message: "站点 \(host)\(realm) 需要用户名和密码进行登录。",
                preferredStyle: .alert
            )

            alert.addTextField { tf in
                tf.placeholder = "用户名"
                tf.textContentType = .username
                tf.autocapitalizationType = .none
                tf.autocorrectionType = .no
            }
            alert.addTextField { tf in
                tf.placeholder = "密码"
                tf.textContentType = .password
                tf.isSecureTextEntry = true
            }

            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                completionHandler(.cancelAuthenticationChallenge, nil)
            })

            alert.addAction(UIAlertAction(title: "登录", style: .default) { [weak self] _ in
                let user = alert.textFields?[0].text ?? ""
                let pass = alert.textFields?[1].text ?? ""
                let cred = URLCredential(user: user, password: pass, persistence: .forSession)
                self?.store.storeCredential(cred, for: challenge.protectionSpace)
                completionHandler(.useCredential, cred)
            })

            topVC.present(alert, animated: true)
        }

        // MARK: WKUIDelegate

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme != "http" && scheme != "https" && scheme != "about" && scheme != "data" && scheme != "blob" && scheme != "file" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                return nil
            }
            // 一律在当前标签里打开，不开新窗口。
            lastLoadedURL = url
            webView.load(URLRequest(url: url))
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async {
            guard isVisible(webView) else { return }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default) { _ in cont.resume() })
                topViewController()?.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async -> Bool {
            guard isVisible(webView) else { return false }
            return await withCheckedContinuation { cont in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in cont.resume(returning: false) })
                alert.addAction(UIAlertAction(title: "好", style: .default) { _ in cont.resume(returning: true) })
                topViewController()?.present(alert, animated: true)
            }
        }

        /// delegate 回调给的是静态类型 `WKWebView`，
        /// 所以这里统一做一次子类转型再判断可见性。
        private func isVisible(_ webView: WKWebView) -> Bool {
            (webView as? BrowserWebView)?.isVisible ?? true
        }

        private func topViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController
        }
    }
}

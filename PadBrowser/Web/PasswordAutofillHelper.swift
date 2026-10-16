import AuthenticationServices
import UIKit
import WebKit

/// iPadOS 原生密码填充辅助器。
///
/// 1. 唤起系统 iCloud 钥匙串密码认证界面（支持 FaceID / TouchID / 密码）；
/// 2. 用户授权后将选择的凭据自动安全填充到当前页面的输入框中。
@MainActor
final class PasswordAutofillHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = PasswordAutofillHelper()

    private weak var targetWebView: BrowserWebView?

    private override init() {
        super.init()
    }

    /// 触发系统密码选择器
    func triggerPasswordAutofill(for webView: BrowserWebView) {
        self.targetWebView = webView

        let passwordProvider = ASAuthorizationPasswordProvider()
        let request = passwordProvider.createRequest()

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    /// 在当前活动窗口中寻找正在显示的 BrowserWebView 并唤起密码填充
    func triggerPasswordAutofillForActiveTab() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }),
            let webView = findWebView(in: window) else { return }
        triggerPasswordAutofill(for: webView)
    }

    private func findWebView(in view: UIView) -> BrowserWebView? {
        if let bw = view as? BrowserWebView, bw.window != nil && bw.superview != nil {
            return bw
        }
        for sub in view.subviews {
            if let found = findWebView(in: sub) {
                return found
            }
        }
        return nil
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASPasswordCredential else { return }
        let username = credential.user
        let password = credential.password

        injectCredentials(username: username, password: password)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // 用户取消或未授权，静默处理不打扰用户
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        targetWebView?.window
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }

    // MARK: - 页面表单注入

    private func injectCredentials(username: String, password: String) {
        guard let webView = targetWebView else { return }

        // 安全地将用户名和密码转义并填充到 DOM
        let userJSON = (try? String(data: JSONEncoder().encode(username), encoding: .utf8)) ?? "\"\""
        let passJSON = (try? String(data: JSONEncoder().encode(password), encoding: .utf8)) ?? "\"\""

        let js = """
        (function() {
            var u = \(userJSON);
            var p = \(passJSON);

            var pwdInputs = document.querySelectorAll('input[type="password"]');
            var pwdInput = pwdInputs.length > 0 ? pwdInputs[0] : null;

            if (pwdInput) {
                pwdInput.value = p;
                pwdInput.dispatchEvent(new Event('input', { bubbles: true }));
                pwdInput.dispatchEvent(new Event('change', { bubbles: true }));

                var form = pwdInput.form || document;
                var userInputs = form.querySelectorAll('input[type="text"], input[type="email"], input[autocomplete="username"], input[name*="user"], input[name*="login"], input[id*="user"], input[id*="login"]');
                if (userInputs.length > 0) {
                    var userInput = userInputs[0];
                    userInput.value = u;
                    userInput.dispatchEvent(new Event('input', { bubbles: true }));
                    userInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
        })();
        """

        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

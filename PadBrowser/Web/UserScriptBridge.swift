import Foundation
import WebKit

/// 页面 JS 与原生之间的单向消息通道。
///
/// 每次新建一个实例（每个标签一份），因此**不需要**额外管理 handler 的引用计数——
/// WebView 被释放时 handler 一起走。但 `WKUserContentController` 对同名 handler
/// 强引用，重名注册会直接抛异常，所以 name 必须带上 tabID。
@MainActor
final class UserScriptBridge: NSObject, WKScriptMessageHandler {

    /// 页面上哪些脚本在运行、分别来自哪里，存这个给 UI 显示指示条用。
    private(set) var activeScriptNames: [String] = []

    /// 页面 → 原生 的回调，在主线程上触发。
    var onMessage: ((String, [String: Any]) -> Void)?

    private let tabID: UUID

    init(tabID: UUID) {
        self.tabID = tabID
    }

    var handlerName: String { "pb.bridge.\(tabID.uuidString)" }

    /// 需要在配置阶段注入的桥脚本。页面里用 `window.__pb.post(...)` 调用。
    func makeBootstrapScript() -> WKUserScript {
        let source = """
        (function () {
          if (window.__pb) { return; }
          var name = \(handlerName.debugDescription);
          window.__pb = {
            post: function (type, payload) {
              try {
                window.webkit.messageHandlers[name].postMessage(
                  Object.assign({ type: type }, payload || {})
                );
              } catch (e) { /* 页面正在卸载，忽略 */ }
            }
          };

          // 修复 iPad 模拟桌面 UA 时，B站等网站在悬停/弹窗时因误判滚动条宽度、动态注入 padding-right 导致的页面抖动与右边距突变
          try {
            var fixStyle = document.createElement('style');
            fixStyle.id = 'pb-scrollbar-jitter-fix';
            fixStyle.textContent = [
              'html, body { overflow-x: clip !important; max-width: 100% !important; }',
              'body[style*="padding-right"] { padding-right: 0px !important; }',
              '.bili-header[style*="padding-right"] { padding-right: 0px !important; }',
              '.bili-header__bar[style*="padding-right"] { padding-right: 0px !important; }',
              'header[style*="padding-right"] { padding-right: 0px !important; }'
            ].join('\\n');

            var target = document.head || document.documentElement;
            if (target) {
              target.appendChild(fixStyle);
            } else {
              document.addEventListener('DOMContentLoaded', function () {
                (document.head || document.documentElement).appendChild(fixStyle);
              });
            }

            if (typeof MutationObserver !== 'undefined') {
              var observer = new MutationObserver(function () {
                if (document.body && document.body.style.paddingRight && document.body.style.paddingRight !== '0px') {
                  document.body.style.paddingRight = '0px';
                }
              });
              if (document.body) {
                observer.observe(document.body, { attributes: true, attributeFilter: ['style'] });
              } else {
                document.addEventListener('DOMContentLoaded', function () {
                  if (document.body) {
                    observer.observe(document.body, { attributes: true, attributeFilter: ['style'] });
                  }
                });
              }
            }
          } catch (err) {}
        })();
        """
        // .atDocumentStart 保证后续注入的用户脚本能立刻拿到 window.__pb
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    func userContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        controller.addUserScript(makeBootstrapScript())
        controller.add(self, name: handlerName)
        return controller
    }

    func userScripts(matching url: URL?) -> [WKUserScript] {
        guard let url else { return [] }
        return UserScriptStore.shared.scripts(matching: url).map { entry in
            WKUserScript(source: entry.source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        }
    }

    func markActiveScripts(_ names: [String]) {
        activeScriptNames = names
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else { return }
        onMessage?(type, body)
    }
}

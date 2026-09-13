# iOS — WKWebView bridge binding

Core lives in SKILL.md. This is the iOS API binding only. Language: Swift.

## Choose the mechanism

| Mechanism | Use when | Reply |
|---|---|---|
| `WKScriptMessageHandlerWithReply` (iOS 14+) | **preferred** — native returns a value/Promise straight to JS | async reply handler |
| `WKScriptMessageHandler` (classic) | min-SDK < 14, or fire-and-forget events | you push the response yourself via `evaluateJavaScript` |

## Threading (iOS-specific)

- `userContentController(_:didReceive:)` is delivered on the **main thread**.
  Still route through the shared dispatcher; offload blocking work so the main
  thread is not held.
- `webView.evaluateJavaScript(...)` MUST be called on the main thread.

## Retain-cycle gotcha (never relax)

`WKUserContentController.add(_:name:)` retains the handler **strongly**. If the
handler also holds the web view (or its owner), you get a cycle that leaks the
whole WebView. Break it with a weak proxy:

```swift
final class WeakBridgeProxy: NSObject, WKScriptMessageHandlerWithReply {
    weak var target: NativeBridge?
    func userContentController(_ c: WKUserContentController,
                               didReceive m: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        target?.handle(m, reply: replyHandler)
    }
}
```

Register/unregister on the view lifecycle, and always `removeScriptMessageHandler`
before re-adding or on teardown:

```swift
let controller = webView.configuration.userContentController
controller.removeScriptMessageHandler(forName: "bridge")   // idempotent guard
controller.addScriptMessageHandler(WeakBridgeProxy(target: bridge),
                                    contentWorld: .page, name: "bridge")
```

Use `WKContentWorld.defaultClient` (or a dedicated world) to isolate your
injected client script from page scripts when the page is not fully trusted.

## Security & navigation (iOS additions to core §4)

- Enforce the host allowlist in
  `webView(_:decidePolicyFor:decisionHandler:)`; `.cancel` off-allowlist.
- `configuration.limitsNavigationsToAppBoundDomains = true` when using app-bound
  domains; keep `allowsInlineMediaPlayback`/data-detection minimal.
- `webView.isInspectable = true` only in DEBUG (iOS 16.4+).

## Generator skeleton (WithReply path)

```swift
final class NativeBridge {
    weak var webView: WKWebView?
    let allowedOrigin: String

    func handle(_ message: WKScriptMessage, reply: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.securityOrigin.host == allowedOrigin else {
            return reply(nil, "origin not allowed")            // JS Promise rejects
        }
        guard let env = EnvelopeParser.parse(message.body) else {
            return reply(nil, "INVALID_PAYLOAD")
        }
        dispatch(env) { responsePayload in reply(responsePayload, nil) }
    }

    func sendEvent(_ env: Envelope) {                          // native→JS push
        let js = "window.__bridge.receive(\(env.jsonString))"
        DispatchQueue.main.async { [weak self] in
            guard let wv = self?.webView else { return }        // destroyed-view guard
            wv.evaluateJavaScript(js)
        }
    }
}

// recovery:
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    webView.reload(); reHandshakeAfterLoad()
}
```

## iOS guard checklist (additions only)

- [Critical] Handler added without a weak proxy → WebView leak (retain cycle).
- [Critical] Origin not checked via `message.frameInfo.securityOrigin`.
- [High] `evaluateJavaScript` off the main thread.
- [High] `isInspectable` / debugging enabled in release.
- [Medium] `webViewWebContentProcessDidTerminate` not handled (blank view after
  a jetsam kill).
- [Low] Injected client shares the page content world when the page is untrusted.

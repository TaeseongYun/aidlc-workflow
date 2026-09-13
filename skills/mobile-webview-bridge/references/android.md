# Android — WebView bridge binding

Core (envelope, handshake, security, threading, lifecycle) lives in SKILL.md.
This file is the Android API binding only. Language: Kotlin.

## Choose the mechanism

| Mechanism | Use when | Origin scoping |
|---|---|---|
| `WebViewCompat.addWebMessageListener` (AndroidX) | **preferred** — modern, origin-scoped at the API level | pass an allowed-origins set to the API |
| `@JavascriptInterface` (classic) | legacy min-SDK, or you need a synchronous return value into JS | none built in — you MUST check origin yourself in every method |

Prefer `addWebMessageListener`: it is origin-scoped by construction and delivers
via `WebMessage`, avoiding the reflection surface of `@JavascriptInterface`.

## Threading (Android-specific)

- `@JavascriptInterface` methods arrive on a **private WebView "JavaBridge"
  background thread, never the main thread**. Do not touch UI or call
  `evaluateJavascript` directly from there — hand the message to the shared
  dispatcher.
- `WebViewCompat` `onPostMessage` arrives on the app's main thread by default
  (or the handler you pass) — still route through the one dispatcher for parity.
- `webView.evaluateJavascript(...)` MUST be called on the main thread.

## Security hardening (Android additions to the core §4)

```kotlin
webView.settings.apply {
    javaScriptEnabled = true          // only where the contract needs it
    allowFileAccess = false
    allowContentAccess = false
    allowFileAccessFromFileURLs = false
    allowUniversalAccessFromFileURLs = false
    mediaPlaybackRequiresUserGesture = true
}
WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)  // never in release
```

Serve local assets through `WebViewAssetLoader` (https-scheme virtual host)
instead of `file://`. Enforce the host allowlist in
`WebViewClient.shouldOverrideUrlLoading` and refuse navigation off-allowlist.

## Generator skeleton (@JavascriptInterface path)

```kotlin
class NativeBridge(
    private val webView: WebView,
    private val allowedOrigin: String,
    private val dispatch: (Envelope) -> Unit,   // shared, thread-normalizing
) {
    @JavascriptInterface                        // called on a BACKGROUND thread
    fun postMessage(raw: String) {
        val env = EnvelopeParser.parseOrNull(raw) ?: return replyError(null, "INVALID_PAYLOAD")
        dispatch(env)                            // dispatcher hops to main as needed
    }

    fun sendToJs(env: Envelope) {                // native→JS
        val json = env.toJsonString()
        webView.post {                           // main thread
            if (webView.isAttachedToWindow) {
                webView.evaluateJavascript("window.__bridge.receive($json)", null)
            }
        }
    }
    private fun replyError(id: String?, code: String) { /* build response envelope, sendToJs */ }
}

// registration is lifecycle-scoped:
override fun onCreateView(...) { webView.addJavascriptInterface(bridge, "AndroidBridge") }
override fun onDestroyView() { webView.removeJavascriptInterface("AndroidBridge"); super.onDestroyView() }
```

Recovery:

```kotlin
webView.webViewClient = object : WebViewClientCompat() {
    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
        rebuildWebViewAndReHandshake(); return true   // true = handled, do not crash
    }
}
```

## Android guard checklist (additions only)

- [Critical] `@JavascriptInterface` method runs without an origin check (classic
  mechanism has none built in).
- [Critical] `allowUniversalAccessFromFileURLs`/`allowFileAccessFromFileURLs`
  true, or `file://` served instead of `WebViewAssetLoader`.
- [High] UI touched or `evaluateJavascript` called from the `@JavascriptInterface`
  background thread.
- [High] Interface not removed in `onDestroyView` (leaks the WebView / handler).
- [Medium] `onRenderProcessGone` not handled (returns false → app crash).

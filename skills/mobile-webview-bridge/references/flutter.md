# Flutter — webview_flutter bridge binding

Core lives in SKILL.md. This is the `webview_flutter` binding only. Language:
Dart.

## Mechanism

- JS→native: `controller.addJavaScriptChannel(name, onMessageReceived: ...)`
  exposes `<name>.postMessage(string)` to JS. **Each channel carries a single
  string** — the JSON envelope multiplexes every method over ONE channel; do
  not create a channel per method.
- native→JS: `controller.runJavaScript(...)` (fire-and-forget) or
  `runJavaScriptReturningResult(...)` (value back). Push events with
  `runJavaScript("window.__bridge.receive(<json>)")`.
- Origin control: `NavigationDelegate(onNavigationRequest:)` →
  `NavigationDecision.prevent` off-allowlist.

## When to switch to flutter_inappwebview

`webview_flutter` has one string per channel and limited hooks. If the contract
needs typed replies per call, many handlers, or finer navigation/permission
control, `flutter_inappwebview`'s `addJavaScriptHandler` (returns a value
straight to the JS Promise) is the better fit. Note it in the plan; the
envelope and core rules are identical either way.

## Threading

`onMessageReceived` is delivered on the platform thread and surfaces on the Dart
main isolate — no background-thread hazard, but route through the one dispatcher
for parity and central validation.

## Generator skeleton

```dart
const origin = 'https://app.example.com';

final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setNavigationDelegate(NavigationDelegate(
    onNavigationRequest: (r) => r.url.startsWith(origin)
        ? NavigationDecision.navigate : NavigationDecision.prevent,
  ))
  ..addJavaScriptChannel('NativeBridge', onMessageReceived: (msg) {
    final env = parseEnvelope(msg.message);       // single string -> envelope
    if (env == null) return;                      // drop / typed error
    dispatch(env, (response) => _sendToJs(controller, response));
  });

void _sendToJs(WebViewController c, Map<String, dynamic> env) {
  final json = jsonEncode(env);
  c.runJavaScript('window.__bridge.receive($json)');   // main isolate
}

// JS client (install via an onPageStarted eval or bundled in the page):
// window.__bridge.call(method, payload) -> NativeBridge.postMessage(JSON.stringify(envelope))
// queue calls until the bridge.init response arrives (handshake race, core §3)
```

Lifecycle: hold the controller in the `State`, and null-check / cancel pending
completers in `dispose()` before the view is torn down so an async reply never
runs `runJavaScript` on a disposed controller.

## Flutter guard checklist (additions only)

- [Critical] `NavigationDelegate` origin check missing (any URL can drive the
  channel).
- [Critical] `onMessageReceived` dispatches without parsing/validating the
  envelope.
- [High] One channel per method instead of one multiplexed channel, or no
  handshake queue on the JS side.
- [High] Pending completers not cancelled in `dispose()` → `runJavaScript` on a
  disposed controller.
- [Medium] `JavaScriptMode.unrestricted` on a screen that does not need the
  bridge.

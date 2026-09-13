# React Native — react-native-webview bridge binding

Core lives in SKILL.md. This is the `react-native-webview` binding only.
Language: TypeScript.

## Mechanism

- JS→native: `window.ReactNativeWebView.postMessage(string)` → the `onMessage`
  prop on `<WebView>`. **Payload is string-only** — the JSON envelope is
  mandatory; `JSON.stringify` on the way out, parse + validate on the way in.
- native→JS: `webViewRef.injectJavaScript("window.__bridge.receive(<json>); true;")`
  (the trailing `true;` avoids a warning on some platforms).
- Install the JS client via `injectedJavaScriptBeforeContentLoaded` so it exists
  at documentStart — this is exactly where the handshake-race queue (core §3) is
  required, because the page can post before RN has wired `onMessage`.

## Threading

`onMessage` fires on the JS thread; there is no background-thread hazard like
Android's, but still route through the one dispatcher so behavior matches the
other platforms and validation is centralized.

## Security (RN additions to core §4)

- `originWhitelist={['https://app.example.com']}` — never leave the default
  `['*']`.
- `onShouldStartLoadWithRequest` → return `false` for off-allowlist navigation.
- `setSupportMultipleWindows={false}`, `javaScriptCanOpenWindowsAutomatically={false}`.
- `injectedJavaScriptBeforeContentLoaded` runs with page privileges — keep it to
  the bridge client, never inject secrets.

## Generator skeleton

```tsx
const ORIGIN = 'https://app.example.com';

const client = `
  (function () {
    const pending = new Map(); let queue = []; let ready = false;
    window.__bridge = {
      call(method, payload) {
        return new Promise((resolve, reject) => {
          const id = crypto.randomUUID();
          pending.set(id, { resolve, reject });
          const msg = JSON.stringify({ id, type: 'request', method, payload, error: null });
          ready ? window.ReactNativeWebView.postMessage(msg) : queue.push(msg);   // handshake queue
          setTimeout(() => { if (pending.delete(id)) reject({ code: 'TIMEOUT' }); }, 10000);
        });
      },
      receive(env) {
        if (env.method === 'bridge.init' && env.type === 'response') {
          ready = true; queue.forEach(m => window.ReactNativeWebView.postMessage(m)); queue = [];
        }
        if (env.type === 'response' && pending.has(env.id)) {
          const p = pending.get(env.id); pending.delete(env.id);
          env.error ? p.reject(env.error) : p.resolve(env.payload);
        }
      },
    };
    window.__bridge.call('bridge.init', {});   // handshake first
  })(); true;
`;

function Bridge() {
  const ref = useRef<WebView>(null);
  const onMessage = (e: WebViewMessageEvent) => {
    const env = parseEnvelope(e.nativeEvent.data);          // parse + validate
    if (!env) return;                                       // drop / typed error
    dispatch(env, (response) =>
      ref.current?.injectJavaScript(`window.__bridge.receive(${JSON.stringify(response)}); true;`));
  };
  return (
    <WebView ref={ref} source={{ uri: ORIGIN }}
      originWhitelist={[ORIGIN]}
      injectedJavaScriptBeforeContentLoaded={client}
      onShouldStartLoadWithRequest={(r) => r.url.startsWith(ORIGIN)}
      onMessage={onMessage} />
  );
}
```

## RN guard checklist (additions only)

- [Critical] `originWhitelist` left as `['*']`, or `onShouldStartLoadWithRequest`
  missing.
- [Critical] `onMessage` handler dispatches without parsing/validating the
  string into the envelope.
- [High] JS client installed via `injectedJavaScript` (after load) instead of
  `...BeforeContentLoaded`, or no handshake queue.
- [Medium] Non-string passed to `postMessage` (silently coerced/lost).
- [Low] `injectJavaScript` payload not `JSON.stringify`-escaped (breaks on
  quotes/newlines).

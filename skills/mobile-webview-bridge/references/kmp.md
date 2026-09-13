# KMP — Kotlin Multiplatform bridge binding

Core lives in SKILL.md. KMP does not host a WebView itself — it owns the
**shared contract, envelope, and validation**, and delegates the WebView API to
Android and iOS via `expect/actual`. Read this together with `android.md` and
`ios.md`: those describe the two `actual` bindings. The whole point is that the
contract and its validation exist ONCE.

## What lives where

| Layer | Contents |
|---|---|
| `commonMain` | contract types, `Envelope` model + kotlinx.serialization, schema validation, the dispatcher, error mapping |
| `androidMain` (`actual`) | binds to the `android.md` mechanism (`addWebMessageListener` / `@JavascriptInterface`), background-thread normalization |
| `iosMain` (`actual`) | binds to the `ios.md` mechanism (`WKScriptMessageHandlerWithReply` + weak proxy), main-thread delivery |

## commonMain — the shared contract & envelope

```kotlin
@Serializable
data class Envelope(
    val id: String? = null,
    val type: Type,                       // REQUEST, RESPONSE, EVENT
    val method: String,
    val payload: JsonObject = JsonObject(emptyMap()),
    val error: BridgeError? = null,
) { enum class Type { REQUEST, RESPONSE, EVENT } }

@Serializable data class BridgeError(val code: String, val message: String)

object BridgeCodec {
    private val json = Json { ignoreUnknownKeys = false; explicitNulls = false }
    fun decode(raw: String): Envelope? = runCatching { json.decodeFromString<Envelope>(raw) }.getOrNull()
    fun encode(env: Envelope): String = json.encodeToString(env)
}

// One validation path for BOTH platforms — the reason KMP is one skill, not two.
fun validate(env: Envelope, capabilities: Set<String>): BridgeError? = when {
    env.type == Envelope.Type.REQUEST && env.method !in capabilities ->
        BridgeError("UNKNOWN_METHOD", env.method)
    env.type == Envelope.Type.REQUEST && env.error != null ->
        BridgeError("INVALID_PAYLOAD", "request carries error")
    else -> null
}
```

## expect/actual seam

```kotlin
// commonMain
expect class WebViewBridgeHost {
    fun register(onMessage: (String) -> Unit)   // raw JSON in, from the platform
    fun evaluate(js: String)                     // native→JS, platform hops to main
    fun unregister()
}
```

The `actual` for `androidMain` wraps the `android.md` skeleton (remember: its
inbound thread is the background JavaBridge thread — normalize before calling
the common dispatcher). The `actual` for `iosMain` wraps the `ios.md` skeleton
(weak proxy, main-thread delivery). Both feed the SAME `commonMain` dispatcher,
so `validate()` and error mapping are never duplicated.

## Threading note

Normalize at the seam: each `actual.register` callback must deliver onto the
one common dispatcher (e.g. a `CoroutineDispatcher` in `commonMain`), so the
background-thread arrival on Android and the main-thread arrival on iOS look
identical to shared code. `evaluate` is expected to marshal to the main thread
inside each `actual`.

## KMP guard checklist (additions only)

- [Critical] Envelope validation duplicated in `androidMain`/`iosMain` instead
  of `commonMain` (defeats the single-contract guarantee; the two WILL drift).
- [High] `actual` android binding calls the common dispatcher directly from the
  `@JavascriptInterface` background thread without normalizing.
- [High] `ignoreUnknownKeys = true` in the shared `Json` (unknown field should
  surface as `INVALID_PAYLOAD`, not be silently dropped).
- [Medium] Platform-specific error codes invented in an `actual` instead of the
  shared reserved set.

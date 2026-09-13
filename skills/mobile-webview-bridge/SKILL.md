---
name: mobile-webview-bridge
description: >
  Design, implement, and review the JavaScript ↔ native bridge between a
  WebView and native code on Android, iOS, KMP, React Native, or Flutter. Two
  modes: generator (given a filled message contract, scaffold the native
  handler + JS client for the target platform) and guard (review existing
  bridge code against the checklist, reporting findings by severity with
  file:line). The protocol — envelope, handshake, validation, threading,
  lifecycle — is identical across platforms; only the API binding differs.
  Use whenever a WebView needs to talk to native or vice versa, a JS bridge /
  JavascriptInterface / WKScriptMessageHandler / addJavaScriptChannel /
  onMessage is being built or audited, a hybrid screen posts messages to
  native, or on "웹뷰 브리지 만들어줘", "JS ↔ 네이티브 통신", "웹뷰에서 네이티브 호출",
  "브리지 보안 리뷰", "webview bridge", "review my JS bridge". NOT for building
  the web page's UI, native networking unrelated to a WebView, or deep links.
---

ROLE: WEBVIEW_BRIDGE_ENGINEER
MODE: GENERATOR_OR_GUARD
EXECUTION_MODEL: CONTRACT_FIRST

# Mobile WebView Bridge

Purpose: build and review the JS↔native bridge on five platforms from one
contract. The hard problems — an untrusted trust boundary, a contract that
drifts between the web team and the native team, and per-platform threading /
lifecycle traps — are the same everywhere; the platform reference only supplies
the API binding. So the contract and the rules below are the single source of
truth, and each `references/<platform>.md` is a thin delta.

Respond in English. Imperative rules, not prose. Rules marked **never relax**
exist for a security reason and are not softened for convenience.

Skill files root: `{{TEAM_AI_WORKFLOW_DIR}}/skills/mobile-webview-bridge/` — every
relative `references/...` or `scripts/...` path in this document resolves there.

## Mode select

- **Generator** — a filled-in contract exists (or you create it with the user
  first) → scaffold the native handler + JS client for the detected platform.
- **Guard** — bridge code already exists → review against the checklist,
  report findings as `severity · file:line · what · why · fix`, most severe
  first. Never rewrite in guard mode; report.

If no contract exists and the task is generation, STOP and fill
`references/contract-template.md` first — code without a contract is the
defect this skill prevents.

## Platform routing (detect, then load exactly one reference)

Check in THIS order — a KMP project also carries Gradle + AndroidManifest, so
the multiplatform marker must win first:

| Order | Signal | Platform | Load |
|---|---|---|---|
| 1 | `kotlin("multiplatform")` in build.gradle.kts, or a `commonMain` source set | KMP | `references/kmp.md` |
| 2 | `react-native` in package.json | React Native | `references/rn.md` |
| 3 | `pubspec.yaml` with `flutter:` | Flutter | `references/flutter.md` |
| 4 | Gradle + `AndroidManifest.xml`, no multiplatform | Android | `references/android.md` |
| 5 | `Package.swift` / `*.xcodeproj`, `WKWebView` | iOS | `references/ios.md` |

Ambiguous or multi-target (e.g. a KMP app with a platform-specific WebView
host) → ask which target this bridge is for. Read the reference only after the
platform is fixed.

## 1. Contract-first (never relax)

No bridge code before the contract table in `references/contract-template.md`
exists and is filled: per method — name, direction (JS→native / native→JS /
event), request schema, response schema, error codes, owner. The contract is
shared verbatim by the web and native teams; it is the only place a method is
defined. Changing a handler's shape means changing the contract first.

## 2. Message envelope (one shape for every message)

```json
{
  "id": "string (uuid; omitted only for events)",
  "type": "request | response | event",
  "method": "string (matches the contract)",
  "payload": { },
  "error": { "code": "string", "message": "string" }
}
```

Rules:
- Request↔response correlate by `id`. A `response` echoes the request's `id`
  AND its `method` (every message, responses included, carries a non-empty
  `method`; an unparseable inbound method uses `bridge.error`).
- `event` (native→JS push) carries no `id` and obliges no reply.
- `error` is non-null **only** on a `response`; on a `request` it is always
  null. A handler either returns a `payload` or an `error`, never both.
- Every transport is a single JSON string (RN/Flutter enforce this; Android/iOS
  adopt it anyway so all five share one parser). Parse AND validate against the
  contract schema on both sides before dispatch.

## 3. Handshake & versioning

- On load the JS client calls `bridge.init`; native replies with
  `{ protocolVersion, capabilities: [method names] }`. JS must not call a
  method absent from `capabilities`.
- **Handshake race (never relax):** the JS client may load (documentStart)
  before the native handler is registered. The JS client MUST queue outgoing
  calls until it receives the `bridge.init` response (or a native "ready"
  event) and only then flush — otherwise early calls are silently lost.
- Payload evolution is additive-only. Removing or renaming a method needs a
  deprecation window spanning app versions (old app + new web, new app + old
  web must both work).
- Unknown method or unknown field → a defined `error` response
  (`code: "UNKNOWN_METHOD"`). Never crash, never answer with silence.

## 4. Security baseline (every item: never relax)

- Every JS→native call is untrusted input. Validate the envelope against the
  contract schema BEFORE dispatching to any handler — treat it exactly like an
  exported/IPC entry point.
- Origin/host allowlist is checked before any handler runs; the bridge is
  disabled entirely on a non-allowlisted page.
- Expose the minimal method surface. Never expose a generic `eval` / `exec` /
  "run arbitrary native" method — enumerate concrete methods only.
- No secrets or long-lived tokens cross the bridge unless the contract says so,
  explicitly, scoped and short-lived.
- HTTPS-only content; `file://` and mixed content stay disabled unless the
  contract explicitly requires them (and then origin-scoped).
- Bound payload size; reject oversized messages with a typed error
  (`code: "PAYLOAD_TOO_LARGE"`) rather than letting a page OOM the bridge.

## 5. Threading

Incoming JS calls do NOT all arrive on the main thread (see the platform
reference for where each lands). Normalize every inbound message onto one
dispatcher, and keep handlers off the delivery thread if they block. Native→JS
evaluation (`evaluateJavascript` / `evaluateJavaScript`) MUST run on the main
thread on Android and iOS. A handler never blocks the delivery thread.

## 6. Lifecycle

- Register the bridge on view attach, unregister on detach — registration is
  tied to the view lifecycle, not the app.
- Guard every async callback against a destroyed WebView: check the view is
  still alive before evaluating JS back into it.
- Define recovery for renderer/content-process termination (Android
  `onRenderProcessGone`, iOS `webViewWebContentProcessDidTerminate`): reload and
  re-handshake rather than resuming into a dead view.

## 7. Errors & timeouts

- Every JS-side request carries a timeout and a typed error path; on timeout it
  rejects with `code: "TIMEOUT"`.
- Native handlers map every thrown exception to a contract error code — an
  uncaught exception must never propagate as a crash or a dropped response.

## 8. Debugging

- Log the correlation `id` on both sides of every request/response so a lost
  message is traceable.
- Inspector hookup: Android `chrome://inspect` (enable
  `setWebContentsDebuggingEnabled` in debug builds only), iOS Safari Web
  Inspector (`isInspectable` on iOS 16.4+, debug only).

## 9. Guard-mode checklist (severity in brackets)

- [Critical] JS→native input dispatched without schema validation (§4).
- [Critical] Origin/host allowlist not enforced before handlers (§4).
- [Critical] Generic eval/exec-style method exposed (§4).
- [Critical] Debugging enabled in a release build (§8).
- [High] No handshake queue → early calls lost (§3).
- [High] Non-additive contract change without a deprecation window (§3).
- [High] Native→JS eval off the main thread, or handler blocks delivery
  thread (§5).
- [High] Async callback fires into a destroyed WebView (§6).
- [High] Secrets/long-lived tokens crossing the bridge outside the contract
  (§4).
- [Medium] No payload-size bound (§4); no request timeout (§7).
- [Medium] Exceptions not mapped to contract error codes (§7).
- [Medium] `file://` / mixed content enabled without contract basis (§4).
- [Low] Missing correlation-id logging (§8); unknown method not returning a
  typed error (§3).

Each platform reference appends only platform-specific checklist items — the
core items above are not repeated there.

## References

- `references/contract-template.md` — fill this BEFORE any generation.
- `references/{android,ios,kmp,rn,flutter}.md` — the one binding for the
  detected platform. Read exactly one.
- `scripts/validate_envelope.py` — offline validator for a message envelope /
  a captured message log against §2 rules; use it in guard mode to check real
  traffic, and in generator mode to self-check emitted examples.

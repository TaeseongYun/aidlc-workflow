# ios-security — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per
failure mode. Swift / SwiftUI, with Info.plist/entitlements notes. Decision
criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- A large share of AI-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets more often than human-only commits.
- Developers **overtrust** AI code, believing it safer than it is.
- Mobile twist: the app binary ships to the device — **anything embedded is
  extractable** (keys, endpoints, logic). The price of AI speed is a review gate.

## 1. Secrets → Keychain, not UserDefaults

```swift
// ❌ UserDefaults / plist is not secure storage
UserDefaults.standard.set(jwt, forKey: "authToken")

// ✅ Keychain with a scoped accessibility class
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "authToken",
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, // device-only, unlocked
    kSecValueData as String: Data(jwt.utf8),
]
SecItemAdd(query as CFDictionary, nil)
// (or a thin wrapper / the project's existing Keychain helper)
```

## 2. No embedded privileged secret

```swift
// ❌ Private API called with an embedded key → key is in the extractable binary
let r = try await session.data(from: URL(string: "https://api.stripe.com/…?key=sk_live_…")!)

// ✅ Call YOUR backend; the server holds the secret
let r = try await api.post("/charge", body: ChargeRequest(orderID: id))
```

- `.env`/secret config in `.gitignore`; a committed secret is leaked → rotate.

## 3. HTTPS only, no ATS bypass, no trust-all

```xml
<!-- ❌ Info.plist — disables App Transport Security globally -->
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
<!-- ✅ keep ATS on; add narrow, justified per-domain exceptions only if unavoidable -->
```

```swift
// ❌ Trust-all challenge handler defeats TLS
func urlSession(_ s: URLSession, didReceive c: URLAuthenticationChallenge,
                completionHandler h: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    h(.useCredential, URLCredential(trust: c.protectionSpace.serverTrust!))   // NO
}
// ✅ Don't implement a bypass; use the default trust evaluation (or correct pinning).
```

## 4. Validate URL input, no trust-boundary force-unwraps

```swift
// ❌ force-unwrap chain on untrusted input
let id = UUID(uuidString: URLComponents(url: url, resolvingAgainstBaseURL: false)!
    .queryItems!.first(where: { $0.name == "id" })!.value!)!

// ✅ validate → typed route → fallback  (detail in ios-navigation-deeplink)
let route = DeepLinkParser.route(for: url)   // undefined input → .home, never a crash
```

## 5. WKWebView — no native bridge to untrusted content

```swift
// ❌ message handler bridges native capability to an arbitrary page
let cfg = WKWebViewConfiguration()
cfg.userContentController.add(self, name: "native")   // page can call native
webView.load(URLRequest(url: userProvidedURL))

// ✅ bridge only content you control; restrict navigation via the delegate
func webView(_ w: WKWebView, decidePolicyFor nav: WKNavigationAction,
             decisionHandler d: @escaping (WKNavigationActionPolicy) -> Void) {
    d(nav.request.url?.host == "app.example.com" ? .allow : .cancel)
}
```

## 6. Logs & pasteboard

```swift
// ❌ print("token=\(jwt)"); os_log("resp \(body)"); UIPasteboard.general.string = secret
// ✅ redact; mark sensitive os_log values private; don't put secrets on the general pasteboard
Logger().info("login ok userID=\(user.id, privacy: .public) token=\(jwt, privacy: .private)")
```

## 7. Crypto — CryptoKit, secure RNG

```swift
// ❌ CommonCrypto MD5 / SHA1 for security, AES-ECB, seeded RNG for a token
// ✅ CryptoKit
import CryptoKit
let key = SymmetricKey(size: .bits256)
let sealed = try AES.GCM.seal(data, using: key)          // AES-GCM, random nonce
let digest = SHA256.hash(data: data)                     // SHA-256

// secure token
var bytes = [UInt8](repeating: 0, count: 32)
_ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
let token = Data(bytes).base64EncodedString()
```

## 8. Data Protection at rest

```swift
// ✅ write sensitive files with a protection class
try data.write(to: url, options: [.completeFileProtectionUnlessOpen])
// ❌ .noFileProtection on sensitive data; syncing device-only secrets
```

## 9. Vulnerable / hallucinated Swift Package deps (slopsquatting)

```
- Verify an AI-suggested Swift Package actually exists and is legitimate (repo,
  stars, recent releases, author). Typo-similar · brand-new · unmaintained →
  suspect slopsquatting, do not add.
- Pin exact versions (.exact / a tag) and commit Package.resolved.
- Review advisories; remove or update anything with a known CVE.
```

## Full vibe-guard review checklist

- [ ] Secrets in the Keychain (scoped accessibility), never `UserDefaults`/plist/source.
- [ ] No embedded privileged secret; privileged calls proxied; no committed `.env`.
- [ ] HTTPS only; no `NSAllowsArbitraryLoads`; no trust-all challenge handler.
- [ ] URL/activity input validated; no force-unwraps on trust-boundary data.
- [ ] WKWebView: no native bridge to untrusted content; navigation restricted.
- [ ] No tokens/PII in logs; sensitive `os_log` `.private`; secrets off the pasteboard.
- [ ] CryptoKit + secure RNG; no MD5/SHA1/ECB/home-rolled crypto.
- [ ] Sensitive files use Data Protection; Keychain accessibility scoped.
- [ ] Swift Packages real · legitimate · maintained · pinned · CVE-free.

## Official references

- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS: https://mas.owasp.org/MASVS/
- OWASP MASTG: https://mas.owasp.org/MASTG/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- Keychain services: https://developer.apple.com/documentation/security/keychain_services
- App Transport Security: https://developer.apple.com/documentation/bundleresources/information_property_list/nsapptransportsecurity
- CryptoKit: https://developer.apple.com/documentation/cryptokit
- CWE Top 25: https://cwe.mitre.org/top25/
- Team baseline: [../../guidance.md](../../guidance.md)

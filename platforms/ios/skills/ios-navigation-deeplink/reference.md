# ios-navigation-deeplink — Reference

Deep-dive for `SKILL.md`. Validation flow, route contract, fallback patterns.
Decision criteria live in `SKILL.md`.

## 1. Document the external contract

```
scheme://order/{id}          id: UUID (required)        → OrderDetail
https://app.example.com/u/{handle}   handle: String (1–30, [a-z0-9_])  → Profile
```

- Each entry: URL pattern, parameters **with types**, validation rules. This is
  the app's external API — treat it like one.

## 2. Validated deep-link flow (centralized at App/Scene)

```swift
enum Route: Hashable { case orderDetail(Order.ID), profile(handle: String), home }

enum DeepLinkParser {
    static func route(for url: URL) -> Route {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return .home }
        switch (comps.host, comps.path) {
        case ("order", let p) where p.hasPrefix("/"):
            guard let id = UUID(uuidString: String(p.dropFirst())) else { return .home } // validate → fallback
            return .orderDetail(id)
        case ("u", let p):
            let handle = String(p.dropFirst())
            guard handle.range(of: "^[a-z0-9_]{1,30}$", options: .regularExpression) != nil else { return .home }
            return .profile(handle: handle)
        default:
            return .home    // undefined input → defined fallback, never a crash
        }
    }
}
```

```swift
// ❌ Anti-patterns
let id = UUID(uuidString: comps.queryItems!.first!.value!)!   // force-unwrap across a trust boundary
navigationPath.append(url.lastPathComponent)                   // unvalidated URL → nav state
```

## 3. Wire it at the Scene boundary

```swift
@main struct MyApp: App {
    @State private var path: [Route] = []
    var body: some Scene {
        WindowGroup {
            RootView(path: $path)
                .onOpenURL { url in path.append(DeepLinkParser.route(for: url)) }        // custom scheme
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in     // Universal Link
                    if let url = activity.webpageURL { path.append(DeepLinkParser.route(for: url)) }
                }
        }
    }
}
```

## 4. Undefined input → defined fallback

- Unknown host/path → `.home` (or a not-found route). Never crash, never guess.
- Invalid parameter type/format → fallback, optionally with a user-visible message.
- Keep the fallback a real, designed destination.

## 5. Navigation review checklist

- [ ] Each external entry documents pattern · typed params · validation.
- [ ] URL parsing centralized at App/Scene, not scattered in views.
- [ ] Parameters parsed & type-checked before building a route.
- [ ] No force-unwraps on deep-link data (trust boundary).
- [ ] Undefined/invalid input lands on a defined fallback.
- [ ] Navigation built as typed route data after validation.
- [ ] Info.plist/entitlements updated when the external surface changes.

## Official references

- Custom URL scheme: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
- Universal Links: https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app
- Allowing apps to link to your content: https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content
- `NSUserActivity`: https://developer.apple.com/documentation/foundation/nsuseractivity
- Team baseline: [../../guidance.md](../../guidance.md)

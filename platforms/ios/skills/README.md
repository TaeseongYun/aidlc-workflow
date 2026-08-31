# iOS Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team iOS baseline) into 7 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/ios-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the security floor (safety rules) is never lowered.**

Stack: Swift + SwiftUI + Swift Concurrency (async/await, actors) + Observation (`@Observable`), SPM modules.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [ios-architecture](ios-architecture/SKILL.md) | App-architecture skeleton — dependency flow · layer responsibilities · navigation-as-data · Feature Slice. The umbrella that ties the other 5 together | (none — description keywords · manual · cross-links) |
| [ios-state-concurrency](ios-state-concurrency/SKILL.md) | One state type per screen (enum, not parallel optionals) · `@Observable`/`@MainActor` · navigation route data · actor isolation · `Sendable` (no `@unchecked` silencer) · Task cancellation · async/await over Combine | `**/*ViewModel.swift`, `**/*Store.swift`, `**/*State.swift`, `**/*Actor.swift`, `**/ViewModels/**/*.swift` |
| [ios-module-structure](ios-module-structure/SKILL.md) | Thin app target + SPM packages · mandatory Feature\<Name\>API/Impl target pair (API = navigation surface only) · composition-root DI (no framework) | `**/Package.swift`, `**/Packages/**/*.swift`, `**/App/**/*.swift`, `**/*App.swift` |
| [ios-platform-adapters](ios-platform-adapters/SKILL.md) | System frameworks (CoreLocation/AVFoundation/StoreKit/UserNotifications) behind injected protocol adapters · permission-denied state · repository DTO↔domain mapping · UserDefaults vs repository vs Keychain | `**/*Adapter.swift`, `**/*Repository.swift`, `**/*Client.swift`, `**/*Service.swift`, `**/DataSources/**/*.swift` |
| [ios-navigation-deeplink](ios-navigation-deeplink/SKILL.md) | URL schemes / Universal Links external contract · deep-link parameter validation · trust-boundary fallback · route data | `**/*App.swift`, `**/*Scene*.swift`, `**/*Router*.swift`, `**/*Route*.swift`, `**/*Coordinator*.swift`, `**/*DeepLink*.swift`, `**/Info.plist` |
| [ios-security](ios-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (Keychain vs UserDefaults · embedded secrets · ATS/TLS bypass · deep-link input · WKWebView · log/pasteboard leaks · weak crypto · Data Protection · hallucinated SPM deps) | `**/*.swift`, `**/Info.plist`, `**/*.entitlements`, `**/Package.swift`, `**/Package.resolved`, `**/.env*` |
| [ios-figma-to-code](ios-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → SwiftUI views + theme (node→View · token→asset-catalog/Theme). Generated code references tokens, not literals, and must still pass ios-security | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/*Theme.swift`, `**/DesignSystem/**/*.swift`, `**/*.xcassets/**` |

## Vibe-guard gist

AI-generated iOS code is fast but frequently vulnerable, and an app ships its binary to the device where anything
embedded can be extracted. `ios-security` fills that gap as a **pre-merge review guard** — it auto-loads when you
touch Swift source · Info.plist · entitlements · Package manifests and catches the most common vulnerable patterns.
The other 6 skills are the deep architecture/quality/codegen rules alongside this guard — Figma-generated SwiftUI is routed back through ios-security before merge.

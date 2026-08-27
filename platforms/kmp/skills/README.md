# KMP (Kotlin Multiplatform) Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team KMP baseline) into 13 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/kmp-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the security floor (safety rules) is never lowered.**

Stack: Kotlin Multiplatform, Compose Multiplatform (Material3) for UI, `StateFlow`/MVI for state,
Ktor + kotlinx.serialization for data, and `expect`/`actual` as the platform boundary (the KMP analog of
Flutter's platform-channel adapter). Shared code lives in `commonMain`; platform code in `androidMain`/`iosMain`.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [kmp-architecture](kmp-architecture/SKILL.md) | App architecture skeleton — dependency flow · layer responsibilities · state home · `expect`/`actual` platform boundary · Feature Slice. The umbrella that ties the other 12 together | (none — description keywords · manual · cross-links) |
| [kmp-module-structure](kmp-module-structure/SKILL.md) | Source-set layout (`commonMain`/`androidMain`/`iosMain`) · Gradle KMP setup · `expect`/`actual` placement · DI scoping · module split timing | `**/build.gradle.kts`, `**/settings.gradle.kts`, `**/gradle/libs.versions.toml`, `**/commonMain/**`, `**/di/**/*.kt` |
| [kmp-state-management](kmp-state-management/SKILL.md) | Sealed/immutable `UiState` · `StateFlow` UDF · effects vs state (`Channel`/`SharedFlow`) · coroutine-scope safety · ViewModel/ScreenModel/component (never mixed) | `**/*ViewModel.kt`, `**/*ScreenModel.kt`, `**/*Component.kt`, `**/*State.kt`, `**/presentation/**/*.kt` |
| [kmp-navigation-platform](kmp-navigation-platform/SKILL.md) | Compose Navigation/Decompose/Voyager · deep-link parameter validation · `expect`/`actual` platform adapters | `**/*Nav*.kt`, `**/navigation/**/*.kt`, `**/*Route*.kt`, `**/androidMain/**/*.kt`, `**/iosMain/**/*.kt` |
| [kmp-design-system](kmp-design-system/SKILL.md) | **Design-system guard** — blocks hardcoded colors/spacing/type, ad-hoc components, off-scale variants; enforces `MaterialTheme` tokens + `CompositionLocal` scales | `**/theme/**/*.kt`, `**/ui/**/*.kt`, `**/*Theme.kt`, `**/design*/**/*.kt` |
| [kmp-figma-to-code](kmp-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → Compose Multiplatform composables + `MaterialTheme` (node→composable · token→ColorScheme/Typography/CompositionLocal). Generated code references tokens, not literals, and must still pass kmp-security | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/*Theme.kt`, `**/theme/**/*.kt` |
| [kmp-accessibility](kmp-accessibility/SKILL.md) | Compose `semantics` — role/`contentDescription` · accessible name · decorative hidden · touch target 48dp · state exposed · font scaling · color-not-sole-signal · focus order · merge/group · platform a11y via `expect`/`actual` | `**/*Screen.kt`, `**/*Composable*.kt`, `**/ui/**/*.kt` |
| [kmp-i18n](kmp-i18n/SKILL.md) | **i18n guard** — no hardcoded strings; Compose resources/moko-resources keys · ICU plurals · locale-aware date/number formatting (`kotlinx-datetime` + `expect`/`actual`) · RTL-safe layout | `**/*.kt`, `**/composeResources/**`, `**/*.strings`, `**/MR/**` |
| [kmp-performance](kmp-performance/SKILL.md) | Compose recomposition · `@Stable`/`@Immutable` · `remember`/`derivedStateOf` · stable params · `LazyColumn` keys · optimize on evidence | `**/*Screen.kt`, `**/*Composable*.kt`, `**/ui/**/*.kt` |
| [kmp-security](kmp-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (embedded secrets · insecure storage · TLS bypass · deep-link/`expect`/`actual` input · WebView · SQL injection · log leakage · weak crypto · unsafe serialization · hallucinated deps) | `**/*.kt`, `**/build.gradle.kts`, `**/gradle/libs.versions.toml`, `**/AndroidManifest.xml`, `**/Info.plist`, `**/.env*` |
| [kmp-testing](kmp-testing/SKILL.md) | Test generation + guard — `commonTest` with `kotlin.test` · `runTest` (coroutines) · **Turbine** (Flow) · `runComposeUiTest` · blocks the 10 AI-test failure modes | `**/commonTest/**/*.kt`, `**/*Test.kt`, `**/androidUnitTest/**/*.kt` |
| [kmp-observability](kmp-observability/SKILL.md) | **Observability guard** — structured logging (Kermit/Napier, no `println`) · correlation IDs · metrics · crash reporting via `expect`/`actual` · no PII/secrets in logs | `**/*.kt`, `**/logging/**/*.kt` |
| [kmp-contract-codegen](kmp-contract-codegen/SKILL.md) | Contract codegen — OpenAPI/GraphQL → typed Ktor client (kotlinx.serialization) / Apollo Kotlin + drift guard. Generated types are the single source of truth; no hand-written DTOs | `**/openapi*.yaml`, `**/openapi*.json`, `**/*.graphql`, `**/*.graphqls`, `**/generated/**/*.kt`, `**/build.gradle.kts` |

## Vibe-guard gist

AI-generated KMP code is fast but frequently vulnerable, and a mobile/desktop app ships its secrets to the device
where they can be extracted. `kmp-security` fills that gap as a **pre-merge review guard** — it auto-loads when
you touch Kotlin source · Gradle files · platform manifests and catches the most common vulnerable patterns. The
other 12 skills are the deep architecture/quality/codegen rules alongside this guard — Figma-generated composables
are routed back through kmp-security before merge.

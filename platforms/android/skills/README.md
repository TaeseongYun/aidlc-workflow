# Android Detailed Skills

**Reference-knowledge skills** expanding `guidance.md` (the team Android
baseline) into 7 topics. Each skill follows the official skills format
(`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch a related
file, and can also be invoked manually as `/android-*`. Deep-dive material is in
each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and
reference it by relative path. If a project's `ctx/` conflicts, the project CTX
takes precedence (following the guidance precedence as-is). However, **the
security floor (safety rules) is never lowered.** `android-security` is organized
by Android's exported-surface trust boundary rather than the numbered
failure-mode format the other platforms' security guards adopt — the enforced
floor is the same.

| Skill | Purpose | Auto-load (paths) |
|------|------|-----------------|
| [android-architecture](android-architecture/SKILL.md) | App architecture backbone — dependency flow, layer responsibilities, Feature Slice decision. The umbrella tying the other 5 together | (none — description keywords, manual, cross-links) |
| [android-viewmodel-state](android-viewmodel-state/SKILL.md) | UiState/StateFlow, events (effect), SavedStateHandle, UDF | `**/*ViewModel.kt`, `**/ui/**/*.kt` |
| [android-module-structure](android-module-structure/SKILL.md) | app/core/feature split, api\|impl split timing, convention plugins, version catalogs | `**/build.gradle.kts`, `**/settings.gradle.kts`, `**/libs.versions.toml`, `**/*.gradle` |
| [android-lifecycle-memory](android-lifecycle-memory/SKILL.md) | Lifecycle-aware collection, scope cancellation, onTrimMemory, leak prevention | `**/*Activity.kt`, `**/*Fragment.kt`, `**/ui/**/*.kt` |
| [android-background-rules](android-background-rules/SKILL.md) | Background execution limits, WorkManager, foreground services, Doze, background location | `**/*Worker.kt`, `**/*Service.kt`, `**/AndroidManifest.xml` |
| [android-security](android-security/SKILL.md) | **Security guard** — exported trust boundary, Intent/extras validation, data encryption, network security, Keystore, Play Integrity | `**/AndroidManifest.xml`, `**/network_security_config.xml`, `**/*.kt` |
| [android-figma-to-code](android-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → Jetpack Compose + theme (node→composable · token→ColorScheme/Typography/designsystem). Generated code references tokens/resources, not literals, and must still pass android-security | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/ui/theme/**/*.kt`, `**/designsystem/**/*.kt`, `**/*Theme.kt` |

## Security floor

`android-security` is the platform's safety guard: it auto-loads when you touch the manifest ·
network-security config · Kotlin source and blocks vulnerable patterns on Android's exported
trust boundary (Intent/extras validation, data encryption, Keystore, network security, Play
Integrity). The other 6 skills are the architecture/quality/codegen rules alongside it — Figma-generated Compose is routed back through android-security before merge.

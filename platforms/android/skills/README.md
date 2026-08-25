# Android Detailed Skills

**Reference-knowledge skills** expanding `guidance.md` (the team Android
baseline) into 6 topics. Each skill follows the official skills format
(`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch a related
file, and can also be invoked manually as `/android-*`. Deep-dive material is in
each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and
reference it by relative path. If a project's `ctx/` conflicts, the project CTX
takes precedence (following the guidance precedence as-is).

| Skill | Purpose | Auto-load (paths) |
|------|------|-----------------|
| [android-architecture](android-architecture/SKILL.md) | App architecture backbone — dependency flow, layer responsibilities, Feature Slice decision. The umbrella tying the other 5 together | (none — description keywords, manual, cross-links) |
| [android-viewmodel-state](android-viewmodel-state/SKILL.md) | UiState/StateFlow, events (effect), SavedStateHandle, UDF | `**/*ViewModel.kt`, `**/ui/**/*.kt` |
| [android-module-structure](android-module-structure/SKILL.md) | app/core/feature split, api\|impl split timing, convention plugins, version catalogs | `**/build.gradle.kts`, `**/settings.gradle.kts`, `**/libs.versions.toml`, `**/*.gradle` |
| [android-lifecycle-memory](android-lifecycle-memory/SKILL.md) | Lifecycle-aware collection, scope cancellation, onTrimMemory, leak prevention | `**/*Activity.kt`, `**/*Fragment.kt`, `**/ui/**/*.kt` |
| [android-background-rules](android-background-rules/SKILL.md) | Background execution limits, WorkManager, foreground services, Doze, background location | `**/*Worker.kt`, `**/*Service.kt`, `**/AndroidManifest.xml` |
| [android-security](android-security/SKILL.md) | Exported trust boundary, Intent/extras validation, data encryption, network security, Keystore, Play Integrity | `**/AndroidManifest.xml`, `**/network_security_config.xml`, `**/*.kt` |

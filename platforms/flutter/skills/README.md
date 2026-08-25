# Flutter Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team Flutter baseline) into 6 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/flutter-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the security floor (safety rules) is never lowered.**

Stack: feature-first Flutter/Dart, Riverpod **or** Bloc (whichever the project already uses — never both).

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [flutter-architecture](flutter-architecture/SKILL.md) | App architecture skeleton — dependency flow · layer responsibilities · state home · platform-channel boundary · Feature Slice. The umbrella that ties the other 5 together | (none — description keywords · manual · cross-links) |
| [flutter-state-management](flutter-state-management/SKILL.md) | Sealed/immutable state · effects vs state · UDF · async-gap safety · Riverpod/Bloc (never both) | `**/*_controller.dart`, `**/*_notifier.dart`, `**/*_bloc.dart`, `**/*_cubit.dart`, `**/*_state.dart`, `**/presentation/**/*.dart` |
| [flutter-module-structure](flutter-module-structure/SKILL.md) | Feature-first `lib/` layout · DI/provider scoping · melos split timing | `**/pubspec.yaml`, `**/melos.yaml`, `**/lib/main.dart`, `**/lib/di/**`, `**/*_providers.dart` |
| [flutter-widget-performance](flutter-widget-performance/SKILL.md) | `const` · rebuild scope (`select`/`buildWhen`) · `mounted` after await · theme/localization (no literals) · optimize on evidence | `**/*_screen.dart`, `**/*_page.dart`, `**/*_view.dart`, `**/widgets/**/*.dart`, `**/presentation/**/*.dart` |
| [flutter-navigation-platform](flutter-navigation-platform/SKILL.md) | go_router/Navigator 2.0 · deep-link parameter validation · platform-channel adapters · `Platform.isX` in adapters | `**/*_router.dart`, `**/router*.dart`, `**/*_route*.dart`, `**/*_channel.dart`, `**/platform/**/*.dart`, `**/*_adapter.dart` |
| [flutter-security](flutter-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (embedded secrets · insecure storage · TLS bypass · deep-link/channel input · WebView · sqflite injection · log leakage · weak crypto · insecure manifests · hallucinated deps) | `**/*.dart`, `**/pubspec.yaml`, `**/pubspec.lock`, `**/AndroidManifest.xml`, `**/Info.plist`, `**/.env*` |

## Vibe-guard gist

AI-generated Flutter code is fast but frequently vulnerable, and a mobile app ships its secrets to the device
where they can be extracted. `flutter-security` fills that gap as a **pre-merge review guard** — it auto-loads when
you touch Dart source · pubspec · platform manifests and catches the most common vulnerable patterns. The other
5 skills are the deep architecture/quality rules this guard references.

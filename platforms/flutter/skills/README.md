# Flutter Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team Flutter baseline) into 13 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/flutter-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the security floor (safety rules) is never lowered.**

Stack: feature-first Flutter/Dart, Riverpod **or** Bloc (whichever the project already uses — never both).

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [flutter-architecture](flutter-architecture/SKILL.md) | App architecture skeleton — dependency flow · layer responsibilities · state home · platform-channel boundary · Feature Slice. The umbrella that ties the other 12 together | (none — description keywords · manual · cross-links) |
| [flutter-state-management](flutter-state-management/SKILL.md) | Sealed/immutable state · effects vs state · UDF · async-gap safety · Riverpod/Bloc (never both) | `**/*_controller.dart`, `**/*_notifier.dart`, `**/*_bloc.dart`, `**/*_cubit.dart`, `**/*_state.dart`, `**/presentation/**/*.dart` |
| [flutter-module-structure](flutter-module-structure/SKILL.md) | Feature-first `lib/` layout · DI/provider scoping · melos split timing | `**/pubspec.yaml`, `**/melos.yaml`, `**/lib/main.dart`, `**/lib/di/**`, `**/*_providers.dart`, `**/injection*.dart` |
| [flutter-widget-performance](flutter-widget-performance/SKILL.md) | `const` · rebuild scope (`select`/`buildWhen`) · `mounted` after await · theme/localization (no literals) · optimize on evidence | `**/*_screen.dart`, `**/*_page.dart`, `**/*_view.dart`, `**/widgets/**/*.dart`, `**/presentation/**/*.dart` |
| [flutter-navigation-platform](flutter-navigation-platform/SKILL.md) | go_router/Navigator 2.0 · deep-link parameter validation · platform-channel adapters · `Platform.isX` in adapters | `**/*_router.dart`, `**/router*.dart`, `**/*_route*.dart`, `**/*_channel.dart`, `**/platform/**/*.dart`, `**/*_adapter.dart` |
| [flutter-security](flutter-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (embedded secrets · insecure storage · TLS bypass · deep-link/channel input · WebView · sqflite injection · log leakage · weak crypto · insecure manifests · hallucinated deps) | `**/*.dart`, `**/pubspec.yaml`, `**/pubspec.lock`, `**/AndroidManifest.xml`, `**/Info.plist`, `**/.env*` |
| [flutter-figma-to-code](flutter-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → Flutter widgets + theme (node→widget · token→ThemeExtension/TextTheme · `const`). Generated code references tokens, not literals, and must still pass flutter-security | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/*_theme.dart`, `**/theme/**/*.dart`, `**/design_system/**/*.dart` |
| [flutter-design-system](flutter-design-system/SKILL.md) | **Design-system guard** — blocks hardcoded colors/spacing/type, ad-hoc components, off-scale variants; enforces theme tokens. The enforcement pair to flutter-figma-to-code | `**/theme/**`, `**/*_theme.dart`, `**/design_system/**`, `**/tokens.dart`, `**/lib/**/*.dart` |
| [flutter-accessibility](flutter-accessibility/SKILL.md) | Flutter a11y — `Semantics` roles/labels · decorative excluded · 48dp touch targets · state exposed · `textScaler` font scaling · WCAG AA contrast · focus into dialogs/sheets · `MergeSemantics` | `**/lib/**/*.dart`, `**/widgets/**/*.dart` |
| [flutter-i18n](flutter-i18n/SKILL.md) | **i18n guard** — no hardcoded strings; ARB keys · ICU plurals · locale-aware date/number formatting · RTL-safe layout | `**/lib/**/*.dart`, `**/l10n/**`, `**/*.arb`, `**/l10n.yaml` |
| [flutter-testing](flutter-testing/SKILL.md) | Test generation + guard — `flutter_test` + `testWidgets` · mocktail · `integration_test` · golden tests · `fakeAsync` · blocks the 10 AI-test failure modes | `**/test/**`, `**/integration_test/**`, `**/*_test.dart` |
| [flutter-observability](flutter-observability/SKILL.md) | **Observability guard** — structured logging (no stray `print`) · correlation IDs · metrics · crash reporting · no PII/secrets in logs | `**/lib/**/*.dart`, `**/*.dart` |
| [flutter-contract-codegen](flutter-contract-codegen/SKILL.md) | Contract codegen — OpenAPI/GraphQL → typed Dart client (dart-dio · swagger_parser + retrofit · ferry) + drift guard. Generated types are the single source of truth; no hand-written DTOs | `**/openapi*.{yaml,yml,json}`, `**/*.graphql`, `**/*.g.dart`, `**/build.yaml`, `**/pubspec.yaml` |

## Vibe-guard gist

AI-generated Flutter code is fast but frequently vulnerable, and a mobile app ships its secrets to the device
where they can be extracted. `flutter-security` fills that gap as a **pre-merge review guard** — it auto-loads when
you touch Dart source · pubspec · platform manifests and catches the most common vulnerable patterns. The other
12 skills are the deep architecture/quality/codegen rules alongside this guard — Figma-generated widgets are routed back through flutter-security before merge.

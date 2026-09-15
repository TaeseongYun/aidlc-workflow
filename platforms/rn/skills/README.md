# React Native Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team RN baseline) into 13 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/rn-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
RN shares the web frontend's React boundaries ([`../../frontend/guidance.md`](../../frontend/guidance.md)) plus the
mobile-specific rules here. When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the safety floors (security rules, accessibility rules) are never lowered.**

Stack: TypeScript + React Navigation / Expo Router + Turbo Modules / Fabric; one styling system, one state library.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [rn-architecture](rn-architecture/SKILL.md) | App-architecture skeleton — Screen → Container → Presentational · server-vs-client state · one API boundary · native-module boundary · Feature Slice. The umbrella that ties the other 12 together | (none — description keywords · manual · cross-links) |
| [rn-state-data](rn-state-data/SKILL.md) | Server vs client state · state decision table · four fetch states · persisted state via storage adapter · secure storage for secrets | `**/hooks/**/*.ts(x)`, `**/*use*.ts(x)`, `**/store/**/*.ts`, `**/queries/**/*.ts`, `**/*.query.ts`, `**/lib/storage/**` |
| [rn-native-modules](rn-native-modules/SKILL.md) | Native adapter interface · Turbo Modules/Fabric · `Platform.OS` boundary · native-dependency justification · permission-denied state | `**/lib/native/**`, `**/*Adapter.ts(x)`, `**/*.native.ts`, `**/*.ios.tsx`, `**/*.android.tsx`, `**/modules/**/*.ts` |
| [rn-navigation-lifecycle](rn-navigation-lifecycle/SKILL.md) | Typed route params · deep-link validation · AppState · offline/network · permission paths | `**/navigation/**`, `**/app/**`, `**/*Navigator.tsx`, `**/*Screen.tsx`, `**/linking*.ts`, `**/*route*.ts` |
| [rn-performance-ux](rn-performance-ux/SKILL.md) | `FlatList`/`FlashList` + stable keys · Reanimated worklets · one styling system · **accessibility safety guard** (roles/labels, ≥44pt) | `**/*.tsx`, `**/*.jsx`, `**/components/**/*.tsx`, `**/*List*.tsx`, `**/theme/**` |
| [rn-security](rn-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (bundle secrets · insecure storage · TLS bypass · deep-link input · WebView · log leakage · weak crypto · insecure manifests · hallucinated deps) | `**/*.ts`, `**/*.tsx`, `**/app.json`, `**/app.config.*`, `**/AndroidManifest.xml`, `**/Info.plist`, `**/.env*` |
| [rn-figma-to-code](rn-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → React Native components + theme (node→View/Text · token→theme object). The mobile delta on [frontend-figma-to-code](../../frontend/skills/frontend-figma-to-code/SKILL.md); generated code must still pass the a11y + security floors | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/theme/**/*.ts`, `**/*.styles.ts`, `**/*theme*.ts` |
| [rn-design-system](rn-design-system/SKILL.md) | **Design-system guard** — blocks hardcoded colors/spacing/type, ad-hoc components, off-scale variants; enforces theme tokens. The enforcement pair to rn-figma-to-code | `**/theme/**`, `**/tokens.*`, `**/design-system/**`, `**/*.tsx`, `**/components/**` |
| [rn-accessibility](rn-accessibility/SKILL.md) | RN a11y — `accessibilityRole`/`accessibilityLabel` · decorative hidden · 44pt/48dp touch targets · state via `accessibilityState` · font scaling never disabled · color-not-sole-signal · focus on overlays · `Pressable` over `View`+`onPress` | `**/*.tsx`, `**/*.jsx`, `**/components/**` |
| [rn-i18n](rn-i18n/SKILL.md) | **i18n guard** — no hardcoded strings; translation keys · ICU plurals · locale-aware date/number formatting · RTL-safe layout | `**/*.tsx`, `**/*.ts`, `**/locales/**`, `**/*.json` |
| [rn-testing](rn-testing/SKILL.md) | Test generation + guard — Jest · @testing-library/react-native · MSW · Detox/Maestro · blocks the 10 AI-test failure modes | `**/*.test.ts(x)`, `**/__tests__/**`, `**/e2e/**` |
| [rn-observability](rn-observability/SKILL.md) | **Observability guard** — structured logging (no stray `console.log`) · correlation IDs · metrics · crash reporting · no PII/secrets in logs | `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx` |
| [rn-contract-codegen](rn-contract-codegen/SKILL.md) | Contract codegen — OpenAPI/GraphQL → typed TS client (openapi-typescript · orval · @graphql-codegen) + drift guard. Generated types are the single source of truth; no hand-written DTOs | `**/openapi*.{yaml,yml,json}`, `**/*.graphql`, `**/generated/**`, `**/*.gen.ts` |

## Two safety guards

RN carries **two** floors that are never lowered for speed:

- `rn-accessibility` (plus the a11y guard rules in `rn-performance-ux`) — accessibility is a safety guard (roles/labels on interactive elements, touch targets ≥ 44pt).
- `rn-security` — AI-generated RN code is fast but frequently vulnerable, and the JS bundle + app package ship to the
  device where secrets can be extracted. This guard auto-loads when you touch RN source · app config · native manifests
  and catches the most common vulnerable patterns.

The other 11 skills — architecture, data, native modules, navigation, performance, figma-to-code, design system, i18n, testing, observability, and contract codegen — are the capability/quality rules; Figma-generated RN is routed back through both guards before merge.

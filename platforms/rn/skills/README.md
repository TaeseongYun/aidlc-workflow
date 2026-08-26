# React Native Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team RN baseline) into 7 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/rn-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
RN shares the web frontend's React boundaries ([`../../frontend/guidance.md`](../../frontend/guidance.md)) plus the
mobile-specific rules here. When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the safety floors (security rules, accessibility rules) are never lowered.**

Stack: TypeScript + React Navigation / Expo Router + Turbo Modules / Fabric; one styling system, one state library.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [rn-architecture](rn-architecture/SKILL.md) | App-architecture skeleton — Screen → Container → Presentational · server-vs-client state · one API boundary · native-module boundary · Feature Slice. The umbrella that ties the other 5 together | (none — description keywords · manual · cross-links) |
| [rn-state-data](rn-state-data/SKILL.md) | Server vs client state · state decision table · four fetch states · persisted state via storage adapter · secure storage for secrets | `**/hooks/**/*.ts(x)`, `**/*use*.ts(x)`, `**/store/**/*.ts`, `**/queries/**/*.ts`, `**/*.query.ts`, `**/lib/storage/**` |
| [rn-native-modules](rn-native-modules/SKILL.md) | Native adapter interface · Turbo Modules/Fabric · `Platform.OS` boundary · native-dependency justification · permission-denied state | `**/lib/native/**`, `**/*Adapter.ts(x)`, `**/*.native.ts`, `**/*.ios.tsx`, `**/*.android.tsx`, `**/modules/**/*.ts` |
| [rn-navigation-lifecycle](rn-navigation-lifecycle/SKILL.md) | Typed route params · deep-link validation · AppState · offline/network · permission paths | `**/navigation/**`, `**/app/**`, `**/*Navigator.tsx`, `**/*Screen.tsx`, `**/linking*.ts`, `**/*route*.ts` |
| [rn-performance-ux](rn-performance-ux/SKILL.md) | `FlatList`/`FlashList` + stable keys · Reanimated worklets · one styling system · **accessibility safety guard** (roles/labels, ≥44pt) | `**/*.tsx`, `**/*.jsx`, `**/components/**/*.tsx`, `**/*List*.tsx`, `**/theme/**` |
| [rn-security](rn-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (bundle secrets · insecure storage · TLS bypass · deep-link input · WebView · log leakage · weak crypto · insecure manifests · hallucinated deps) | `**/*.ts`, `**/*.tsx`, `**/app.json`, `**/app.config.*`, `**/AndroidManifest.xml`, `**/Info.plist`, `**/.env*` |
| [rn-figma-to-code](rn-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → React Native components + theme (node→View/Text · token→theme object). The mobile delta on [frontend-figma-to-code](../../frontend/skills/frontend-figma-to-code/SKILL.md); generated code must still pass the a11y + security floors | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/theme/**/*.ts`, `**/*.styles.ts`, `**/*theme*.ts` |

## Two safety guards

RN carries **two** floors that are never lowered for speed:

- `rn-performance-ux` — accessibility is a safety guard (roles/labels on interactive elements, touch targets ≥ 44pt).
- `rn-security` — AI-generated RN code is fast but frequently vulnerable, and the JS bundle + app package ship to the
  device where secrets can be extracted. This guard auto-loads when you touch RN source · app config · native manifests
  and catches the most common vulnerable patterns.

The other 5 skills — architecture, data, native, navigation, and `rn-figma-to-code` — are the capability/quality rules; Figma-generated RN is routed back through both guards before merge.

# Frontend Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team frontend baseline) into 12 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/frontend-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the safety floors (security rules, accessibility rules) are never lowered.**

Stack: TypeScript + React (Next.js App Router when present); the same boundaries apply to Vue/Svelte with names swapped.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [frontend-architecture](frontend-architecture/SKILL.md) | Component-architecture skeleton — Route/Page → Container → Presentational · server-vs-client state · one API boundary · Feature Slice. The umbrella that ties the other 11 together | (none — description keywords · manual · cross-links) |
| [frontend-state-data](frontend-state-data/SKILL.md) | Server vs client state · state decision table · four fetch states · TanStack Query/RSC · no remote-in-store · derive-don't-store | `**/hooks/**/*.ts(x)`, `**/*use*.ts(x)`, `**/store/**/*.ts`, `**/queries/**/*.ts`, `**/*.query.ts`, `**/app/**/page.tsx` |
| [frontend-module-structure](frontend-module-structure/SKILL.md) | app/components/features/lib layout · one styling system · one state library · route-level code-splitting & lazy boundaries | `**/next.config.*`, `**/vite.config.*`, `**/tailwind.config.*`, `**/tsconfig.json`, `**/package.json`, `**/app/**/layout.tsx` |
| [frontend-api-contract](frontend-api-contract/SKILL.md) | One API client module · typed boundary (no `any`) · error normalization · runtime response validation | `**/lib/api/**`, `**/api/**/*.ts`, `**/*.api.ts`, `**/services/**/*.ts`, `**/*client*.ts`, `**/openapi*.{yaml,json}` |
| [frontend-accessibility](frontend-accessibility/SKILL.md) | **A11y safety guard** — semantic controls (no div-onClick) · labels/alt · focus management · keyboard · platform-over-library | `**/*.tsx`, `**/*.jsx`, `**/components/**` |
| [frontend-security](frontend-security/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (XSS · bundle secrets · token storage · CSRF · open redirect · postMessage · SSRF/injection in server code · prototype pollution · hallucinated deps) | `**/*.tsx`, `**/*.ts`, `**/next.config.*`, `**/middleware.ts`, `**/app/**/route.ts`, `**/.env*` |
| [frontend-figma-to-code](frontend-figma-to-code/SKILL.md) | Figma → code — shared `scripts/figma` manifest + DTCG tokens → React/Next components + theme (node→component · token→theme). Generated output must still pass the a11y + security floors | `**/tokens.json`, `**/*.tokens.json`, `**/design-tokens/**`, `**/figma*.json`, `**/theme/**/*.ts`, `**/tailwind.config.*` |
| [frontend-design-system](frontend-design-system/SKILL.md) | **Design-system guard** — blocks hardcoded colors/spacing/type, ad-hoc components, off-scale variants; enforces theme tokens. The enforcement pair to frontend-figma-to-code | `**/tokens.json`, `**/design-tokens/**`, `**/theme/**`, `**/tailwind.config.*`, `**/*.tsx`, `**/components/**` |
| [frontend-i18n](frontend-i18n/SKILL.md) | **i18n guard** — no hardcoded strings; translation keys · ICU plurals · locale-aware date/number formatting · RTL-safe layout | `**/*.tsx`, `**/*.ts`, `**/locales/**`, `**/messages/**` |
| [frontend-testing](frontend-testing/SKILL.md) | Test generation + guard — Vitest/Jest · Testing Library + user-event · MSW · Playwright · blocks the 10 AI-test failure modes | `**/*.test.ts(x)`, `**/*.spec.ts(x)`, `**/e2e/**` |
| [frontend-observability](frontend-observability/SKILL.md) | **Observability guard** — structured logging (no stray `console.log`) · correlation IDs · metrics · crash reporting · no PII/secrets in logs | `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx` |
| [frontend-contract-codegen](frontend-contract-codegen/SKILL.md) | Contract codegen — OpenAPI/GraphQL → typed client + hooks (openapi-typescript · orval · @graphql-codegen) + drift guard. Generated types are the single source of truth; no hand-written DTOs | `**/openapi*.{yaml,yml,json}`, `**/*.graphql`, `**/generated/**`, `**/*.gen.ts`, `**/codegen.{ts,yml,yaml}` |

## Two safety guards

Frontend has **two** floors that are never lowered for speed:

- `frontend-accessibility` — a11y is a safety guard, not a nice-to-have (semantic HTML, focus, labels/alt, keyboard). It uses a Do/Don't structure (a quality floor), distinct from the security guard's numbered failure-mode format.
- `frontend-security` — AI-generated web code is fast but frequently vulnerable, and the client bundle is public.
  This guard auto-loads when you touch web source · config · env · middleware · route handlers and catches the most
  common vulnerable patterns.

The other 10 skills — architecture, data, structure, API contract, figma-to-code, design system, i18n, testing, observability, and contract codegen — are the capability/quality rules; Figma-generated code is routed back through both guards before merge.

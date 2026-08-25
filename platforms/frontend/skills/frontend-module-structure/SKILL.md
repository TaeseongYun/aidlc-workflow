---
name: frontend-module-structure
description: Frontend module/structure rules (project layout, single styling system, code-splitting boundaries). app/components/features/lib layout with feature-scoped code kept inside its feature, one styling system only (design tokens / Tailwind / CSS modules — never a second), route-level code splitting as the default with heavy widgets lazy-loaded, one state library only, cross-feature reuse graduated into shared components/lib rather than feature→feature imports. Use when writing/reviewing project layout, adding a styling/state dependency, placing a file/feature, or setting code-split/lazy boundaries.
when_to_use: When laying out app/components/features/lib, placing a feature or shared code, choosing where to split/lazy-load, or judging whether a second styling/state library should be added. Also for "where does this file go", feature folder structure, code-splitting boundaries.
paths: **/next.config.*, **/vite.config.*, **/tailwind.config.*, **/tsconfig.json, **/package.json, **/app/**/layout.tsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-module-structure

Rules for project layout, styling-system singularity, and code-split
boundaries. The Module Baseline from `guidance.md` expanded to an enforceable
level. Project `ctx/` overrides this document. Deeper material (folder trees,
lazy-boundary samples) lives in [reference.md](./reference.md).

## Scope

- In scope: `app/components/features/lib` layout, where a file/feature belongs,
  single styling system, one state library, route-level code splitting and lazy
  boundaries.
- Covers: structural placement and the "no second system" rules.
- Doesn't cover: state modeling → [frontend-state-data], API client →
  [frontend-api-contract], a11y → [frontend-accessibility], security →
  [frontend-security].

## Core rules

Do:

- **Follow the project's existing layout.** Absent one, use:

  ```
  app/ (or pages/)   # routes, layouts, route-level data fetching
  components/         # shared presentational components
  features/<name>/    # feature-scoped components, hooks, api calls
  lib/                # api client, utilities
  styles/ or tokens   # design tokens, global styles
  ```

- **Feature-scoped code stays inside its feature.** Shared code graduates into
  `components/` (UI) or `lib/` (logic). Don't import another feature's internals.
- **One styling system.** Use the project's existing approach (design tokens,
  Tailwind, or CSS modules) — never introduce a second.
- **One state library.** Match what the project already has; don't add a second.
- **Route-level code splitting is the default**; heavy, below-the-fold, or
  conditionally-shown widgets load lazily (`next/dynamic`, `React.lazy`).
- **Colocate** a feature's components/hooks/api together; a barrel `index.ts`
  only if it earns its keep (avoid deep re-export chains that break tree-shaking).

Don't:

- Import `features/b/...` internals from `features/a`.
- Add a second styling system (e.g. styled-components next to Tailwind) or a
  second state library.
- Eagerly bundle a heavy widget (chart, editor, map) into the initial route load.
- Scaffold empty `features/<name>/{components,hooks,api}` folders "for later".
- Put a route-only component in shared `components/`, or a truly shared one deep
  inside one feature.

## Decision table

| Situation | Placement |
|---|---|
| Used by one feature only | inside that `features/<name>/` |
| Used by 2+ features, presentational | `components/` |
| Used by 2+ features, pure logic/util | `lib/` |
| Route entry + route-level fetch | `app/.../page.tsx` (or `pages/`) |
| Heavy / conditional widget | lazy-loaded at its use site |
| Design tokens / global styles | `styles/` or the tokens module (one system) |

## Refactor / red-flag signals

- Feature A importing feature B's internal files.
- A second styling system or state library appearing next to the existing one.
- A heavy widget eagerly imported into the initial bundle.
- Shared code copy-pasted across features instead of lifted into `components`/`lib`.
- Empty scaffolded feature subfolders with no files.
- Deep barrel re-export chains defeating tree-shaking.

## References

- Next.js project structure: https://nextjs.org/docs/app/building-your-application/routing/colocation
- Lazy loading (`next/dynamic`): https://nextjs.org/docs/app/building-your-application/optimizing/lazy-loading
- `React.lazy` / code splitting: https://react.dev/reference/react/lazy
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Folder trees, lazy-boundary samples: [`reference.md`](reference.md)

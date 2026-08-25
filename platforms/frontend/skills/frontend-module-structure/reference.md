# frontend-module-structure — Reference

Deep-dive for `SKILL.md`. Folder trees, cross-feature rules, code-split/lazy
boundaries. Decision criteria live in `SKILL.md`.

## 1. Feature-scoped layout (grow on demand)

```
app/
  (marketing)/            # route groups
  orders/
    page.tsx              # route entry + route-level data fetching
    layout.tsx
components/               # SHARED presentational components (used by 2+ features)
  button.tsx
features/
  orders/
    components/           # order-only components
    hooks/                # order-only hooks
    api.ts                # order endpoints (wraps the shared client) → frontend-api-contract
  checkout/
    components/
lib/
  api/client.ts           # the single API client module
  utils/
styles/                   # design tokens, global css (ONE styling system)
```

- Subfolders appear **only when they hold files**. Empty
  `features/x/{components,hooks}` scaffolding is over-engineering.

## 2. Cross-feature dependencies

```
✅ features/checkout → components/Button, lib/formatMoney   (via shared layers)
❌ features/checkout → features/orders/components/OrderRow    (feature→feature internals)
```

- When two features need the same thing, lift it to `components/` (UI) or `lib/`
  (logic). Don't reach into another feature's folder.

## 3. One styling system, one state library

```tsx
// ❌ Two styling systems in one codebase
import styled from 'styled-components';   // ...while the rest of the app is Tailwind
// ❌ Two state libraries
import { create } from 'zustand';         // ...next to an existing Redux store

// ✅ Match what the project already uses. Adding a second system is a design decision,
//    not a default — it fragments tokens, bundles, and mental model.
```

## 4. Code splitting / lazy boundaries

```tsx
// Route-level splitting is automatic in app/pages routers. Split heavy widgets explicitly:

// ✅ Heavy, below-the-fold, or conditional widget → lazy
const Chart = dynamic(() => import('@/features/analytics/components/Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // if it needs the browser only
});

// React (non-Next):
const Editor = React.lazy(() => import('./Editor'));
<Suspense fallback={<EditorSkeleton />}><Editor /></Suspense>
```

- Split on evidence (bundle analyzer / a genuinely heavy dep), not reflexively —
  over-splitting adds waterfalls and skeleton churn.

## 5. Structure review checklist

- [ ] Feature code stays in its feature; shared code in `components`/`lib`.
- [ ] No feature→feature internal imports.
- [ ] One styling system; one state library.
- [ ] Route-level splitting on; heavy/conditional widgets lazy-loaded.
- [ ] No empty scaffolded subfolders.
- [ ] Barrels only where they earn their keep (no tree-shake-breaking chains).

## Official references

- Next.js colocation & project organization: https://nextjs.org/docs/app/building-your-application/routing/colocation
- Next.js lazy loading: https://nextjs.org/docs/app/building-your-application/optimizing/lazy-loading
- React code splitting (`lazy`/`Suspense`): https://react.dev/reference/react/lazy
- Team baseline: [../../guidance.md](../../guidance.md)

# frontend-architecture — Reference

Deeper material for `SKILL.md`. Detailed layer responsibilities · container/
presentational · feature-slice samples. See `SKILL.md` for the rule summary and
decision criteria.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| Route/Page | data-fetch boundary, layout, route params | deep UI detail, business rules | composed page |
| Container | data + state wiring, loading/error/empty/content | presentational markup detail | props to children |
| Presentational | render props, emit callbacks | fetching, global store, router | UI + callbacks |
| Query layer / server state | remote data, caching, invalidation | UI-only state | typed data / status |
| Client state store | cross-cutting UI state | remote data mirroring | UI state |
| API client module | base URL, auth header, error normalization | business rules, per-component config | typed responses |

## 2. Container / presentational split

```tsx
// Container: wires data + state, renders the four fetch states, passes props down.
function OrderListContainer() {
  const { data, isLoading, isError } = useOrders();          // server state → frontend-state-data
  if (isLoading) return <Spinner />;
  if (isError) return <ErrorState onRetry={/* ... */} />;
  if (data.length === 0) return <EmptyState />;
  return <OrderList orders={data} onSelect={/* ... */} />;   // presentational
}

// Presentational: props in, callbacks out. No fetching, no store, no router.
function OrderList({ orders, onSelect }: { orders: Order[]; onSelect: (id: string) => void }) {
  return <ul>{orders.map(o => <OrderRow key={o.id} order={o} onClick={() => onSelect(o.id)} />)}</ul>;
}
```

## 3. Server state vs client state (never mirror)

```tsx
// ❌ Remote data copied into a global store and hand-synced
const useStore = create(set => ({ orders: [], setOrders: (o) => set({ orders: o }) }));
useEffect(() => { fetchOrders().then(useStore.getState().setOrders); }, []); // drift + duplicate cache

// ✅ Server state owns remote data (cache + invalidation); store holds UI-only state
const { data: orders } = useQuery({ queryKey: ['orders'], queryFn: api.getOrders });
const cartOpen = useUiStore(s => s.cartOpen);  // client state = UI-only
```

Detail → [frontend-state-data].

## 4. One API client module

```ts
// lib/api/client.ts — the single boundary. base URL, auth, error normalization.
export const api = {
  getOrders: () => request<Order[]>('/orders'),
  // ...
};
// ❌ components calling raw fetch('/api/orders') directly → scattered, untyped, no error norm
```

Detail → [frontend-api-contract].

## 5. Module baseline

Follow the project's existing layout. Absent one:

```
app/ (or pages/)   # routes, layouts, route-level data fetching
components/         # shared presentational components
features/<name>/    # feature-scoped components, hooks, api calls
lib/                # api client, utilities
styles/ or tokens   # design tokens, global styles
```

Detail → [frontend-module-structure].

## 6. Architecture review checklist

- [ ] Presentational components take props / emit callbacks (no fetch/store/router).
- [ ] Data fetching lives at route/container (RSC / query layer).
- [ ] Server state in the query layer; client state is UI-only; no mirroring.
- [ ] All backend calls go through one API client module (no scattered `fetch`).
- [ ] API responses typed (no `any` at the boundary).
- [ ] One state library, one styling system.
- [ ] Slices promoted on a real signal (no preemptive global store/abstraction).

## Official references

- React — thinking in components: https://react.dev/learn/thinking-in-react
- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Next.js App Router: https://nextjs.org/docs/app
- TanStack Query: https://tanstack.com/query/latest
- Team baseline: [../../guidance.md](../../guidance.md)

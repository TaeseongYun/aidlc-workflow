# rn-architecture — Reference

Deeper material for `SKILL.md`. Layer responsibilities · container/presentational
· native boundary · module baseline. See `SKILL.md` for the rule summary and
decision criteria. RN shares the web React boundaries — [frontend-architecture]
in `../../../frontend/skills/` is the web sibling.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| Screen (route) | data-fetch boundary, navigation, fetch states | deep UI detail, business rules | composed screen |
| Container | data + state wiring, loading/error/empty/content | presentational detail | props to children |
| Presentational | render props, emit callbacks | fetch, store, navigation, native modules | UI + callbacks |
| Server state (Query) | remote data, caching, invalidation | UI-only state | typed data / status |
| Client state store | session/UI state | remote-data mirroring | UI state |
| API client module | base URL, auth header, error normalization | business rules | typed responses |
| Native adapter | native module calls, `Platform.OS`, permission | business rules | domain result / typed failure |

## 2. Container / presentational split

```tsx
// Container: wires data + state, renders the four fetch states, passes props down.
function OrderListScreen() {
  const { data, isLoading, isError, refetch } = useOrders(); // server state → rn-state-data
  if (isLoading) return <Spinner />;
  if (isError) return <ErrorState onRetry={refetch} />;
  if (data.length === 0) return <EmptyState />;
  return <OrderList orders={data} onSelect={/* nav */} />;
}

// Presentational: props in, callbacks out. No fetch/store/navigation/native.
function OrderList({ orders, onSelect }: { orders: Order[]; onSelect: (id: string) => void }) {
  return <FlatList data={orders} keyExtractor={o => o.id} renderItem={/* ... */} />; // → rn-performance-ux
}
```

## 3. Native capability behind an adapter

```ts
// Interface: domain language. Feature code depends only on this.
export interface Biometrics { authenticate(): Promise<boolean>; }

// Adapter: the ONLY place the third-party native module is imported → rn-native-modules
import * as LocalAuth from 'expo-local-authentication';
export class BiometricsAdapter implements Biometrics {
  async authenticate() { return (await LocalAuth.authenticateAsync()).success; }
}
// ❌ a screen importing expo-local-authentication directly
```

## 4. Server vs client state (never mirror)

```tsx
// ❌ remote data into a store, hand-synced → drift + duplicate cache
// ✅ Query owns remote data; store holds UI/session only
const { data: orders } = useQuery({ queryKey: ['orders'], queryFn: api.getOrders });
const theme = useUiStore(s => s.theme); // client state
```

Detail → [rn-state-data].

## 5. Module baseline

Follow the project's layout. Absent one:

```
src/
  app/ or navigation/    # navigators, linking config, route params
  components/            # shared presentational components
  features/<name>/       # feature screens, hooks, api calls
  lib/                   # api client, storage adapter, native adapters
  theme/                 # tokens, styling setup
ios/ android/            # native projects — touched only via modules/config
```

- Feature code stays in its feature; shared code graduates to `components`/`lib`.
- One styling system, one state library → [rn-performance-ux].

## 6. Architecture review checklist

- [ ] Presentational components take props / emit callbacks (no fetch/store/nav/native).
- [ ] Data fetching at screen/container (TanStack Query); the four fetch states rendered.
- [ ] Server state in Query; client state UI/session only; no mirroring.
- [ ] All backend calls through one API client module; responses typed (no `any`).
- [ ] Native capability behind a project-owned adapter (no direct native import in features).
- [ ] Navigation params typed; deep links validated.
- [ ] One state library, one styling system.

## Official references

- React Native New Architecture: https://reactnative.dev/architecture/landing-page
- React Navigation: https://reactnavigation.org/docs/params/
- TanStack Query: https://tanstack.com/query/latest
- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Team baseline: [../../guidance.md](../../guidance.md)

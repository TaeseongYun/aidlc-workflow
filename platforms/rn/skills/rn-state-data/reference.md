# rn-state-data — Reference

Deep-dive for `SKILL.md`. Server/client-state separation, the four fetch states,
storage adapter, secure storage. Decision criteria live in `SKILL.md`.

## 1. Server state owns remote data (no mirroring)

```tsx
// ❌ Remote data into a store, synced by hand → two sources of truth, drift
const useStore = create(set => ({ orders: [], setOrders: (o) => set({ orders: o }) }));
useEffect(() => { api.getOrders().then(useStore.getState().setOrders); }, []);

// ✅ Query is the cache; components read it directly
const { data: orders, isLoading, isError } = useQuery({ queryKey: ['orders'], queryFn: api.getOrders });
```

## 2. Render all four fetch states

```tsx
function Profile({ id }: { id: string }) {
  const { data, isLoading, isError, refetch } = useQuery({ queryKey: ['user', id], queryFn: () => api.getUser(id) });
  if (isLoading) return <Spinner />;
  if (isError)   return <ErrorState onRetry={refetch} />;
  if (!data)     return <EmptyState />;
  return <ProfileCard user={data} />;
}
```

- Offline / poor-network is a designed state: configure query retry and show a
  user-visible offline state → [rn-navigation-lifecycle].

## 3. Persisted client state via a storage adapter

```ts
// One adapter behind the store — swappable (MMKV/AsyncStorage), mockable in tests.
import { MMKV } from 'react-native-mmkv';
const kv = new MMKV();
export const storage = {
  get: (k: string) => kv.getString(k),
  set: (k: string, v: string) => kv.set(k, v),
  remove: (k: string) => kv.delete(k),
};
// ❌ components calling AsyncStorage.getItem directly, scattered
```

## 4. Secrets go to secure storage — NOT AsyncStorage

```ts
// ❌ token in AsyncStorage/MMKV plaintext — readable on a compromised device
await AsyncStorage.setItem('token', jwt);

// ✅ Keychain/Keystore via a secure-storage module
import * as SecureStore from 'expo-secure-store';
await SecureStore.setItemAsync('token', jwt);          // hardware-backed keystore
const jwt2 = await SecureStore.getItemAsync('token');
// react-native-keychain: Keychain.setGenericPassword(user, token)
```

Detail → [rn-security].

## 5. Derive, don't store; model exclusive state as a union

```ts
// ❌ duplicated state + effect to sync
useEffect(() => { setFullName(`${first} ${last}`); }, [first, last]);
// ✅ const fullName = `${first} ${last}`;

// ❌ independent flags allow impossible combos
type S = { loading: boolean; data?: Order[]; error?: string };
// ✅ discriminated union / rely on Query's status
type S = { status: 'loading' } | { status: 'error'; error: string } | { status: 'ready'; data: Order[] };
```

## 6. Invalidate after mutations

```tsx
const qc = useQueryClient();
const { mutate } = useMutation({
  mutationFn: api.updateOrder,
  onSuccess: () => qc.invalidateQueries({ queryKey: ['orders'] }), // single source of truth
});
```

## 7. State review checklist

- [ ] Remote data in TanStack Query (no store mirror).
- [ ] loading / error / empty / content all rendered.
- [ ] Persisted client state via one storage adapter behind the store.
- [ ] Secrets/tokens in Keychain/Keystore, never AsyncStorage/MMKV plaintext.
- [ ] Derived values computed, not stored + synced.
- [ ] Exclusive states modeled as a union (or Query status).
- [ ] Mutations invalidate query keys; one state library only.

## Official references

- TanStack Query invalidation: https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Expo SecureStore: https://docs.expo.dev/versions/latest/sdk/securestore/
- react-native-keychain: https://github.com/oblador/react-native-keychain
- react-native-mmkv: https://github.com/mrousavy/react-native-mmkv
- Team baseline: [../../guidance.md](../../guidance.md)

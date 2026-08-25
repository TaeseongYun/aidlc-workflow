# frontend-state-data — Reference

Deep-dive for `SKILL.md`. Server/client-state separation, the four fetch states,
derived state, invalidation. Decision criteria live in `SKILL.md`.

## 1. Server state owns remote data (no mirroring)

```tsx
// ❌ Remote data into a store, synced by hand → two sources of truth, drift
const useStore = create(set => ({ user: null, setUser: (u) => set({ user: u }) }));
useEffect(() => { fetchUser(id).then(useStore.getState().setUser); }, [id]);

// ✅ Query layer is the cache; components read it directly
const { data: user, isLoading, isError } = useQuery({ queryKey: ['user', id], queryFn: () => api.getUser(id) });
```

## 2. Render all four fetch states

```tsx
function Profile({ id }: { id: string }) {
  const { data, isLoading, isError, refetch } = useQuery({ queryKey: ['user', id], queryFn: () => api.getUser(id) });
  if (isLoading) return <Spinner />;                 // loading
  if (isError)   return <ErrorState onRetry={refetch} />; // error
  if (!data)     return <EmptyState />;              // empty
  return <ProfileCard user={data} />;                // content
}
```

- Server Components equivalent: `await` the data in the RSC, wrap client subtrees
  in `<Suspense fallback>` for loading and an error boundary for errors.

## 3. Derive, don't store

```tsx
// ❌ Duplicated state + effect to keep it in sync
const [fullName, setFullName] = useState('');
useEffect(() => { setFullName(`${first} ${last}`); }, [first, last]);

// ✅ Derived during render (memoize only if measured hot)
const fullName = `${first} ${last}`;

// ❌ Seeding local state from props via effect
useEffect(() => { setSelected(defaultId); }, [defaultId]);
// ✅ Reset via key, or lift the source of truth up
<Panel key={defaultId} defaultId={defaultId} />
```

## 4. Invalidate after mutations (don't hand-sync)

```tsx
const qc = useQueryClient();
const { mutate } = useMutation({
  mutationFn: api.updateOrder,
  onSuccess: () => qc.invalidateQueries({ queryKey: ['orders'] }), // refetch, single source of truth
});
```

## 5. Model exclusive state as a union

```ts
// ❌ independent flags allow impossible combos
type S = { loading: boolean; data?: Order[]; error?: string };
// ✅ discriminated union — exactly one case
type S = { status: 'loading' } | { status: 'error'; error: string } | { status: 'ready'; data: Order[] };
```

- With a query library, `status`/`isLoading`/`isError` already encode this — use
  it instead of hand-rolling.

## 6. State review checklist

- [ ] Remote data in the query layer / server components (no store mirror).
- [ ] loading / error / empty / content all rendered.
- [ ] Derived values computed, not stored + synced.
- [ ] No `useEffect` that re-derives props/state or mirrors a query.
- [ ] Exclusive states modeled as a union, not independent flags.
- [ ] Mutations invalidate query keys (no manual cache patching unless deliberate).
- [ ] Exactly one state library in the project.

## Official references

- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Choosing the state structure: https://react.dev/learn/choosing-the-state-structure
- TanStack Query defaults & invalidation: https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
- Next.js data fetching: https://nextjs.org/docs/app/building-your-application/data-fetching
- Team baseline: [../../guidance.md](../../guidance.md)

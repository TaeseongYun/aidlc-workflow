# rn-navigation-lifecycle — Reference

Deep-dive for `SKILL.md`. Typed params, linking config + validation, AppState,
offline. Decision criteria live in `SKILL.md`.

## 1. Typed route params

```tsx
// One ParamList; screens read typed params — no any.
type RootParamList = {
  Home: undefined;
  Order: { id: string };
};
type Props = NativeStackScreenProps<RootParamList, 'Order'>;
function OrderScreen({ route }: Props) {
  const id = route.params.id; // typed
  // ...
}
// ❌ const id = (route.params as any).id;
```

## 2. Deep-link flow with validation (trust boundary)

```ts
// linking config maps URLs → screens
const linking = {
  prefixes: ['myapp://', 'https://app.example.com'],
  config: { screens: { Order: 'order/:id' } },
};

// Validate params before use — external URLs are untrusted
function parseOrderId(raw?: string): string | null {
  return raw && /^[0-9]+$/.test(raw) ? raw : null; // reject anything else
}
function OrderScreen({ route, navigation }: Props) {
  const id = parseOrderId(route.params?.id);
  if (!id) { navigation.replace('NotFound'); return null; } // defined fallback
  // ...
}
```

- Never honor an arbitrary redirect target from a link; allowlist internal routes
  → [rn-security].

## 3. AppState background/foreground

```tsx
useEffect(() => {
  const sub = AppState.addEventListener('change', (state) => {
    if (state === 'active') queryClient.invalidateQueries({ queryKey: ['feed'] }); // refresh stale on foreground
  });
  return () => sub.remove();
}, []);
```

## 4. Offline / poor network is a designed state

```tsx
const { data, isError, isPaused, refetch } = useQuery({
  queryKey: ['feed'], queryFn: api.getFeed, retry: 3,
});
if (isPaused) return <OfflineBanner />;          // no network — visible state, not a spinner
if (isError)  return <ErrorState onRetry={refetch} />;
```

## 5. Permission-denied path

```tsx
// designed UI state (permission requested in the adapter → rn-native-modules)
if (permission === 'denied') return <PermissionDeniedState onOpenSettings={openAppSettings} />;
```

## 6. Navigation review checklist

- [ ] Route params typed via a `ParamList` (no `any`).
- [ ] Deep links go URL → linking config → param validation → screen.
- [ ] Deep-link params validated; bad input → defined fallback; redirects allowlisted.
- [ ] `AppState` handled (refresh stale data / pause work on background).
- [ ] Offline/poor-network is a visible designed state (retry configured).
- [ ] Permission-denied is a designed UI state.
- [ ] Presentational components don't drive navigation.

## Official references

- React Navigation TypeScript: https://reactnavigation.org/docs/typescript/
- React Navigation deep linking: https://reactnavigation.org/docs/deep-linking/
- Expo Router: https://docs.expo.dev/router/introduction/
- AppState: https://reactnative.dev/docs/appstate
- TanStack Query — network mode: https://tanstack.com/query/latest/docs/framework/react/guides/network-mode
- Team baseline: [../../guidance.md](../../guidance.md)

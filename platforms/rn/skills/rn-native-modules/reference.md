# rn-native-modules — Reference

Deep-dive for `SKILL.md`. Adapter interface, platform divergence, permission
state, testing. Decision criteria live in `SKILL.md`.

## 1. Native capability behind an adapter interface

```ts
// lib/native/location.ts — interface in domain language
export interface LocationService {
  current(): Promise<{ lat: number; lng: number }>;
}

// The ONLY file importing the third-party native module
import * as Location from 'expo-location';
export class LocationServiceAdapter implements LocationService {
  async current() {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') throw new PermissionDenied('location'); // → typed, designed state
    const pos = await Location.getCurrentPositionAsync();
    return { lat: pos.coords.latitude, lng: pos.coords.longitude };
  }
}

// ❌ a screen importing 'expo-location' directly — native churn leaks everywhere
```

Under the New Architecture a native module is a **Turbo Module**: its API is typed by
**codegen** from a JS spec, resolved through `TurboModuleRegistry`, and called over **JSI**.
The adapter wraps that generated surface so feature code never touches
`TurboModuleRegistry`/JSI directly and New-Arch churn stays in one file.

## 2. Platform divergence at the boundary, not scattered

```tsx
// ❌ Platform.OS branches through business logic
function price(p: Product) {
  return Platform.OS === 'ios' ? p.iosPrice : p.androidPrice; // business logic forked by OS
}

// ✅ small UI tweak: Platform.select at the component
const shadow = Platform.select({ ios: styles.iosShadow, android: styles.androidElevation });

// ✅ bigger divergence: separate files resolved by the bundler
//   Button.ios.tsx / Button.android.tsx  → import { Button } from './Button'
```

## 3. Permission-denied is a designed state

```tsx
// ✅ denied is a first-class UI state, not a toast
function CameraScreen() {
  const { status, request } = useCameraPermission();     // wraps the adapter
  if (status === 'undetermined') return <RequestPrompt onPress={request} />;
  if (status === 'denied') return <PermissionDeniedState onOpenSettings={openAppSettings} />;
  return <CameraView />;
}
```

## 4. New native dependency = real justification

```
Before adding a native module, check the ladder:
- Does a JS-only API already do it (fetch, Intl, crypto.getRandomValues via a polyfill)?
- Does an already-installed dep cover it?
- Is the perf/UX gain worth the upgrade + build + CI cost the native module adds?
Only then add it — and put it behind an adapter (§1).
```

## 5. Test against the adapter interface

```ts
// ✅ mock the adapter, not the native module — stable across native upgrades
const fakeLocation: LocationService = { current: async () => ({ lat: 1, lng: 2 }) };
render(<Nearby location={fakeLocation} />);
// ❌ jest.mock('expo-location', ...) in every test — brittle, duplicated
```

## 6. Native-module review checklist

- [ ] Third-party native module imported only inside its adapter.
- [ ] Feature code depends on the adapter interface, not the module.
- [ ] `Platform.OS` divergence in the adapter or `.ios/.android` files, not business logic.
- [ ] Each new native dep is justified (JS-only ruled out).
- [ ] Permission-denied is a designed UI state.
- [ ] Native errors mapped to typed results at the adapter.
- [ ] Tests mock the adapter interface.

## Official references

- Turbo Native Modules: https://reactnative.dev/docs/turbo-native-modules-introduction
- Platform-specific code: https://reactnative.dev/docs/platform-specific-code
- Expo permissions: https://docs.expo.dev/guides/permissions/
- Team baseline: [../../guidance.md](../../guidance.md)

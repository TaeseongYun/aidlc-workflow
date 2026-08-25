---
name: rn-state-data
description: React Native state and data rules (server state vs client state, fetch states, persisted & secure storage). Remote data lives in TanStack Query with caching + invalidation — never mirrored into a global store; client state covers UI/session only; the state decision table places each kind of state (local, screen/feature, remote, cross-cutting, persisted); the four fetch states (loading/error/empty/content) are always modeled and rendered; persisted client state goes through a storage adapter (MMKV/AsyncStorage) behind the store; secrets/tokens go to Keychain/Keystore via a secure-storage module — never AsyncStorage. Use when deciding where state lives, wiring TanStack Query, persisting state, or catching remote-in-store mirroring and secrets-in-AsyncStorage smells.
when_to_use: When choosing a state home, separating server vs client state, wiring a query, persisting client state, storing tokens, or catching smells like remote data mirrored into a store, secrets in AsyncStorage, or a second state library.
paths: **/hooks/**/*.ts, **/hooks/**/*.tsx, **/*use*.ts, **/*use*.tsx, **/store/**/*.ts, **/queries/**/*.ts, **/*.query.ts, **/lib/storage/**
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-state-data

Rules for where state lives, how remote data enters the app, and how state is
persisted. The State Decision Table and server/client-state items of
`guidance.md` expanded to an enforceable level. Project `ctx/` overrides this
document. Deeper material lives in [reference.md](./reference.md).

## Scope

- In scope: state-home decisions, server vs client state, fetch-state modeling,
  persisted state via a storage adapter, secure storage for secrets.
- Covers: TanStack Query, the state decision table, the four fetch states,
  avoiding remote-in-store, MMKV/AsyncStorage vs Keychain/Keystore.
- Doesn't cover: component boundaries → [rn-architecture], native adapters →
  [rn-native-modules], offline/AppState lifecycle → [rn-navigation-lifecycle],
  security-vuln detail → [rn-security].

## Core rules

Do:

- **Server state ≠ client state.** Remote data lives in TanStack Query (cache +
  invalidation). Client state is UI/session only.
- **Model the four fetch states — loading / error / empty / content — and render
  all four.** Don't skip empty/error.
- **Derive, don't store.** Values computable from existing state/props are
  computed, not duplicated + synced.
- **Persist client state through a storage adapter** (MMKV / AsyncStorage) behind
  the store — one place, mockable in tests.
- **Secrets/tokens go to Keychain/Keystore via a secure-storage module** (e.g.
  `react-native-keychain`, Expo SecureStore) — **never AsyncStorage/MMKV plain**
  → [rn-security].
- **Invalidate, don't hand-sync.** After a mutation, invalidate the affected
  query keys.
- Use the state library the project already has — do not add a second one.

Don't:

- Copy remote data into a global store and keep it in sync manually.
- Put tokens, credentials, or PII in AsyncStorage/MMKV as plaintext.
- Use `useEffect` to re-derive a value or mirror a query result into local state.
- Skip the empty or error state ("happy path only").
- Encode exclusive states as independent booleans/nullables (use a union).
- Reach for a store for state a single component / lifted `useState` owns.

## State decision table

| Situation | State home | API |
|---|---|---|
| One component's UI state | local | `useState`/`useReducer` |
| Shared within a screen/feature | lift up / context for stable values | props / context |
| Remote data | TanStack Query — **never** a global store | `useQuery` |
| Cross-cutting client state (session, theme) | the project's existing store | Zustand/Redux (one only) |
| Persisted client state | storage adapter (MMKV/AsyncStorage) behind the store | adapter |
| Secrets / tokens | secure-storage module → Keychain/Keystore | `SecureStore`/Keychain |

## Refactor / red-flag signals

- Remote data mirrored into a global store and manually kept in sync.
- Secrets or tokens in AsyncStorage/MMKV plaintext.
- `useEffect` chains re-deriving a query result or a derived value.
- Missing empty/error rendering; only loading + content handled.
- Independent booleans/nullables encoding one exclusive state.
- A second state-management library next to the existing one.

## References

- TanStack Query — invalidation & defaults: https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Expo SecureStore: https://docs.expo.dev/versions/latest/sdk/securestore/
- react-native-keychain: https://github.com/oblador/react-native-keychain
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Query samples, storage-adapter & secure-storage patterns: [`reference.md`](reference.md)

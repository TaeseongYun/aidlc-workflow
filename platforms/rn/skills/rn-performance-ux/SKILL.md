---
name: rn-performance-ux
description: React Native performance and UX rules (lists, animations, styling, accessibility). Lists use FlatList/FlashList with stable keys — never map inside a ScrollView for unbounded data, and keys are never derived from array index on reorderable data; animations/gestures use Reanimated worklets and the project's existing gesture setup — animation state is not driven through React renders; the project's single styling convention (StyleSheet, styled-components, or NativeWind) is followed — never a second one; accessibility is a safety guard — accessibilityRole/accessibilityLabel on interactive elements and touch targets ≥ 44pt. Use when building/reviewing lists, animations, styled components, or interactive elements, or catching ScrollView-map, index-key, render-driven-animation, or missing-a11y smells.
when_to_use: When building lists, animations/gestures, styled components, or interactive UI; or catching smells like unbounded map in ScrollView, index keys on reorderable data, animation state driven by React renders, a second styling system, or missing accessibility roles/labels/touch targets.
paths: **/*.tsx, **/*.jsx, **/components/**/*.tsx, **/*List*.tsx, **/theme/**
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-performance-ux — lists, animation, styling, a11y

Rules for RN rendering performance and UX quality. The list/animation/styling/
accessibility items of `guidance.md` expanded to an enforceable level.
Accessibility here is a **safety guard**, not trimmed for speed. Project `ctx/`
overrides this document, but the accessibility floor is not lowered. Deeper
material lives in [reference.md](./reference.md).

## Scope

- In scope: list virtualization + keys, Reanimated animations/gestures, single
  styling system, accessibility (roles/labels/touch targets).
- Covers: keeping scrolling/animation smooth and UI accessible.
- Doesn't cover: state/data → [rn-state-data], native modules →
  [rn-native-modules], navigation → [rn-navigation-lifecycle], security →
  [rn-security].

## Core rules

Do:

- **Virtualize lists.** Use `FlatList`/`FlashList` with a stable `keyExtractor`.
  For long/unbounded data, never `.map` inside a `ScrollView`.
- **Stable keys.** Key by a stable id, **never the array index** on reorderable/
  mutable data (breaks recycling and state).
- **Animate on the UI thread.** Use Reanimated worklets and the project's
  existing gesture setup; **don't drive animation state through React renders**
  (`setState` per frame).
- **One styling system.** Follow the project's convention (StyleSheet,
  styled-components, or NativeWind) — never introduce a second.
- **Accessibility is a safety guard** (not trimmed for speed): interactive
  elements have `accessibilityRole` + `accessibilityLabel`; touch targets are
  **≥ 44pt**; state changes are announced where needed.
- **Memoize list rows on evidence** (`React.memo`, stable callbacks) when a
  measured re-render problem exists — not speculatively.

Don't:

- `.map` a large/unbounded array inside a `ScrollView`.
- Use the array index as `key` on data that can reorder/insert/delete.
- Drive an animation by calling `setState` every frame.
- Add a second styling system alongside the existing one.
- Ship interactive elements with no role/label, or touch targets < 44pt.
- Sprinkle `React.memo`/`useCallback` everywhere without a measured problem.

## Decision table

| Symptom / need | Fix |
|---|---|
| Long/unbounded list | `FlatList`/`FlashList` (not `ScrollView` + `.map`) |
| List rows lose state / jump on reorder | stable id `keyExtractor`, not index |
| Janky animation/gesture | Reanimated worklet on the UI thread, not React renders |
| Row re-renders on every parent update | `React.memo` + stable callbacks (on evidence) |
| Styling a component | the project's single styling system |
| Interactive element | `accessibilityRole` + `accessibilityLabel`, ≥ 44pt target |
| Async status for a11y | announce via accessibility (e.g. `AccessibilityInfo`) |

## Refactor / red-flag signals

- Unbounded `.map` lists inside `ScrollView`.
- Keys derived from array index on reorderable data.
- Animation state driven through React renders (`setState` per frame).
- A second styling or component library alongside the existing one.
- Interactive elements without `accessibilityRole`/`accessibilityLabel`.
- Touch targets smaller than 44pt.
- Blanket `memo`/`useCallback` with no measured cause.

## References

- FlatList: https://reactnative.dev/docs/flatlist · Optimizing FlatList: https://reactnative.dev/docs/optimizing-flatlist-configuration
- FlashList: https://shopify.github.io/flash-list/
- Reanimated: https://docs.swmansion.com/react-native-reanimated/
- Accessibility: https://reactnative.dev/docs/accessibility
- Team baseline: [`../../guidance.md`](../../guidance.md)
- List/animation/a11y samples: [`reference.md`](reference.md)

---
name: rn-accessibility
description: React Native accessibility rules — a11y as a safety guard, not a nice-to-have. Tappable elements expose a role (accessibilityRole="button"/link), every actionable control has an accessibilityLabel, decorative content is hidden from the a11y tree (importantForAccessibility="no"), touch targets meet 44pt/48dp minimums (hitSlop), state (disabled/checked/selected/busy) is exposed via accessibilityState, font scaling is never disabled (allowFontScaling left true), color is paired with text/icon and meets WCAG AA contrast, focus moves into opened sheets/dialogs and is restored on close, related content is grouped so the screen reader reads a unit once, and Pressable is preferred over View+onPress. These are safety rules and are never trimmed for speed. Use when building or reviewing RN screens, components, navigation, or when catching bare-View-onPress, missing-label, hidden-state, or focus-management gaps.
when_to_use: When building or reviewing interactive RN components, forms, bottom sheets/modals, navigation, or when catching a11y smells like View+onPress as a button, unlabeled icon controls, state shown by color only, font scaling disabled, or missing focus management on overlays. Also for grouping/merging and platform-component-over-reinvention decisions.
paths: **/*.tsx, **/*.jsx, **/components/**/*.tsx, **/components/**/*.jsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (focus management,
screen-reader testing, grouping, Dynamic Type, bad→good snippets) lives in
[reference.md](./reference.md).

## Scope

- In scope: role/trait exposure, accessible names, decorative hiding, touch
  target size, state exposure, font scaling, color/contrast signaling, focus
  management, grouping, and preferring Pressable and platform controls over
  manual re-implementations.
- Covers: making interactive RN UI, forms, overlays, and navigation usable by
  TalkBack (Android) and VoiceOver (iOS).
- Doesn't cover: component/navigation architecture → [rn-architecture],
  data/state → [rn-state-data], security → [rn-security].

## Core rules (safety — not trimmed for speed)

Do:

- **Interactive elements expose a role.** A tappable is a `<Pressable
  accessibilityRole="button">` (or `"link"` for navigation). Never a bare
  `<View onPress>` — `Pressable` surfaces a role, focus behavior, and press
  feedback to assistive tech for free.
- **Every actionable control and meaningful image has an accessible name.**
  Provide `accessibilityLabel` when the visual text is absent or insufficient.
  Icon-only buttons always have a label; image-only touchables always have a label.
- **Decorative content is hidden from the a11y tree.** Set
  `importantForAccessibility="no"` (Android) or `accessible={false}` on
  purely decorative images and graphics so screen readers skip them.
- **Manage focus on overlays and navigation.** When a bottom sheet, modal, or
  alert opens, move focus into it with `AccessibilityInfo.setAccessibilityFocus`;
  restore it to the trigger on close. Announce async/live changes with
  `AccessibilityInfo.announceForAccessibility`.
- **Touch targets meet the platform minimum.** Visual hit area must be at least
  44×44 pt (iOS) / 48×48 dp (Android). Use `hitSlop` to expand the tappable
  area without changing the visual layout.
- **State is exposed, not implied.** `accessibilityState` carries
  `disabled`, `checked`, `selected`, `expanded`, `busy` — never convey state
  by color or visual position alone.
- **Font scaling is left on.** `allowFontScaling` defaults to `true` — never
  set it to `false`. Use flexible layouts (`flex`, percentage) that accommodate
  scaled text; avoid fixed heights on text containers.
- **Color is not the only signal.** Pair color with text, icon, or shape; meet
  WCAG AA contrast (4.5:1 for normal text, 3:1 for large text/UI components).

Don't:

- `<View onPress>` / `<TouchableOpacity>` without `accessibilityRole` acting as
  a button or link — use `<Pressable accessibilityRole="button/link">`.
- Ship an icon-only button, a meaningful image, or an actionable control with no
  `accessibilityLabel`.
- Open a modal or bottom sheet without moving focus in; let focus stay behind
  the overlay.
- Set `allowFontScaling={false}` or use fixed-pixel heights that clip scaled text.
- Expose state (selected, disabled, loading) by color or visual style only —
  always pair with `accessibilityState` and a non-color signal.
- Leave decorative images in the a11y tree — set `importantForAccessibility="no"`
  or `accessible={false}`.
- Render interactive elements smaller than 44×44 pt / 48×48 dp without `hitSlop`.
- Re-implement a control from scratch (e.g., custom Switch built from Views) when
  the platform `Switch` or a semantics-complete component exists — add a proper
  semantics layer if you must build custom.

## Decision table

| Need | Use (platform first) |
|---|---|
| Tappable action | `<Pressable accessibilityRole="button">` |
| Navigation tappable | `<Pressable accessibilityRole="link">` or framework `<Link>` |
| Toggle / switch | Platform `<Switch>` (role + state built in) |
| Checkbox | `accessibilityRole="checkbox"` + `accessibilityState={{ checked }}` |
| Expand/collapse | `accessibilityRole="button"` + `accessibilityState={{ expanded }}` |
| Icon-only button name | `accessibilityLabel="Close"` (no visible text) |
| Decorative image/graphic | `importantForAccessibility="no"` / `accessible={false}` |
| Expand tappable area | `hitSlop={{ top, right, bottom, left }}` |
| Async status / live region | `AccessibilityInfo.announceForAccessibility(message)` |
| Move focus programmatically | `AccessibilityInfo.setAccessibilityFocus(reactTag)` |
| Dynamic Type / font scale | Leave `allowFontScaling={true}` (default); use `flex` layouts |
| State (disabled/busy/selected) | `accessibilityState={{ disabled: true, busy: true, … }}` |
| Group related content | `accessible={true}` on the container + `accessibilityLabel` covering the group |

## Refactor / red-flag signals

- `<View onPress…>` or `<TouchableOpacity>` without `accessibilityRole`.
- Icon button, image button, or meaningful image with no `accessibilityLabel`.
- `allowFontScaling={false}` anywhere in a component file.
- Fixed pixel height on a text container (`style={{ height: 20 }}`).
- Modal/sheet open without `AccessibilityInfo.setAccessibilityFocus` call.
- State (selected/checked/disabled/loading) reflected only in color or opacity.
- Decorative image missing `importantForAccessibility="no"` / `accessible={false}`.
- Interactive element with no `hitSlop` whose visual size is below 44×44 pt.
- A custom-drawn control (Slider, Checkbox, Toggle) with no `accessibilityRole`,
  `accessibilityLabel`, or `accessibilityState`.

## References

- React Native Accessibility: https://reactnative.dev/docs/accessibility
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Apple Accessibility (VoiceOver, Dynamic Type): https://developer.apple.com/documentation/accessibility
- Android Accessibility (TalkBack): https://developer.android.com/guide/topics/ui/accessibility
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, screen-reader testing, grouping, Dynamic Type, snippets: [`reference.md`](reference.md)

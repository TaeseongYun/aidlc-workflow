---
name: android-accessibility
description: Android (Jetpack Compose) accessibility rules — a11y as a safety guard, not a nice-to-have. Interactive composables expose a role (Role.Button, Role.Checkbox), every actionable control has a contentDescription, decorative images are hidden from the a11y tree, touch targets meet 48dp minimum, state (selected/checked/disabled/expanded) is exposed via stateDescription, text scales with sp units and system font scale, color is not the only signal, focus order is logical and managed on dialogs/bottom sheets, related items are merged with mergeDescendants, and native Compose controls are preferred over hand-rolled semantics layers. These are safety rules and are never trimmed for speed. Use when building or reviewing Compose UI, dialogs/bottom sheets, icon buttons, custom-drawn controls, or when catching missing contentDescription, bare clickable containers, or lost focus gaps.
when_to_use: When building or reviewing Compose composables, dialogs, bottom sheets, custom controls, or navigation; when catching a11y smells like a clickable Box with no role, an icon-only button with no contentDescription, text using dp units, or state conveyed by color alone. Also for semantics-layer and TalkBack readiness decisions.
paths: "**/*.kt, **/ui/**/*.kt, **/*Screen.kt, **/components/**/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (TalkBack testing, focus
management, semantics merging, font scale, bad→good snippets) lives in
[reference.md](./reference.md).

## Scope

- In scope: Compose semantics (`Modifier.semantics`, `contentDescription`,
  `Role`, `stateDescription`, `LiveRegionMode`), touch target sizing, sp/font
  scale, color/contrast signaling, platform-over-custom defaults.
- Covers: making Compose UI, dialogs, bottom sheets, and custom controls
  usable by TalkBack and other assistive technology.
- Doesn't cover: component boundaries → [android-architecture], state
  management → [android-viewmodel-state], security → [android-security].

## Core rules (safety — not trimmed for speed)

Do:

- **Interactive composables expose a role.** A tappable `Box`/`Row`/`Column`
  must carry `Modifier.semantics { role = Role.Button }` (or use a native
  `Button`/`IconButton` that provides the role automatically). TalkBack
  announces "double-tap to activate" only when a role is present.
- **Prefer the platform control.** `Button`, `IconButton`, `Checkbox`,
  `Switch`, `RadioButton`, `DropdownMenu` from Material 3 over a hand-rolled
  composable. Native controls ship with the correct semantics layer; custom
  ones require explicit `Modifier.semantics { }` to match.
- **Every actionable control and meaningful image has a contentDescription.**
  Icon-only buttons and image composables that convey meaning must set
  `contentDescription` in `Modifier.semantics { }` (or via the `Image`
  parameter). Give the label in plain action language ("Add to cart", not
  "Shopping cart icon").
- **Decorative content is hidden from the a11y tree.** Set
  `contentDescription = null` on a purely decorative `Image`, or use
  `Modifier.semantics { hideFromAccessibility() }` /
  `Modifier.clearAndSetSemantics { }` on an illustrative container so
  TalkBack skips it entirely.
- **Expose state — not just visuals.** Use `stateDescription` in
  `Modifier.semantics { }` for custom controls; `selected`, `checked`,
  `disabled`, `expanded` for standard roles. Never rely on color or icon
  change alone.
- **Use sp units for all text; never disable font scaling.** `fontSize`
  values in `sp` scale with the user's system font-size preference.
  Never hard-code `dp` for text sizes or set `fontScale = 1f` to lock
  scaling. Verify composable layout at 200% font scale.
- **Touch targets are at least 48dp × 48dp.** Use
  `Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)` or wrap a small
  visual in a larger clickable area. `IconButton` from Material 3 meets
  this by default.
- **Color is not the only signal.** Pair color with text, icon, or shape;
  meet WCAG AA contrast (4.5:1 normal text, 3:1 large text / UI components).
  Error states must carry text or an icon label in addition to red color.
- **Manage focus into opened dialogs and bottom sheets; restore on close.**
  `AlertDialog` handles this automatically. Hand-rolled sheets must use
  `FocusRequester` to move TalkBack focus in on open and restore it on
  dismiss.
- **Announce async / live changes.** Wrap a status text in
  `Modifier.semantics { liveRegion = LiveRegionMode.Polite }` so TalkBack
  reads updates (saving, loading complete, error) without the user navigating
  to it.
- **Group related items; don't over-fragment.** Use `mergeDescendants = true`
  in `Modifier.semantics { }` on the parent so TalkBack reads a card or list
  row as one unit. Use `Modifier.clearAndSetSemantics { }` to replace
  auto-merged children with a single composed description.

Don't:

- Use a `Box`/`Row`/`Column` with `.clickable { }` and no
  `Modifier.semantics { role = Role.Button }` — TalkBack announces a generic
  container with no affordance.
- Ship an icon-only button (`IconButton` with only an icon child) without a
  `contentDescription` on the inner `Icon`.
- Leave a purely decorative `Image` or background illustration with a
  non-null `contentDescription` — TalkBack reads noise.
- Hard-code text sizes in `dp` or clamp `LocalDensity` to prevent font
  scaling.
- Make a touch target smaller than 48dp × 48dp without an expanded clickable
  area.
- Convey error/required/selected state by color or icon change alone —
  always pair with a text label or `stateDescription`.
- Open a dialog or bottom sheet without moving TalkBack focus into it.
- Fragment a card into many individual TalkBack stops when a single merged
  announcement is clearer.
- Re-implement a checkbox or toggle as a custom `Box` with a click handler
  instead of using `Checkbox`/`Switch` — the semantics layer is non-trivial
  to replicate correctly.

## Decision table

| Need | Use (platform first) |
|---|---|
| Tappable action | `Button` / `TextButton` / `FilledTonalButton` (Material 3) |
| Icon-only action | `IconButton` — set `contentDescription` on the inner `Icon` |
| Toggle (on/off) | `Switch` — exposes checked state automatically |
| Binary selection | `Checkbox` / `RadioButton` |
| Expandable section | `role = Role.Button` + `expanded` in semantics |
| Decorative image | `Image(contentDescription = null)` |
| Meaningful image | `Image(contentDescription = "…")` or `Modifier.semantics { contentDescription = "…" }` |
| Custom tappable card | `.clickable(onClickLabel = "Open order details") { }` + `Modifier.semantics { role = Role.Button }` |
| Async status text | `Modifier.semantics { liveRegion = LiveRegionMode.Polite }` |
| Focus into dialog | `AlertDialog` (automatic) or `FocusRequester` on open |
| Group card children | `Modifier.semantics(mergeDescendants = true) { }` on parent |
| Replace auto-merge | `Modifier.clearAndSetSemantics { contentDescription = "…" }` |
| Text that scales | `fontSize = 16.sp` — never `16.dp` |
| Small visual, large hit | `Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)` around clickable |

## Refactor / red-flag signals

- `.clickable { }` on a `Box`/`Row`/`Column` with no `role` in semantics.
- `IconButton` or image composable with no `contentDescription` on the `Icon`/`Image`.
- Decorative `Image` with a non-null `contentDescription`.
- Text `fontSize` in `dp` instead of `sp`.
- A touch target smaller than 48dp with no expanded clickable wrapper.
- Custom state (selected/expanded/disabled) shown by color or icon only — no
  `stateDescription` or semantic flag.
- A hand-rolled dialog/sheet that never calls `FocusRequester.requestFocus()`.
- A long card with many TalkBack stops that should be merged.
- A custom checkbox/toggle built from a `Box` + mutable state instead of
  `Checkbox`/`Switch`.
- `liveRegion` absent on a status region that updates asynchronously.

## References

- Compose accessibility: https://developer.android.com/jetpack/compose/accessibility
- Material Design accessibility: https://m3.material.io/foundations/overview/principles
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Android TalkBack: https://support.google.com/accessibility/android/answer/6006598
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, TalkBack testing, semantics merging, font scale, snippets: [`reference.md`](reference.md)

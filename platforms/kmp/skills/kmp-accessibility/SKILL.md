---
name: kmp-accessibility
description: KMP Compose Multiplatform accessibility rules — a11y as a safety guard, not a nice-to-have. Modifier.semantics exposes correct roles (Role.Button/Role.Image/invisibleToUser), every actionable composable and meaningful image has a contentDescription, decorative content is excluded (contentDescription=null / invisibleToUser=true), touch targets meet the 48dp minimum, state (selected/checked/disabled/expanded/progressBar) is exposed via Semantics not color alone, text scales with LocalDensity/SP units and never clips, color is paired with text/icon and meets WCAG AA contrast, focus order is logical and FocusRequester moves into opened dialogs/sheets and restores on close, related content is grouped with semantics(mergeDescendants=true) without over-merging, and native Material3 controls are preferred over hand-drawn custom composables. These are safety rules and are never trimmed for speed. Use when building or reviewing Compose Multiplatform composables, forms, dialogs/bottom sheets, navigation, or catching Semantics gaps.
when_to_use: When building or reviewing interactive Compose Multiplatform composables, forms, dialogs/bottom sheets, menus, or navigation; managing focus; or catching a11y smells like missing contentDescription, icon-only button with no semanticsLabel, touch target smaller than 48dp, state conveyed by color alone, or a custom-drawn control with no Semantics layer.
paths: "**/ui/**/*.kt, **/widgets/**/*.kt, **/*Screen.kt, **/*Composable*.kt, **/commonMain/**/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (patterns, focus management,
screen-reader testing, Semantics grouping) lives in [reference.md](./reference.md).

## Scope

- In scope: `Modifier.semantics`, touch target sizing, keyboard/focus operability,
  accessible names and roles, state exposure, font scaling via SP units, color/contrast
  signaling, `mergeDescendants` grouping, platform-over-reinvention defaults.
- Covers: making interactive Compose Multiplatform UI, forms, and dialogs usable by
  TalkBack (Android) and VoiceOver (iOS via Compose Multiplatform accessibility bridge).
- Doesn't cover: widget decomposition / layer boundaries →
  [kmp-architecture](../kmp-architecture/SKILL.md); state management patterns →
  [kmp-state-management](../kmp-state-management/SKILL.md); security →
  [kmp-security](../kmp-security/SKILL.md).

## Core rules (safety — not trimmed for speed)

Do:

- **Expose a role on every tappable.** Use `Modifier.semantics { role = Role.Button }`
  on custom tappable containers, or use Material3 `Button`/`TextButton`/`IconButton`
  which carry the button role automatically. A bare `Modifier.clickable` with no
  semantics is invisible to screen readers.
- **Name every actionable control and meaningful image.** Icon-only buttons need
  `Modifier.semantics { contentDescription = "Close dialog" }`. Images that convey
  meaning need `contentDescription = "Company logo"` on the `Image` composable.
- **Exclude decorative content from the a11y tree.** Purely decorative images and
  dividers use `contentDescription = null` or
  `Modifier.semantics { invisibleToUser() }` so screen readers skip them.
- **Meet the 48dp touch target minimum.** Use `Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)`
  as the floor. Expand small visual controls with padding or `minimumInteractiveComponentSize()`
  (Compose Material3). Do not ship 24dp icon-only tappables bare.
- **Expose state via Semantics.** Use `Modifier.semantics { stateDescription = … }`,
  `selected = isSelected`, `disabled()`, `expanded = isOpen`, `progressBarRangeInfo` — not
  color or visual indicator alone. Screen readers announce the state, not the color.
- **Use SP units for text.** Text sizes in `sp` (not `dp`) respects the system font-size
  preference. Do not clamp `LocalDensity` to suppress scaling.
- **Pair color with a secondary signal.** Error/success/warning states use text or icon
  in addition to color. Meet WCAG AA contrast (4.5:1 for body text, 3:1 for large/UI).
- **Manage focus on dialogs and sheets.** Open a dialog → the first focusable control
  receives focus via `FocusRequester.requestFocus()` in a `LaunchedEffect`. Close →
  restore focus to the triggering composable. Announce async live changes with
  `LocalAccessibilityManager.current.announce`.
- **Group related content with `mergeDescendants`.** Wrap a card's icon + label + sublabel
  in `Modifier.semantics(mergeDescendants = true) { }` so TalkBack reads one unit.
  Use `clearAndSetSemantics` on parts that are redundant after merging.
- **Prefer native Material3 controls.** `Checkbox`, `Switch`, `Slider`, `TextField`,
  `Button`, `RadioButton` carry correct roles and state semantics built-in. A
  custom-drawn control must add an explicit `Modifier.semantics { … }` layer with role,
  label, and state — no custom composable ships with a bare `Modifier.clickable`.

Don't:

- Use a bare `Modifier.clickable` as the only tappable layer — no role exposed to the a11y tree.
- Ship an icon-only button (e.g., a toolbar icon) with no `contentDescription` or
  `Modifier.semantics { contentDescription = "…" }`.
- Leave decorative `Image` composables in the a11y tree with `contentDescription` unset (defaults
  to null is correct) but without explicit intent — always be explicit.
- Ship touch targets smaller than 48dp without expanding the hit area via padding or
  `minimumInteractiveComponentSize()`.
- Convey checked/selected/disabled/expanded state by color or visual change alone with no
  corresponding Semantics property.
- Use `dp` for text sizes — always use `sp` so OS font-scale preference is respected.
- Signal error/required/status by color alone; red border with no text or icon.
- Open a hand-rolled dialog/sheet without moving focus in, or close without restoring focus
  to the trigger.
- Over-merge unrelated actions into one `mergeDescendants = true` group — a screen reader
  user cannot reach the individual actions.
- Reinvent a checkbox/toggle/slider with `Canvas.drawArc`/`drawPath` and ship it with no
  `Modifier.semantics` layer.

## Decision table

| Need | Use (platform first) |
|---|---|
| Tappable action | `Button` / `TextButton` / `OutlinedButton` (Material3) |
| Icon-only action | `IconButton` (add `contentDescription` on the `Icon`) |
| Toggle | `Switch` / `Checkbox` / `RadioButton` (state built-in) |
| Text input | `TextField` with `label = { Text(…) }` |
| Meaningful image | `Image(…, contentDescription = "description")` |
| Decorative image | `Image(…, contentDescription = null)` or `Modifier.semantics { invisibleToUser() }` |
| Custom tappable | `Modifier.semantics { role = Role.Button; contentDescription = "…" }.clickable { … }` |
| Group card/row as one unit | `Modifier.semantics(mergeDescendants = true) { }` on the container |
| Suppress subtree | `Modifier.semantics { invisibleToUser() }` or `clearAndSetSemantics { }` |
| Announce async change | `LocalAccessibilityManager` / `SemanticsProperties.liveRegion` |
| Expose checked/expanded/busy state | `Modifier.semantics { selected = v; expanded = v; stateDescription = "…" }` |
| Focus into opened overlay | `FocusRequester().requestFocus()` inside `LaunchedEffect(Unit)` |
| Minimum touch target | `Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp)` or `minimumInteractiveComponentSize()` |
| Scale-aware text | Use `sp` units; do not clamp `LocalDensity` or `LocalFontScale` |

## Refactor / red-flag signals

- `Modifier.clickable` with `onClick` and no `Modifier.semantics { role = Role.Button }`.
- `Icon` composable inside a tappable with no `contentDescription` on the `Icon` or enclosing
  `Modifier.semantics { contentDescription = "…" }`.
- `Image(…)` with no explicit `contentDescription` decision (null for decorative, string for meaningful).
- A tappable composable visually smaller than 48×48dp with no padding expansion.
- Semantics node with no `contentDescription`, no `role`, and no `stateDescription`.
- Color-only feedback: red border, green fill, greyed composable — with no corresponding
  Semantics state property.
- Text size in `dp` instead of `sp`.
- A dialog/sheet opened by `LaunchedEffect`/`Dialog` call with no `FocusRequester` usage
  for hand-rolled overlays.
- `Modifier.semantics(mergeDescendants = true)` wrapping an entire screen or a composable
  that contains multiple independent actions (over-merge).
- `Canvas` drawing interactive controls (custom toggle, slider) with no `Modifier.semantics`
  wrapper.

## References

- Compose accessibility: https://developer.android.com/develop/ui/compose/accessibility
- `Modifier.semantics` API: https://developer.android.com/reference/kotlin/androidx/compose/ui/semantics/package-summary
- `Role` enum: https://developer.android.com/reference/kotlin/androidx/compose/ui/semantics/Role
- `SemanticsProperties`: https://developer.android.com/reference/kotlin/androidx/compose/ui/semantics/SemanticsProperties
- Compose Multiplatform a11y: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-accessibility.html
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, screen-reader testing, grouping/merging, SP scaling samples: [`reference.md`](reference.md)

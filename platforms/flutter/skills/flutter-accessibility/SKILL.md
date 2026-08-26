---
name: flutter-accessibility
description: Flutter accessibility rules — a11y as a safety guard, not a nice-to-have. Semantics widgets expose correct roles (button/image/hidden), every actionable control and meaningful image has a label, decorative content is excluded from the a11y tree, touch targets meet the 48dp Material minimum (kMinInteractiveDimension), state (selected/checked/disabled/expanded/busy) is exposed via Semantics not color alone, text scales with MediaQuery.textScaler and never clips, color is paired with text/icon and meets WCAG AA contrast, focus order is logical and FocusNode moves into opened dialogs/sheets and restores on close, related content is grouped with MergeSemantics without over-merging, and native Flutter controls are preferred over hand-drawn custom widgets. These are safety rules and are never trimmed for speed. Use when building or reviewing Flutter widgets, forms, dialogs/bottom sheets, navigation, or catching Semantics gaps.
when_to_use: When building or reviewing interactive Flutter widgets, forms, dialogs/bottom sheets, menus, or navigation; managing focus; or catching a11y smells like missing Semantics label, icon-only button with no semanticsLabel, touch target smaller than 48dp, state conveyed by color alone, or a custom-drawn control with no Semantics layer.
paths: "**/lib/**/*.dart, **/widgets/**/*.dart, **/*.dart"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (patterns, focus management,
screen-reader testing, Semantics grouping) lives in [reference.md](./reference.md).

## Scope

- In scope: Semantics widgets, touch target sizing, keyboard/focus operability,
  accessible names and roles, state exposure, font scaling, color/contrast
  signaling, MergeSemantics/ExcludeSemantics grouping, platform-over-reinvention
  defaults.
- Covers: making interactive Flutter UI, forms, and dialogs usable by TalkBack
  (Android) and VoiceOver (iOS).
- Doesn't cover: widget decomposition / layer boundaries →
  [flutter-architecture], state management patterns →
  [flutter-state-management], security → [flutter-security].

## Core rules (safety — not trimmed for speed)

Do:

- **Expose a role on every tappable.** Wrap custom tappable containers in
  `Semantics(button: true, ...)` or use `ElevatedButton`/`TextButton`/
  `IconButton` which carry the button trait automatically. A bare `GestureDetector`
  with no Semantics is invisible to screen readers.
- **Name every actionable control and meaningful image.** Icon-only buttons need
  `Tooltip` (which contributes a label) or explicit
  `Semantics(label: 'Close dialog')`. Images that convey meaning need
  `Image(semanticsLabel: 'Company logo')`.
- **Exclude decorative content from the a11y tree.** Purely decorative images and
  dividers use `ExcludeSemantics(child: ...)` or
  `Image(excludeFromSemantics: true)` so screen readers skip them.
- **Meet the 48dp touch target minimum.** Use `kMinInteractiveDimension` (48.0) as
  the floor. Expand small visual controls with `SizedBox`/`ConstrainedBox` or
  wrap in a `GestureDetector` with a larger `HitTestBehavior` area; do not ship
  24dp icon-only tappables bare.
- **Expose state via Semantics.** Use `Semantics(checked: isChecked)`,
  `Semantics(selected: isSelected)`, `Semantics(enabled: !isDisabled)`,
  `Semantics(expanded: isOpen)`, `Semantics(value: label)` — not color or visual
  indicator alone. Screen readers announce the state, not the color.
- **Respect `MediaQuery.textScaler`.** Scale text sizes with it; do not clamp to a
  fixed pixel value that clips at large font scales. Use `Text` with its default
  scaling behavior; avoid hard-coded `textScaleFactor: 1.0`.
- **Pair color with a secondary signal.** Error/success/warning states use text or
  icon in addition to color. Meet WCAG AA contrast (4.5:1 for body text, 3:1 for
  large/UI).
- **Manage focus on dialogs and sheets.** Open a dialog → the first focusable
  control receives focus (Flutter's `AlertDialog`/`showModalBottomSheet` does this
  automatically; hand-rolled overlays must use `FocusNode.requestFocus()`). Close
  → restore focus to the triggering widget. Announce async live changes with
  `SemanticsService.announce`.
- **Group related content with `MergeSemantics`.** Wrap a card's icon + label +
  sublabel in `MergeSemantics` so TalkBack reads one unit. Use `ExcludeSemantics`
  on the parts that are redundant after merging.
- **Prefer native Flutter controls.** `Checkbox`, `Switch`, `Slider`, `TextField`,
  `ElevatedButton`, `Radio` carry correct roles and state semantics built-in. A
  custom-drawn control must add an explicit `Semantics(...)` layer with role,
  label, and state — no custom widget ships with a bare `GestureDetector`.

Don't:

- Use a bare `GestureDetector` or `InkWell` as the only tappable layer — no role
  exposed to the a11y tree.
- Ship an icon-only button (e.g., a toolbar icon) with no `semanticsLabel`,
  `Tooltip`, or `Semantics(label: ...)`.
- Leave decorative `Image` widgets in the a11y tree with no
  `excludeFromSemantics: true` / `ExcludeSemantics`.
- Ship touch targets smaller than `kMinInteractiveDimension` (48dp) without
  expanding the hit area.
- Convey checked/selected/disabled/expanded state by color or visual change alone
  with no corresponding `Semantics` property.
- Set a fixed `textScaleFactor` or clamp `MediaQuery.textScaler` to suppress OS
  font scaling.
- Signal error/required/status by color alone; red border with no text or icon.
- Open a hand-rolled dialog/sheet without moving focus in, or close without
  restoring focus to the trigger.
- Over-merge unrelated actions into one `MergeSemantics` group — a screen reader
  user cannot reach the individual actions.
- Reinvent a checkbox/toggle/slider with `GestureDetector` + `CustomPaint` and
  ship it with no `Semantics` layer.

## Decision table

| Need | Use (platform first) |
|---|---|
| Tappable action | `ElevatedButton` / `TextButton` / `OutlinedButton` |
| Icon-only action | `IconButton` (add `tooltip:` for the accessible name) |
| Toggle | `Switch` / `Checkbox` / `Radio` (state built-in) |
| Text input | `TextField` with `decoration: InputDecoration(labelText: ...)` |
| Meaningful image | `Image(semanticsLabel: 'description')` |
| Decorative image | `Image(excludeFromSemantics: true)` or `ExcludeSemantics` |
| Custom tappable | `Semantics(button: true, label: '...', child: GestureDetector(...))` |
| Group card/row as one unit | `MergeSemantics(child: Row(...))` |
| Suppress subtree | `ExcludeSemantics(child: ...)` |
| Announce async change | `SemanticsService.announce('Saved', TextDirection.ltr)` |
| Expose checked/expanded/busy state | `Semantics(checked: v)` / `expanded` / `liveRegion: true` |
| Focus into opened overlay | `FocusNode` + `requestFocus()` in `WidgetsBinding.instance.addPostFrameCallback` |
| Minimum touch target | `SizedBox(width: kMinInteractiveDimension, height: kMinInteractiveDimension, child: ...)` |
| Scale-aware text | `MediaQuery.textScalerOf(context)` — do not override to 1.0 |

## Refactor / red-flag signals

- `GestureDetector` with `onTap` and no wrapping `Semantics(button: true)`.
- Icon widget inside a tappable with no `Semantics(label: ...)`, `Tooltip`, or
  `semanticsLabel` on the surrounding widget.
- `Image(...)` with no `semanticsLabel` and no `excludeFromSemantics: true`.
- A `SizedBox` or `Container` tap target visually smaller than 48×48dp.
- `Semantics` node with `hidden: false` but no `label` and no `button`/`image` flag.
- Color-only feedback: red border, green fill, greyed widget — with no
  corresponding `Semantics` state property.
- `textScaleFactor: 1.0` passed anywhere, or `MediaQuery` overridden to suppress scaling.
- A `showDialog` / `showModalBottomSheet` call followed by no `FocusNode` usage
  in the dialog content for hand-rolled dialogs.
- `MergeSemantics` wrapping an entire screen or a card that contains multiple
  independent actions (over-merge).
- `CustomPainter` or `CustomPaint` rendering interactive controls with no
  `Semantics` wrapper.

## References

- Flutter accessibility docs: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility
- `Semantics` widget API: https://api.flutter.dev/flutter/widgets/Semantics-class.html
- `MergeSemantics` / `ExcludeSemantics`: https://api.flutter.dev/flutter/widgets/MergeSemantics-class.html
- `SemanticsService.announce`: https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html
- `kMinInteractiveDimension`: https://api.flutter.dev/flutter/material/kMinInteractiveDimension-constant.html
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, screen-reader testing, grouping/merging, textScaler samples: [`reference.md`](reference.md)

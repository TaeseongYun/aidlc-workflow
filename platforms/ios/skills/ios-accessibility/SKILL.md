---
name: ios-accessibility
description: iOS/SwiftUI accessibility rules — a11y as a safety guard, not a nice-to-have. Interactive controls expose roles/traits (accessibilityAddTraits(.isButton)), every actionable element has an accessibilityLabel, decorative content is hidden (accessibilityHidden(true)), touch targets are at least 44pt, dynamic state is exposed via accessibilityValue/accessibilityAddTraits(.isSelected), Dynamic Type is supported via .font(.body)/ScaledMetric, color is paired with text/icon, focus is managed into sheets/alerts and restored on dismiss (via @AccessibilityFocusState), related content is grouped with accessibilityElement(children:), and native SwiftUI controls are preferred over reinvented custom-drawn ones. These are safety rules and are never trimmed for speed. Use when building or reviewing SwiftUI views, custom controls, forms, sheets/alerts, or catching missing labels, bare tappable containers, or broken Dynamic Type.
when_to_use: When building or reviewing SwiftUI views, custom interactive controls, forms, modals/sheets, or navigation; managing VoiceOver focus; or catching a11y smells like unlabeled icon buttons, tap-gesture-only containers without traits, missing accessibilityHidden on decorative images, fixed font sizes, or broken focus flow.
paths: **/*.swift, **/Views/**/*.swift, **/Components/**/*.swift
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (focus management,
VoiceOver testing, grouping patterns) lives in [reference.md](./reference.md).

## Scope

- In scope: SwiftUI accessibility modifiers, VoiceOver operability, labels/traits,
  focus management, Dynamic Type support, color/contrast signaling, native-control-over-reinvention defaults.
- Covers: making interactive views, forms, sheets, and custom controls usable by
  VoiceOver, Switch Control, and assistive tech.
- Doesn't cover: component decomposition → [ios-architecture], state and async →
  [ios-state-concurrency], security → [ios-security].

## Core rules (safety — not trimmed for speed)

Do:

- **Expose role/trait on every interactive element.** A tappable view without a
  native interactive ancestor gets `.accessibilityAddTraits(.isButton)` (or
  `.isLink`, `.isHeader`, etc.). Native SwiftUI `Button`, `Toggle`, `Picker`,
  `NavigationLink` carry their traits automatically — prefer them.
- **Every actionable control and meaningful image has an accessible name.**
  Icon-only buttons get `.accessibilityLabel("Close")`. Images carrying meaning
  get a label; decorative images get `.accessibilityHidden(true)`.
- **Decorative content is hidden from the a11y tree.**
  Background shapes, dividers, and illustrative images that carry no
  information get `.accessibilityHidden(true)` so VoiceOver skips them.
- **Touch targets are at least 44×44pt.**
  When the visual element is smaller, expand the hit area with
  `.contentShape(Rectangle())` and a frame padding, or use
  `.accessibilityFrame(CGRect(...))` to extend the logical target.
- **State is exposed to assistive tech — not just visually.**
  Selected/checked/disabled/loading state is declared via
  `.accessibilityAddTraits(.isSelected)`, `.accessibilityValue("On")`,
  `.disabled(true)`, or `.accessibilityAddTraits(.updatesFrequently)`.
  Never rely on color or animation alone.
- **Support Dynamic Type.** Use semantic text styles (`.font(.body)`,
  `.font(.headline)`) or `@ScaledMetric` for custom sizes. Never lock a text
  view to a fixed point size that clips at accessibility scale.
- **Color is not the only signal.** Pair color with text, icon, or shape.
  Meet WCAG AA contrast (4.5:1 normal text, 3:1 large). Error, required, and
  status states carry a textual or iconic cue alongside color.
- **Manage focus into sheets, alerts, and custom overlays.**
  Use `@AccessibilityFocusState` to move VoiceOver focus into a newly presented
  element and restore it when the element is dismissed.
- **Group related content so VoiceOver reads it as one unit.**
  Use `.accessibilityElement(children: .combine)` to merge a label+value pair.
  Use `.accessibilityElement(children: .contain)` when internal actions must
  remain reachable. Never fragment a logical unit across multiple unrelated
  focus stops.
- **Prefer native SwiftUI controls over custom-drawn equivalents.**
  `Button`, `Toggle`, `Slider`, `Picker`, `Menu` carry their semantics for free.
  A fully custom-drawn control must add an explicit semantics layer via
  `.accessibilityElement` + `.accessibilityLabel` + `.accessibilityAddTraits`.

Don't:

- Use a plain `Text` or `Image` with `.onTapGesture` as a button without adding
  `.accessibilityAddTraits(.isButton)` and a label — it is invisible to VoiceOver.
- Ship an icon-only button with no `.accessibilityLabel`.
- Leave decorative background images and dividers in the a11y tree.
- Use a fixed `.font(.system(size: 14))` on body text that cannot scale.
- Convey error/required/selection state by color or animation alone.
- Present a sheet or alert and leave VoiceOver focus stranded on the element
  that triggered it, forcing users to swipe through the full UI to reach the modal content.
- Over-merge: `.accessibilityElement(children: .combine)` on a container that
  contains independent actions (the actions become unreachable).
- Re-implement a control that SwiftUI already provides natively (custom toggle
  drawn from scratch, custom segmented picker from `HStack + Buttons`) without
  adding a complete semantics layer.

## Decision table

| Need | Use (platform first) |
|---|---|
| Tappable action | `Button` — traits included automatically |
| Toggle / checkbox | `Toggle` — role and state included |
| Selection from list | `Picker` or `List` with `selection:` |
| Icon-only button name | `.accessibilityLabel("…")` |
| Decorative image/shape | `.accessibilityHidden(true)` |
| Merge label + value into one stop | `.accessibilityElement(children: .combine)` |
| Keep child actions reachable in a group | `.accessibilityElement(children: .contain)` |
| Expose selected/checked state | `.accessibilityAddTraits(.isSelected)` / `.accessibilityValue(…)` |
| Expose loading / live-updating | `.accessibilityAddTraits(.updatesFrequently)` |
| Move VoiceOver focus into a sheet | `@AccessibilityFocusState` + `.accessibilityFocused($state)` |
| Expand a small tap target | `.contentShape(Rectangle())` + frame padding |
| Scale custom numeric sizes | `@ScaledMetric var size: CGFloat = 16` |
| Async status announcement | `UIAccessibility.post(notification: .announcement, argument: "…")` |

## Refactor / red-flag signals

- `.onTapGesture` on `Text`, `Image`, or `ZStack` with no `.accessibilityAddTraits(.isButton)`.
- Icon-only `Button` or image with no `.accessibilityLabel`.
- Decorative `Image` or `Color`/`Shape` with no `.accessibilityHidden(true)`.
- `.font(.system(size: N))` on body text — Dynamic Type cannot scale it.
- Error or selection state shown only through color change.
- Sheet/alert presented with no `@AccessibilityFocusState` focus move.
- `.accessibilityElement(children: .combine)` wrapping a container that has
  independent `Button` children (actions become unreachable).
- A custom-drawn control with no `.accessibilityLabel`, `.accessibilityAddTraits`,
  or `.accessibilityElement` modifiers at all.
- Tap target frame visually smaller than 44×44pt without a `.contentShape` expansion.

## References

- Apple Accessibility (SwiftUI): https://developer.apple.com/documentation/accessibility
- Human Interface Guidelines — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, VoiceOver testing, grouping/Dynamic Type snippets: [`reference.md`](reference.md)

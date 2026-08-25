---
name: frontend-accessibility
description: Frontend accessibility rules — a11y as a safety guard, not a nice-to-have. Interactive elements are real buttons/links (not divs with onClick), images have alt text, form fields have labels, focus is managed on dialogs and route changes, keyboard operation works, color is not the only signal, and the platform is preferred over a library (semantic HTML, native input types, CSS before a JS dependency). These are safety rules and are never trimmed for speed. Use when building/reviewing interactive UI, forms, dialogs/modals, navigation, or when catching div-onClick, missing-label, missing-alt, or focus-trap gaps.
when_to_use: When building or reviewing interactive elements, forms, dialogs/modals, menus, or navigation; managing focus; or catching a11y smells like div-with-onClick, unlabeled fields, missing alt, or lost focus on route change. Also for semantic HTML / platform-over-library decisions.
paths: **/*.tsx, **/*.jsx, **/components/**/*.tsx, **/components/**/*.jsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-accessibility — a11y safety guard

Accessibility is a **safety guard**, not a nice-to-have. The a11y items of
`guidance.md` expanded to enforceable rules. These are safety rules and are
**never trimmed for speed**. Project `ctx/` overrides this document, but the
accessibility floor is not lowered. Deeper material (patterns, focus management,
ARIA) lives in [reference.md](./reference.md).

## Scope

- In scope: semantic elements, keyboard operability, labels/alt, focus
  management, color/contrast signaling, platform-over-library defaults.
- Covers: making interactive UI, forms, and dialogs usable by keyboard and
  assistive tech.
- Doesn't cover: component boundaries → [frontend-architecture], data/state →
  [frontend-state-data], security → [frontend-security].

## Core rules (safety — not trimmed for speed)

Do:

- **Interactive elements are real controls.** A clickable is a `<button>`; a
  navigation is an `<a href>`. Never a `<div onClick>` — real controls give
  keyboard operability, focus, and role for free.
- **Prefer the platform over a library.** Semantic HTML, native input types
  (`<input type="date">`, `<dialog>`, `<details>`), and CSS (flex/grid, `:has`,
  transitions) before a JS dependency.
- **Every image has `alt`** (empty `alt=""` for decorative). **Every form field
  has a label** (`<label htmlFor>` or `aria-label`), tied to the control.
- **Manage focus.** Move focus into an opened dialog, trap it while open, restore
  it on close; move focus to the heading/main on route change. Don't strand
  keyboard/screen-reader users.
- **Keyboard works.** All interactions are reachable and operable by keyboard;
  visible focus styles are not removed (`:focus-visible`).
- **Color is not the only signal.** Pair color with text/icon; meet contrast
  (WCAG AA).

Don't:

- `<div onClick>` / `<span onClick>` as a button; add `role="button"` hacks
  instead of using a `<button>`.
- Ship an unlabeled input, an icon-only button with no accessible name, or an
  image without `alt`.
- Open a modal without moving/trapping focus, or change routes without resetting focus.
- `outline: none` with no visible focus replacement.
- Reach for a JS component where a native element + CSS does it.
- Convey required/error/status by color alone.

## Decision table

| Need | Use (platform first) |
|---|---|
| Clickable action | `<button type="button">` |
| Navigation | `<a href>` (framework `<Link>`) |
| Date / number / email input | native `<input type=...>` |
| Disclosure / accordion | `<details>/<summary>` |
| Modal dialog | `<dialog>` or a focus-managed component |
| Field label | `<label htmlFor>` (or `aria-label` when no visible label) |
| Icon-only button name | `aria-label` |
| Status / error signal | text/icon **plus** color, `aria-live` for async |

## Refactor / red-flag signals

- `<div>`/`<span>` with `onClick` used as a control.
- Inputs without associated labels; icon buttons with no accessible name.
- Images missing `alt`.
- Dialogs/menus with no focus management; route changes that lose focus.
- `outline: none` without a `:focus-visible` replacement.
- A JS library doing what a semantic element + CSS would.
- Required/error state shown by color only.

## References

- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- ARIA Authoring Practices (patterns): https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN accessibility: https://developer.mozilla.org/docs/Web/Accessibility
- React accessibility: https://react.dev/reference/react-dom/components#accessibility
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Focus management, ARIA patterns, testing-by-role samples: [`reference.md`](reference.md)

---
name: frontend-design-system
description: Frontend (web) design-system consistency guard — reuse existing design tokens and
  components instead of reinventing them, and detect/block the off-system code AI commonly
  produces (hardcoded colors, magic spacing/size, ad-hoc typography, reinvented components,
  off-scale variants, inline styles bypassing the theme, dark-mode/theme breaks, duplicated
  icons/assets, ad-hoc radius/elevation, primitive-instead-of-semantic tokens). The enforcement
  pair to frontend-figma-to-code. Auto-loads when writing or reviewing UI, themes, or tokens.
when_to_use: When building or reviewing UI, wiring themes/tokens, reviewing Figma-derived
  components, or on requests like "does this match the design system", "use the tokens",
  "design consistency review".
paths: "**/tokens.json, **/*.tokens.json, **/design-tokens/**, **/theme/**, **/tailwind.config.*,
  **/*.tsx, **/components/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# frontend-design-system — design-system consistency guard

AI-generated UI — especially output from `frontend-figma-to-code` — **reinvents the design
system instead of reusing it**: it hardcodes hex colors and magic spacing numbers, builds a fifth
bespoke `Button` when one already exists, and emits values that break in dark mode. The result is
drift: the same brand blue in six slightly-different shades, spacing that ignores the scale,
typography off the type ramp. This skill is a **guard** (detect/block off-system code) plus
**generation guidance** (reuse existing tokens + components first). It is the enforcement layer
that makes `frontend-figma-to-code` safe to ship: generated UI must pass THIS skill before merge.
Project `ctx/` overrides this document, but the design-system floor is never lowered.

## Scope

- Targets: UI components (`**/*.tsx`), theme/token files (`**/tokens.json`, `**/*.tokens.json`,
  `**/design-tokens/**`, `**/theme/**`, `**/tailwind.config.*`), component library usage
  (`**/components/**`).
- What it does: **detect off-system patterns → propose in-system replacements** for each failure
  mode below.
- Delegate: generating Figma-derived UI → [frontend-figma-to-code]; accessibility semantics →
  [frontend-accessibility]; injectable/XSS risk in rendered content → [frontend-security];
  module layout of the component library → [frontend-module-structure].
- Scope note: this skill governs **visual consistency** — color, spacing, type, components,
  assets, radius, elevation, and token tier. It does not govern behaviour, data flow, or routing.

## Mode A — Reuse (generation guidance)

**Before writing any UI, locate the system first.**

1. **Find the token source.** Look for `tokens.json` / `*.tokens.json` / `design-tokens/`
   at the repo root or under `src/`. This is the DTCG token file that `frontend-figma-to-code`
   outputs. Inspect it to understand what color, dimension, and typography tokens exist.

2. **Find the component library.** Grep for the installed UI library
   (`shadcn/ui`, `@radix-ui`, `@mui/material`, or the project's own `src/components/ui/`).
   Check `package.json` and `components/`. Map the new screen to existing components FIRST
   — do not build a new `Button`, `Card`, `Modal`, or `Input` if one exists.

3. **Prefer semantic tokens over primitives.** Inside component code, reach for semantic CSS
   variables (`--color-primary`, `--color-background`, `--color-foreground`) or Tailwind semantic
   utilities (`bg-primary`, `text-foreground`) rather than palette primitives (`blue-500`,
   `gray-900`). Semantic tokens survive re-theming and dark-mode switches; primitives silently
   break them.

4. **Extend in ONE place.** If a genuinely new design need arises (a one-off accent, a new text
   style), add ONE token to `tokens.json` / the Tailwind theme and reference it — never inline
   the literal in the component. A single token addition is reviewed once; a literal scattered
   across ten files is never fully caught.

5. **The calibration knob.** A new design need = a token/component addition, reviewed once. An
   inline literal = drift that accumulates. When in doubt, add the token and note it for the
   design-system owner.

Code examples in [reference.md](./reference.md) (Mode A section).

## Mode B — Guard (block off-system code)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in
[reference.md](./reference.md). These rules must not be relaxed.

### 1. Hardcoded color

- **Rule**: color values in component code must always come from a design token or theme utility.
  Never use raw hex, `rgb()`, or named CSS colors in a component.
- **Common AI failure**: extracting a hex directly from the Figma inspect panel and pasting it
  inline (`color: '#3B82F6'`, `className="text-[#3B82F6]"`). The color works today and breaks
  in dark mode or on the next rebrand.
- **red-flag**: `#` hex literals, `rgb(`/`rgba(` in JSX style props or Tailwind arbitrary values;
  `Color(0xFF…)` or named CSS colors (`blue`, `white`) outside the token file itself.

### 2. Magic spacing / size

- **Rule**: padding, margin, gap, width, and height must use the spacing/size scale — Tailwind
  spacing utilities (`p-4`, `gap-3`, `w-full`) or the CSS variable spacing tokens. Raw pixel
  numbers in style props or Tailwind arbitrary values (`p-[13px]`) are off-system.
- **Common AI failure**: copying pixel values from Figma geometry (`padding: '13px'`,
  `gap: 7`, `className="p-[13px]"`) instead of snapping to the nearest scale step.
- **red-flag**: arbitrary Tailwind size values (`p-[…]`, `w-[…]`, `gap-[…]` with a raw number),
  inline `style={{ padding: '13px' }}`, numeric literal spacing props on design-system components.

### 3. Ad-hoc typography

- **Rule**: font family, size, weight, and line-height must come from the type scale — Tailwind
  typography utilities (`text-sm`, `font-semibold`, `leading-relaxed`) mapped from DTCG
  `typography` tokens, or a text-style component. Per-component overrides of font size/weight
  are off-system.
- **Common AI failure**: setting `fontSize: 15, fontWeight: 600` in a style prop, or composing
  Tailwind font utilities that are not part of the project's defined type ramp.
- **red-flag**: `fontSize:`/`fontWeight:`/`fontFamily:` in style props; Tailwind `text-[15px]`,
  `font-[600]` arbitrary values; `lineHeight:` set inline on a non-token value.

### 4. Reinvented component

- **Rule**: before building a component from scratch, search the installed component library
  (`shadcn/ui`, Radix, MUI, or the project's `src/components/ui/`). A raw `<button>`, bespoke
  modal, or hand-rolled `<input>` duplicating library components is off-system.
- **Common AI failure**: emitting `<button className="rounded bg-blue-500 px-4 py-2 text-white">`
  instead of `<Button variant="default">` from the project's component library.
- **red-flag**: raw `<button>`, `<input>`, `<select>`, `<dialog>` styled inline; a new
  `Card.tsx`/`Modal.tsx`/`Badge.tsx` in `components/` when the library already ships one.

### 5. Off-scale variant

- **Rule**: a near-duplicate of a token value that is not the token is worse than a hardcoded
  literal — it looks correct in review and silently diverges. Always use the exact token; if
  the exact value is not on the scale, add the token rather than using the closest approximate.
- **Common AI failure**: using `#3B83F7` (one digit off from brand `#3B82F6`), or `rounded-[6px]`
  when the radius token is `6px` but the Tailwind class is `rounded-md`. The value looks right
  in isolation; it drifts cumulatively.
- **red-flag**: hex literals that differ from documented brand colors by one or two digits;
  spacing/radius values that are within 1–2px of a scale step but are not the scale step.

### 6. Inline style bypassing theme

- **Rule**: `style={{}}` props and one-off `className` strings with raw values bypass the theme
  and break re-theming. Use Tailwind utilities mapped to token CSS variables, or the component's
  own variant/size API. If a style cannot be expressed without a `style` prop (e.g. dynamic
  width), bind it to a CSS variable token, not a literal.
- **Common AI failure**: `style={{ color: '#fff', backgroundColor: '#1d4ed8', padding: '12px 24px' }}`
  on a component that has a `variant` + `size` prop.
- **red-flag**: `style={{` on any element that a design-system component's props can cover;
  Tailwind `className` strings mixing utilities and arbitrary values; `sx={{ … }}` with literals
  (MUI).

### 7. Dark-mode / theme break

- **Rule**: every color used in a component must be a semantic (adaptive) token — a CSS custom
  property that resolves differently in light and dark mode, or a Tailwind utility backed by one.
  Hardcoded `white`/`black` backgrounds, `gray-900` text, or explicit `dark:` overrides on
  literal values break when the theme changes.
- **Common AI failure**: `className="bg-white text-gray-900"` with a `dark:bg-gray-900
  dark:text-white` override — this works for one light/dark pair but breaks for any custom theme.
  Use `bg-background text-foreground` (semantic) instead.
- **red-flag**: `bg-white`, `bg-black`, `text-white`, `text-black` in component JSX (outside the
  token/theme file); `dark:` prefixed overrides on non-semantic colors; `style={{ background: 'white' }}`.

### 8. Duplicated icon / asset

- **Rule**: before adding an SVG or image, check the project's icon set (Lucide, Heroicons,
  Radix Icons, or the internal icon component) and public asset directory. Inline `<svg>` paths
  and duplicate asset files are off-system.
- **Common AI failure**: pasting the full SVG path data inline (`<svg><path d="M3 4h18…"/></svg>`)
  for a chevron that `lucide-react` already ships, or adding `close.svg` to `/public` when
  `<X />` from the icon library exists.
- **red-flag**: inline `<svg>` with a `<path d="…">` literal; a new file in `/public/icons/` or
  `/assets/` matching a name likely in the icon library; duplicated `*.svg` in `components/`.

### 9. Ad-hoc radius / elevation / shadow

- **Rule**: corner radius, elevation (z-index), and shadow must use the design token. In Tailwind
  these are `rounded-sm/md/lg/xl/full` mapped from the token; hand-rolled `borderRadius: 7` or
  `box-shadow: 0 2px 4px rgba(0,0,0,0.1)` are off-system.
- **Common AI failure**: `className="rounded-[7px]"` instead of `rounded-md` (the token), or a
  `style={{ boxShadow: '0 2px 8px rgba(0,0,0,0.15)' }}` instead of `shadow-md` from the scale.
- **red-flag**: `borderRadius:` in style props; `rounded-[…]` with a raw pixel value; `boxShadow:`/
  `box-shadow:` literals; `elevation:` / `z-index:` literals not from the token map.

### 10. Primitive instead of semantic token

- **Rule**: palette primitives (`blue-500`, `--color-blue-500`, `colors.blue[500]`) must not
  appear inside component code. Components reference semantic tokens (`--color-primary`,
  `text-primary`, `bg-card`, `border-border`). Primitives belong only in the token definition
  file itself, where semantic tokens are wired to them.
- **Common AI failure**: `className="bg-blue-500 text-white"` in a `PrimaryButton` — works until
  the brand color changes. The correct form is `bg-primary text-primary-foreground`, which picks
  up any re-theme automatically.
- **red-flag**: Tailwind palette classes (`blue-500`, `gray-200`, `zinc-900`) in component JSX;
  `var(--color-blue-500)` in component CSS; CSS-in-JS accessing `theme.palette.blue[500]` directly.

## Design-system review checklist

For UI code that AI generated or was pasted in quickly, before merge:

- [ ] No hex/rgb/named-color literals in components — all colors via semantic token or Tailwind semantic utility.
- [ ] No raw px/number spacing in style props or Tailwind arbitrary values — all spacing on the scale.
- [ ] No per-component font-size/weight/family overrides — typography from the type-scale utilities.
- [ ] No hand-rolled Button/Card/Modal/Input — library component used if one exists.
- [ ] No near-duplicate of a token value that is not the token — exact token only.
- [ ] No `style={{}}` literals where a component variant/size prop or theme utility applies.
- [ ] No hardcoded light/dark colors — all adaptive colors from semantic CSS variables.
- [ ] No inline SVG paths or duplicate assets — icon library or existing asset used.
- [ ] No raw `borderRadius`/`boxShadow`/`elevation` values — token-backed utilities only.
- [ ] No palette primitives in component code — semantic token tier used throughout.

## Halt conditions

Halt (do not proceed, surface the issue) when:

- The codebase has no token file and no theme configuration — design-system enforcement is
  impossible without a source of truth. Output the halt block and ask the user to point to
  the token/theme file or confirm that no design system is in use.
- A requested new component would require inventing a new shadow/radius/color scale that
  does not exist — add the token first, then build.

```markdown
## Design-system guard — halted

Halt reason:
- (specific reason)

Action needed:
1. ...
```

On halt: do NOT propose a workaround that bypasses tokens. Output only the halt reason.

## References

- Generation counterpart: [frontend-figma-to-code](../frontend-figma-to-code/SKILL.md)
- Team baseline: [../../guidance.md](../../guidance.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent safety floors: [frontend-accessibility](../frontend-accessibility/SKILL.md), [frontend-security](../frontend-security/SKILL.md)
- Adjacent: [frontend-module-structure](../frontend-module-structure/SKILL.md)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Tailwind CSS theming: https://tailwindcss.com/docs/theme
- shadcn/ui theming (CSS variables): https://ui.shadcn.com/docs/theming
- Deep dive (bad→good code pairs, Mode A examples): [reference.md](./reference.md)

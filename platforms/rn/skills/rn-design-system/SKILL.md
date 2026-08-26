---
name: rn-design-system
description: React Native design-system consistency guard — reuse existing design tokens and
  components instead of reinventing them, and detect/block the off-system code AI commonly
  produces (hardcoded colors, magic spacing/size, ad-hoc typography, reinvented components,
  off-scale variants, inline styles bypassing the theme, dark-mode/theme breaks, duplicated
  icons/assets, ad-hoc radius/elevation, primitive-instead-of-semantic tokens). The
  enforcement pair to rn-figma-to-code. Auto-loads when writing or reviewing UI, themes,
  or tokens.
when_to_use: When building or reviewing RN UI, wiring themes/tokens, reviewing Figma-derived
  components, or on requests like "does this match the design system", "use the tokens",
  "design consistency review".
paths: "**/theme/**", "**/tokens.*", "**/design-system/**", "**/*.tsx", "**/components/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# rn-design-system — design-system consistency guard

AI codegen — especially output from [rn-figma-to-code](../rn-figma-to-code/SKILL.md) —
**reinvents the design system instead of reusing it**: it hardcodes hex colors and magic
spacing numbers, builds a fifth bespoke `Button` when one already exists, and emits values
that silently break in dark mode. The result is drift: the same brand blue in six
slightly-different shades, spacing that ignores the scale, typography off the type ramp.

This skill is both a **guard** (detect/block off-system code) and **generation guidance**
(reuse existing tokens + components). It is the **enforcement layer that makes
rn-figma-to-code safe to ship**: generated UI must pass THIS skill before merge.
Project `ctx/` overrides this document. Code examples live in [reference.md](./reference.md).

## Scope

- **Targets**: RN source (`.ts`/`.tsx`), theme/token modules (`theme/**`, `tokens.*`,
  `design-system/**`), and component library files.
- **What it does**: detect off-system code → propose on-system alternatives; guide
  new-screen generation to reuse existing tokens and components.
- **Delegate**: Figma-to-component generation → [rn-figma-to-code](../rn-figma-to-code/SKILL.md);
  a11y roles/labels → folded into [rn-figma-to-code](../rn-figma-to-code/SKILL.md);
  file/folder structure for the design system → [rn-architecture](../rn-architecture/SKILL.md).

## Mode A — Reuse (generation guidance)

Follow these steps **before writing any UI code**:

**1. Locate the token source and component library.**

```bash
# Find token/theme files
find . -type f \( -name "tokens.*" -o -name "*theme*" -o -path "*/design-system/*" \) | head -20
# Find existing components
find . -path "*/components/*" -name "*.tsx" | head -30
```

Read the theme object (e.g. `theme/index.ts` or `theme.ts`) to understand the token
shape before writing a single `StyleSheet` entry. Grep for the primitive and semantic
token names — know what exists.

**2. Map screen → existing tokens (semantic over primitive).**

For every color, size, spacing, or radius value the Figma frame specifies:
- Look up the **semantic token** first (`theme.colors.primary`, `theme.colors.surface`,
  `theme.space.md`) — semantic tokens survive re-theming; primitives (`theme.colors.blue500`)
  do not.
- If `@shopify/restyle` is in use, use `Box`/`Text` with theme-prop attributes
  (`backgroundColor="primary"`) rather than `StyleSheet` inline literals.
- If a token module is present (e.g. `tokens/spacing.ts`), import from it — never
  duplicate the value.

**3. Map screen → existing components.**

Search the component library before building anything new. A new `<Button>`, `<Card>`,
`<TextInput>`, or `<Modal>` that already exists in the library is dead code and drift.

```bash
grep -r "export.*Button\|export.*Card\|export.*Input\|export.*Modal" src/components/
```

If the existing component doesn't accept a needed prop, **add the prop to the existing
component** — don't fork it.

**4. Genuinely new need → ONE extension, reviewed once.**

A new design requirement that no existing token covers is a **token addition**, not an
inline literal. Add one entry to the theme (`theme.colors.warningSubtle`) and reference it
everywhere. An off-system inline is never acceptable as "just this once" — the calibration
knob is the theme, not `StyleSheet` literals.

```tsx
// ponytail: one new token beats ten inline literals
// Add to theme.ts:
colors: { ..., warningSubtle: '#FFF3CD' }
// Then reference:
backgroundColor: theme.colors.warningSubtle
```

## Mode B — Guard (10 failure modes)

Each rule: **rule → common AI failure → red-flag**. Code pairs in [reference.md](./reference.md).

### 1. Hardcoded color

- **Rule**: colors in RN components come from the theme object / `@shopify/restyle` theme
  prop / token module — never a raw hex, `rgb()`, or named color literal in a `StyleSheet`
  or inline style.
- **Common AI failure**: `color: '#3B82F6'`, `backgroundColor: 'rgba(0,0,0,0.5)'`,
  `tintColor: 'blue'` hard-set in component styles, Figma hex pasted directly.
- **red-flag**: hex literals (`#rrggbb`), `rgb(...)`/`rgba(...)` inline in component
  `StyleSheet` or inline `style` prop; named color strings (`'red'`, `'white'`,
  `'transparent'`) where a semantic token exists.

### 2. Magic spacing / size

- **Rule**: all spacing (padding, margin, gap, width, height) references the spacing scale
  from the theme (`theme.space.sm`, `theme.space.md`) or spacing token module. Raw numeric
  literals for spatial values belong only in the theme definition itself.
- **Common AI failure**: `padding: 13`, `marginHorizontal: 7`, `gap: 10`, `height: 48`
  scattered through component `StyleSheet` blocks.
- **red-flag**: numeric literals for padding/margin/gap/width/height inside component
  files; magic numbers that are close to but not on the spacing scale
  (e.g. `padding: 15` when the scale has `sm=8, md=16`).

### 3. Ad-hoc typography

- **Rule**: font size, weight, family, and line height are expressed as text-style tokens
  from the type scale (`theme.text.bodyM`, `theme.text.titleL`), not set per-component.
  Inline `fontSize`/`fontWeight`/`fontFamily` in a `StyleSheet` is off-system.
- **Common AI failure**: `fontSize: 15, fontWeight: '600', fontFamily: 'Inter-SemiBold'`
  duplicated across multiple components instead of spreading a text-style token.
- **red-flag**: `fontSize` / `fontWeight` / `fontFamily` / `lineHeight` set directly in a
  component `StyleSheet` (outside the theme/token definition files); per-component
  `fontFamily` strings.

### 4. Reinvented component

- **Rule**: if the design system ships a `Button`, `Card`, `TextInput`, `Modal`, `Badge`,
  `Avatar`, or `Divider`, use it — never re-implement from raw `<View>`/`<Text>`. One
  component library ([rn-architecture]); zero tolerated duplicates.
- **Common AI failure**: a new `export function PrimaryButton(...)` built from a styled
  `<TouchableOpacity>` + `<Text>` when `<Button>` already exists; a bespoke
  `<CardContainer>` wrapping `<View>` when `<Card>` is in the library.
- **red-flag**: a new primitive-shaped component (`StyleSheet` with `borderRadius`,
  `backgroundColor`, `paddingHorizontal`, `elevation`) in a non-library file;
  `TouchableOpacity`/`Pressable` wrapped in custom markup for a purpose an existing
  component already covers.

### 5. Off-scale variant

- **Rule**: color and size values must be token values, not near-duplicates of tokens.
  A value one step off the scale is still off-system regardless of how close it is.
- **Common AI failure**: `borderRadius: 7` when the scale has `sm=4, md=8`; `#3B83F7`
  vs brand `#3B82F6`; `padding: 14` when the scale has `sm=8, md=16`.
- **red-flag**: a numeric literal or hex color that is similar to but not equal to a
  token value; near-duplicate raw values appearing in multiple files (grep for them).

### 6. Inline style bypassing theme

- **Rule**: `style={{ ... }}` inline props with literal values bypass the theme entirely.
  Styles go in `StyleSheet.create` blocks that reference theme tokens; with
  `@shopify/restyle`, use `Box`/`Text` theme props. Inline style props are reserved for
  truly dynamic/computed values only (e.g. `style={{ opacity: animatedValue }}`).
- **Common AI failure**: `<View style={{ padding: 16, backgroundColor: '#fff', borderRadius: 8 }}>`,
  long inline `style` objects spread across JSX.
- **red-flag**: inline `style={{...}}` with static numeric or color literals; multiple
  style keys set inline in JSX rather than in a `StyleSheet`.

### 7. Dark-mode / theme break

- **Rule**: colors that must adapt to dark mode use semantic tokens resolved at runtime via
  `useColorScheme()` or `@shopify/restyle`'s theme variants — never a hardcoded light/dark
  literal. Light and dark palettes are defined in the theme (e.g. `lightTheme`/`darkTheme`
  variants), not in component `StyleSheet` blocks.
- **Common AI failure**: `backgroundColor: '#ffffff'` (breaks in dark mode);
  `color: 'black'` hardcoded; a separate `if (colorScheme === 'dark') style.bg = '#000'`
  patch next to a hardcoded light color.
- **red-flag**: `'white'`/`'black'`/`'#fff'`/`'#000'` in component styles; explicit
  `colorScheme === 'dark'` branches that substitute raw colors instead of switching theme;
  no `useColorScheme` / restyle `ThemeProvider` when the app supports dark mode.

### 8. Duplicated icon / asset

- **Rule**: icons come from the project's icon set (e.g. `react-native-vector-icons`,
  `react-native-svg` + an icon component, or a custom `<Icon>` wrapper). Inline SVG path
  data or re-added asset files for icons the set already contains are not acceptable.
- **Common AI failure**: a raw `<Svg><Path d="M5 12..." /></Svg>` block pasted inline for
  an icon the icon library already ships; a second copy of `logo.png` placed in a feature
  folder instead of using the shared asset.
- **red-flag**: `<Svg>` with raw `<Path d="...">` in a non-icon-library file; asset files
  (PNG/SVG) duplicated across feature directories; `require('../assets/close.png')` when a
  `<CloseIcon>` component already exists.

### 9. Ad-hoc radius / elevation / shadow

- **Rule**: border radius, elevation, and shadow values come from theme tokens
  (`theme.radius.md`, `theme.elevation.card`). One-off values produce inconsistent
  surfaces across the app.
- **Common AI failure**: `borderRadius: 7`, `elevation: 3`, hand-rolled
  `shadowColor`/`shadowOpacity`/`shadowOffset`/`shadowRadius` per-component instead of a
  shared shadow token or mixin.
- **red-flag**: `borderRadius` / `elevation` / `shadowColor` + `shadowOpacity` literal
  combos in component `StyleSheet` blocks (outside the theme definition); values that don't
  match any token in `theme.radius` or `theme.elevation`.

### 10. Primitive instead of semantic token

- **Rule**: component code references **semantic tokens** (`theme.colors.primary`,
  `theme.colors.surface`, `theme.colors.onSurface`), not palette primitives
  (`theme.colors.blue500`, `theme.palette.gray200`). Primitives belong only in the theme
  definition itself — where they are assigned to semantic names.
- **Common AI failure**: `color: theme.palette.gray700` in a `<Text>` style; importing
  `COLORS.blue500` directly in a screen component. Re-theming (e.g. white-labeling) then
  silently breaks because the primitive bypasses the semantic mapping.
- **red-flag**: palette/primitive token references (`blue500`, `gray200`, `COLORS.brand`)
  inside component or screen files; a direct import of a primitive color constant into a
  non-theme file.

## Review checklist

For RN UI that was AI-generated or Figma-derived, before merge:

- [ ] No raw hex/rgb/named-color literals in component `StyleSheet` or inline styles — all colors from theme tokens.
- [ ] No magic spacing numbers — all padding/margin/gap from the spacing scale.
- [ ] No per-component `fontSize`/`fontWeight`/`fontFamily` — all typography from text-style tokens.
- [ ] No re-implemented design-system components — existing `Button`/`Card`/`Input`/`Modal` used.
- [ ] No off-scale near-duplicate values — each value is exactly a token value.
- [ ] No static-literal inline `style={{...}}` objects — styles in `StyleSheet` referencing tokens.
- [ ] No hardcoded `'white'`/`'black'`/`'#fff'`/`'#000'` — semantic tokens + `useColorScheme`/restyle for dark mode.
- [ ] No inline SVG paths or duplicate asset files — icon set components used.
- [ ] No ad-hoc `borderRadius`/`elevation`/shadow combos — all from `theme.radius`/`theme.elevation`.
- [ ] No palette-primitive references in component code — semantic tokens only.

## Halt conditions

Halt and report (do NOT proceed to merge guidance) when:

- A component file contains 3 or more distinct hardcoded hex colors — the design token
  mapping is missing, not just one slip.
- An existing design-system component is being re-implemented from scratch — the
  reinvention must be reviewed and removed before further changes.
- Dark-mode support is claimed but no semantic tokens or `useColorScheme`/restyle theme
  variants are in use — the feature is broken by design.

```markdown
## Design-system guard halted

Halt reason:
- (specific violation)

Action required:
1. (what must be fixed before proceeding)
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code pairs (bad → good per rule): [reference.md](./reference.md)
- Generation counterpart (produces output this skill enforces): [rn-figma-to-code](../rn-figma-to-code/SKILL.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Adjacent: [rn-security](../rn-security/SKILL.md) (security floor), [rn-performance-ux](../rn-performance-ux/SKILL.md)
- `@shopify/restyle`: https://github.com/Shopify/restyle
- React Native StyleSheet: https://reactnative.dev/docs/stylesheet
- useColorScheme: https://reactnative.dev/docs/usecolorscheme

---
name: android-design-system
description: Android design-system consistency guard — reuse existing design tokens and
  composables instead of reinventing them, and detect/block the off-system code AI
  commonly produces (hardcoded colors, magic spacing/size, ad-hoc typography, reinvented
  components, off-scale variants, inline styles bypassing the theme, dark-mode/theme
  breaks, duplicated icons/assets, ad-hoc radius/elevation, primitive-instead-of-semantic
  tokens). The enforcement pair to android-figma-to-code. Auto-loads when writing or
  reviewing UI, themes, or tokens.
when_to_use: When building or reviewing UI, wiring themes/tokens, reviewing Figma-derived
  composables, or on requests like "does this match the design system", "use the tokens",
  "design consistency review".
paths: **/ui/theme/**, **/*Theme.kt, **/*Color.kt, **/*Type.kt, **/designsystem/**, **/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# android-design-system

AI codegen — especially the output of [android-figma-to-code](../android-figma-to-code/SKILL.md)
— **reinvents the design system instead of reusing it**: it hardcodes hex colors and
magic spacing numbers, builds a fifth bespoke `Button` when one already exists in
`core/designsystem`, and emits values that silently break in dark mode. The result is
drift: the same brand blue in six slightly-different shades, spacing that ignores the
scale, typography off the type ramp.

This skill is a **guard** (detect/block off-system code) plus **generation guidance**
(reuse existing tokens and composables). It is the enforcement layer that makes
`android-figma-to-code` safe to ship: generated UI must pass THIS skill before merge.
The rules here are **design-system rules** and must not be weakened or relaxed.

## Scope

- Applies to: Kotlin sources, `**/ui/theme/**`, `**/*Theme.kt`, `**/*Color.kt`,
  `**/*Type.kt`, `**/designsystem/**/*.kt`.
- Covers: `MaterialTheme` (`ColorScheme` / `Typography` / `Shapes`) + design tokens,
  reuse of existing composables, semantic-over-primitive token usage, dark-mode safety.
- Does NOT cover: generation pipeline → [android-figma-to-code]; accessibility attributes
  and content descriptions → [android-accessibility]; module placement of designsystem
  code → [android-module-structure]; architectural structure → [android-architecture];
  security surface of exported components → [android-security].
- A project's `ctx/` overrides this document.

## Mode A — Reuse (generation guidance)

When writing or reviewing new UI, locate existing tokens and composables **before**
writing a single line:

1. **Find the token source.** Grep `**/ui/theme/**` and `**/designsystem/**` for
   `Color.kt`, `Type.kt`, `Theme.kt`, `AppTokens`, `DesignTokens`, or similar. Read
   the `ColorScheme` values and `Typography` styles — these are your vocabulary.
2. **Find the composable library.** Glob `**/designsystem/**/*.kt` or
   `**/core/designsystem/**`. Identify existing buttons, cards, inputs, dialogs, chips,
   icons. If a composable exists, reference it — never rebuild it.
3. **Map semantic, not primitive.** Use `MaterialTheme.colorScheme.primary` not
   `AppTokens.brandBlue`. Use `MaterialTheme.typography.titleMedium` not
   `FontWeight(600)` + `16.sp`. Semantic tokens survive re-theming; primitives do not.
4. **Extend in ONE place.** A genuinely new design need (a new spacing step, a new
   semantic color role) is a token or variant addition in `core/designsystem`, reviewed
   once and reused everywhere — never an inline literal. Add the token, not the inline.
5. **Calibration knob.** If the design calls for a value that is close to an existing
   token but not exact, treat that as a design question: is this intentional? A variant
   of an existing token is almost always the right answer, not a one-off literal.

The invariant: **composable code references `MaterialTheme.colorScheme.*` /
`MaterialTheme.typography.*` / spacing tokens / designsystem composables — never raw
literals.**

## Mode B — Guard (10 failure modes)

Each rule uses: **rule → common AI failure → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded color

**Rule:** All colors in composables must come from `MaterialTheme.colorScheme.*` or a
named designsystem color token. Raw hex/rgb/Color literals are forbidden in component
code.

**Common AI failure:** Figma-to-code tools resolve the fill color to its hex value
and paste it directly: `Color(0xFF3366FF)` or `color = Color.Blue`. This breaks
theming and dark mode silently — the composable ignores the active `ColorScheme`
entirely.

**Red-flag:** `Color(0xFF...)` or `Color.Red/Blue/Black/White` inside a composable
body or modifier; any hex string in a composable argument.

---

### 2. Magic spacing/size

**Rule:** Padding, margin, gap, and size values must come from the spacing/size token
scale (`AppTokens.spaceMd`, `Dimens.paddingLarge`, etc.) or a named `dp` constant in
`core/designsystem`. Raw `dp` literals that are not token references are forbidden in
component code.

**Common AI failure:** The extractor reads the Figma node's numeric padding and emits
`Modifier.padding(13.dp)` or `Arrangement.spacedBy(13.dp)` — a magic number that
matches no token on the scale and breaks if the scale is updated.

**Red-flag:** `.padding(N.dp)` / `spacedBy(N.dp)` / `.size(N.dp)` / `.height(N.dp)`
where N is an arbitrary literal not defined in the token/dims file.

---

### 3. Ad-hoc typography

**Rule:** Text style (font family, size, weight, line-height, letter-spacing) must come
from `MaterialTheme.typography.*` or a designsystem `TextStyle` token. Per-component
inline font configuration is forbidden.

**Common AI failure:** The AI reads the Figma text node's resolved style and emits
`fontSize = 15.sp, fontWeight = FontWeight(600)` inline. This duplicates the type ramp
in a one-off, silently diverges when the font scale changes, and ignores `LocalTextStyle`
propagation.

**Red-flag:** `fontSize = N.sp` or `fontWeight = FontWeight(N)` set directly on `Text`
composable calls; inline `TextStyle(...)` construction inside a composable body.

---

### 4. Reinvented component

**Rule:** If `core/designsystem` already ships a composable (button, card, dialog,
input, chip, bottom sheet, scaffold), use it. Do not build a new one from raw
layout primitives.

**Common AI failure:** The AI sees a Figma button frame and generates a `Row` with
`Modifier.background(...).clickable { }` — a bespoke, untested shadow of the real
`PrimaryButton`. The result misses ripple, semantics, accessibility role, disabled
state, and any future designsystem update.

**Red-flag:** A `Row` / `Column` / `Box` with `.clickable` that visually reproduces
a designsystem control; a new `@Composable` function whose body duplicates the layout
of an existing designsystem composable.

---

### 5. Off-scale variant

**Rule:** Color and spacing values must match a token exactly. A value that is a
near-duplicate of a token but not the token — differing by 1-2 px or one hex digit —
is a bug, not a design choice.

**Common AI failure:** The AI copies a color from Figma that was slightly off in the
design file (`#3B83F7` instead of the brand `#3B82F6`) and it propagates silently.
Over time the codebase accumulates six slightly-different blues.

**Red-flag:** Two nearly identical literal values across files for what should be the
same token; a literal that is within ±2dp or ±1 hex digit of a known token value.

---

### 6. Inline style bypassing theme

**Rule:** Styling must go through `MaterialTheme` / the designsystem modifier extensions
/ token constants. One-off `Modifier` chains that hardcode visual properties inline
(color, shape, elevation) instead of reading from the theme are forbidden.

**Common AI failure:** The AI inlines `Modifier.background(Color(0xFFEEEEEE)).clip(RoundedCornerShape(8.dp))`
directly on a layout node rather than mapping to `MaterialTheme.colorScheme.surfaceVariant`
and `MaterialTheme.shapes.small`.

**Red-flag:** `Modifier.background(Color(...))` or `.clip(RoundedCornerShape(N.dp))`
inline in a composable body where a theme value exists; `Modifier.border(...)` with
literal color and width not from tokens.

---

### 7. Dark-mode / theme break

**Rule:** Every color reference must use a semantic `ColorScheme` role that the active
`MaterialTheme` resolves correctly for both light and dark modes. Hardcoded
light-or-dark colors that bypass the `ColorScheme` are forbidden.

**Common AI failure:** The AI emits `Color.White` for a background or `Color.Black`
for text. In dark mode the `MaterialTheme` switches `colorScheme` but the composable
ignores it — white-on-white or black-on-black. Alternatively, the AI builds a manual
`if (isSystemInDarkTheme()) Color.X else Color.Y` branch that duplicates the theme.

**Red-flag:** `Color.White` / `Color.Black` / `Color.LightGray` as direct arguments
in component code; a manual `isSystemInDarkTheme()` branch inside a composable that
picks a raw color rather than delegating to the `ColorScheme`.

---

### 8. Duplicated icon/asset

**Rule:** Icons and image assets that already exist in the designsystem icon set or
drawable resources must be referenced via `painterResource` / `ImageVector` / the
designsystem `Icon` composable. Do not inline raw vector paths or add a second copy
of an existing asset.

**Common AI failure:** The AI exports an SVG from Figma and reconstructs its path
data inline as an `androidx.compose.ui.graphics.Path` object, or adds a new
`ic_arrow.xml` when `R.drawable.ic_arrow_forward` already exists in the icon set.

**Red-flag:** Inline `Path` / `addPath` construction in a composable; a new drawable
XML whose icon already exists under another name; duplicate `ic_*.xml` or `ic_*.kt`
files with the same visual as an existing asset.

---

### 9. Ad-hoc radius / elevation / shadow

**Rule:** Corner radius, elevation, and shadow must come from `MaterialTheme.shapes.*`
(for radius) and `MaterialTheme.colorScheme.surfaceTint` / `Modifier.shadow` with
token-defined elevation values. One-off literal values are forbidden.

**Common AI failure:** The AI reads the Figma node's `cornerRadius: 7` and emits
`RoundedCornerShape(7.dp)` instead of mapping it to `MaterialTheme.shapes.small`
(typically `4.dp`) or `shapes.medium` (typically `12.dp`). Similarly, `Modifier.shadow(elevation = 3.dp)` appears with a raw value.

**Red-flag:** `RoundedCornerShape(N.dp)` inline where N does not correspond to a
named shapes token; `Modifier.shadow(elevation = N.dp)` with a literal not from
the elevation scale; hand-rolled `drawBehind { }` shadows.

---

### 10. Primitive instead of semantic token

**Rule:** Inside composable code, use semantic tokens (`MaterialTheme.colorScheme.primary`,
`MaterialTheme.colorScheme.onSurface`) — not palette primitives (`AppTokens.brandBlue`,
`Color(0xFF3366FF)`). Primitives belong only in the `ColorScheme` / theme definition
in `core/designsystem`; composables consume the semantic role.

**Common AI failure:** The AI uses `AppTokens.brandBlue` directly in a composable
because it is "correct" today. When the product re-themes (white-label, seasonal), the
composable silently uses the wrong color because it is wired to a primitive, not the
semantic role that the new theme remaps.

**Red-flag:** `AppTokens.*`, `DesignTokens.*`, or named palette constants used
directly inside composable bodies outside of `core/designsystem`; any color reference
that bypasses `MaterialTheme.colorScheme.*`.

---

## Halt conditions

Stop and report (do not continue) if:

- The codebase has no `MaterialTheme` wrapper at the app root — token references have
  no theme to resolve against. Report the missing `MaterialTheme` call and halt.
- Multiple competing theme definitions exist (two `AppTheme` composables or two
  `ColorScheme` objects) and it is unclear which is active. Report the conflict and halt.
- Requested to build a UI component that duplicates one already in `core/designsystem`
  without a stated reason. Report the existing composable and halt.

**Output on halt:**

```
## Design-system guard halted

Reason:
- <specific reason>

Action needed:
1. <what to resolve before proceeding>
```

Do not propose alternatives. Do not explain how to fix. Output the halt reason only.

## References

- Generation counterpart (enforce THIS skill on its output): [android-figma-to-code](../android-figma-to-code/SKILL.md)
- Team Android baseline: [../../guidance.md](../../guidance.md)
- Security floor: [android-security](../android-security/SKILL.md)
- Module structure for designsystem: [android-module-structure](../android-module-structure/SKILL.md)
- Code examples (bad → good per rule, Mode-A worked example): [reference.md](./reference.md)
- Material Design 3 color system: https://m3.material.io/styles/color/system/overview
- Material Design 3 type scale: https://m3.material.io/styles/typography/overview
- Jetpack Compose `MaterialTheme`: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary#MaterialTheme

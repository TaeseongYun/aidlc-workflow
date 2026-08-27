---
name: kmp-design-system
description: KMP Compose Multiplatform design-system consistency guard — reuse existing design tokens and composables instead of reinventing them, and detect/block the off-system code AI commonly produces (hardcoded colors, magic spacing/size, ad-hoc typography, reinvented composables, off-scale variants, inline styles bypassing MaterialTheme, dark-mode/theme breaks, duplicated icons/assets, ad-hoc radius/elevation, primitive-instead-of-semantic tokens). The enforcement pair to kmp-figma-to-code. Auto-loads when writing or reviewing UI, themes, or tokens.
when_to_use: When building or reviewing UI, wiring themes/tokens, reviewing Figma-derived composables, or on requests like "does this match the design system", "use the tokens", "design consistency review".
paths: "**/theme/**/*.kt, **/*Theme*.kt, **/design_system/**/*.kt, **/tokens/**/*.kt, **/ui/**/*.kt, **/widgets/**/*.kt, **/composeResources/**"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-design-system — design-system consistency guard

AI-generated Compose Multiplatform code — especially [kmp-figma-to-code](../kmp-figma-to-code/SKILL.md)
output — **reinvents the design system instead of reusing it**: it hardcodes hex colors and magic
dp numbers, builds a fifth bespoke `Button` composable when one already exists in the component
library, and emits values that silently break in dark mode. The result is drift: the same brand
blue in six slightly-different shades, spacing that ignores the scale, typography off the type
ramp. This skill is the **guard** (detect/block off-system code) plus **generation guidance**
(reuse existing tokens + composables). It is the enforcement layer that makes
[kmp-figma-to-code](../kmp-figma-to-code/SKILL.md) safe to ship: generated UI must pass
THIS skill before merge.

## Scope

- Targets: Kotlin source under `**/ui/**`, `**/theme/**`, `**/design_system/**`, `**/widgets/**`,
  `**/composeResources/**` — especially AI-generated or Figma-derived files.
- What it does: **detect off-system patterns → propose on-system alternatives** for each
  failure mode below.
- Delegate to adjacent skills: pixel-exact Figma translation → [kmp-figma-to-code](../kmp-figma-to-code/SKILL.md);
  accessibility semantics → [kmp-accessibility](../kmp-accessibility/SKILL.md);
  file/module placement → [kmp-module-structure](../kmp-module-structure/SKILL.md);
  security audit of generated code → [kmp-security](../kmp-security/SKILL.md).
- Reality: a Compose Multiplatform app inherits one `MaterialTheme` tree.
  **Anything that bypasses it creates a second truth** — theme switches, dark mode, and
  white-label variants all break silently.

## Mode A — Reuse (generation guidance)

Before writing any new composable or token value, orient yourself in the existing system:

### Step 1 — Locate the token source and component library

```bash
# Find MaterialTheme definition
grep -r "MaterialTheme\b" --include="*.kt" -l .

# Find ColorScheme
grep -r "colorScheme\b" --include="*.kt" -l . | head -5

# Find CompositionLocals (spacing, custom tokens)
grep -r "compositionLocalOf\|staticCompositionLocalOf\|ProvidableCompositionLocal" --include="*.kt" -l .

# Find the design_system composable library
ls */design_system/ 2>/dev/null || find . -type d -name "design_system" | head -5
```

Do this FIRST. Never write a new color or spacing literal before knowing what
`MaterialTheme` already provides.

### Step 2 — Map a new screen to existing tokens and composables

Read the token source, then map each design value to its semantic counterpart:

| Design need | KMP semantic token |
|---|---|
| Brand primary color | `MaterialTheme.colorScheme.primary` |
| On-primary text | `MaterialTheme.colorScheme.onPrimary` |
| Surface / card background | `MaterialTheme.colorScheme.surface` |
| Error state | `MaterialTheme.colorScheme.error` |
| Body text | `MaterialTheme.typography.bodyMedium` |
| Headline | `MaterialTheme.typography.headlineMedium` |
| Spacing unit | `LocalSpacing.current.md` (or your `CompositionLocal`) |

Prefer semantic entries (`primary`, `surface`, `onSurface`) over palette entries
(`blue500`). A screen built on semantic tokens re-themes and switches dark mode for free.

Map Figma instances to existing library composables before writing any new markup:

```bash
# Does a Button composable already exist?
grep -r "fun.*Button" --include="*.kt" . | grep "@Composable\|Composable" | head -10

# Does a Card composable already exist?
grep -r "fun.*Card" --include="*.kt" . | grep "@Composable\|Composable" | head -10
```

If it exists, reference it. Building ad-hoc `Box`/`Row` markup for what is a button
is the most common AI drift.

### Step 3 — Extend the system in ONE place

A genuinely new design need is a **token or composable addition reviewed once**,
not an inline literal used once. The calibration knob:

- New semantic color needed → add a `CompositionLocal<Color>` entry, not an inline `Color(0xFF…)`.
- New spacing value needed → add it to the spacing `CompositionLocal` data class, not `Modifier.padding(13.dp)`.
- New composable variant needed → add a parameter to the existing composable or a named overload,
  not a second composable with near-identical code.

```kotlin
// Add ONE CompositionLocal entry instead of inlining everywhere
data class AppColors(
    val highlight: Color,
)

val LocalAppColors = staticCompositionLocalOf { AppColors(highlight = Color.Unspecified) }

// Wire it in MaterialTheme call once; consume via LocalAppColors.current
MaterialTheme(colorScheme = colorScheme) {
    CompositionLocalProvider(
        LocalAppColors provides AppColors(highlight = Color(0xFFFFB703))
    ) {
        content()
    }
}
```

## Mode B — Guard (block off-system code)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded color

- **Rule**: no `Color(0xFF…)` literals in composable code. All colors come from
  `MaterialTheme.colorScheme.*` or a named `CompositionLocal`. New colors → extend via
  `CompositionLocal`, reviewed once.
- **Common AI failure**: Figma-to-code dumps `Color(0xFF3B82F6)` for every fill it reads.
  The next palette update or dark-mode switch leaves the composable stranded on the old value.
- **red-flag**: `Color(0xFF` appearing in composable files outside the theme layer;
  `Color.Blue` / `Color.Red` literals outside theme definitions; raw hex strings in `ui/`.

### 2. Magic spacing / size

- **Rule**: all padding, margin, gap, width, height that encodes a design-system spacing
  unit must come from the spacing `CompositionLocal` (e.g. `LocalSpacing.current.md`) or
  a named constant in the token file — not a bare dp number.
- **Common AI failure**: `Modifier.padding(13.dp)`, `Spacer(Modifier.height(24.dp))`,
  `Modifier.size(37.dp)` — numbers that match no token on the scale.
- **red-flag**: `.padding(` / `.height(` / `.width(` / `.size(` with a bare dp literal
  that has no named-constant alias.

### 3. Ad-hoc typography

- **Rule**: font size, weight, family, and line height come from
  `MaterialTheme.typography.*`. Never set `fontSize` / `fontWeight` / `fontFamily`
  inline in a `TextStyle` in composable code.
- **Common AI failure**: `TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold)` —
  a one-off that ignores the type scale and breaks when the type ramp changes.
- **red-flag**: `TextStyle(fontSize =` / `fontWeight = FontWeight.` in composable files
  outside the `Typography` definition in `*Theme.kt`.

### 4. Reinvented composable

- **Rule**: when the design system ships a composable (Button, Card, Modal, TextField,
  BottomSheet), use it. Never rebuild the same composable as ad-hoc `Box` /
  `Row` / `Modifier.clickable` markup.
- **Common AI failure**: Figma-to-code sees a `PrimaryButton` node and emits a
  `Box(modifier = Modifier.background(…).clickable { … }) { Text(…) }` instead of
  referencing `PrimaryButton(label = …, onClick = …)`.
- **red-flag**: a new `@Composable` in a feature file that replicates a composable already in
  the design_system module; a `Modifier.clickable` wrapping styled `Box` text where a
  Button composable exists.

### 5. Off-scale variant

- **Rule**: colors and sizes must be token values, not near-duplicates of tokens.
  `Color(0xFF3B83F7)` where the brand token resolves to `Color(0xFF3B82F6)` is drift.
- **Common AI failure**: Figma layers often have a blue that is one step off the palette.
  The extractor rounds; the AI does not always notice.
- **red-flag**: hex values in the codebase that are within a few digits of an existing token
  value but are not the token; spacing numbers that are one unit off a scale step (e.g. 13.dp
  instead of 12.dp or 16.dp).

### 6. Inline style bypassing theme

- **Rule**: do not pass a `TextStyle(…)` or `Modifier.background(color = …)` containing
  literals directly to a composable in feature code. All decoration/style comes from the
  theme or a named style constant.
- **Common AI failure**: `Text("Hello", style = TextStyle(color = Color.White, fontSize = 14.sp))` —
  the theme is bypassed entirely; the composable ignores dark mode and palette changes.
- **red-flag**: `style = TextStyle(` with literals in feature composables;
  `Modifier.background(Color(0xFF…))` outside the design_system layer.

### 7. Dark-mode / theme break

- **Rule**: colors must come from `ColorScheme` semantic entries or an adaptive
  `CompositionLocal`. Never hardcode light-mode values (`Color.White`, `Color.Black`,
  `Color(0xFFFFFFFF)`) as backgrounds or foregrounds — they produce invisible text or
  unreadable surfaces in dark mode.
- **Common AI failure**: `color = Color.White` for a card background, `Color.Black`
  for body text — passes in light mode, invisible in dark mode. No `darkColorScheme`
  wired.
- **red-flag**: `Color.White` / `Color.Black` in composable code outside theme definitions;
  a `MaterialTheme` with no dark companion; only a `lightColorScheme` defined with no
  `darkColorScheme`.

### 8. Duplicated icon / asset

- **Rule**: use the icon set the design system already ships (`Icons.*` from
  `material-icons-*`, or the project's custom icon set) instead of pasting a raw SVG
  path or adding a second copy of an existing asset.
- **Common AI failure**: Figma exports vector nodes as inline path data; AI copies them as
  `Canvas.drawPath` code instead of referencing the icon. Or it adds an SVG to
  `composeResources/` when `Icons.ArrowForward` already exists.
- **red-flag**: `drawPath(Path().apply { moveTo(…) })` reconstructing a UI icon;
  an SVG file that duplicates a named `Icons.*` glyph; `painterResource` used for
  an icon the system icon set already contains.

### 9. Ad-hoc radius / elevation / shadow

- **Rule**: corner radius, elevation, and shadow come from `MaterialTheme.shapes`,
  `CardDefaults`, or a named `CompositionLocal` token — not bare
  `RoundedCornerShape(7.dp)` or `elevation = 3.5.dp` literals.
- **Common AI failure**: every card and dialog gets its own `shape = RoundedCornerShape(12.dp)`
  or `elevation = 4.dp` literal — out of sync with `MaterialTheme.shapes` and impossible
  to update globally.
- **red-flag**: `RoundedCornerShape(` with a bare dp number in feature composables;
  `elevation =` with a literal dp value; `Shadow(blurRadius =` outside the theme layer.

### 10. Primitive instead of semantic token

- **Rule**: inside component and feature code, use semantic tokens
  (`colorScheme.primary`, `colorScheme.surface`, `typography.bodyMedium`) not
  palette primitives (`AppColors.Blue500`, `Color(0xFF60A5FA)`). Palette entries are
  defined once in the theme layer; they are never referenced directly from composable code.
- **Common AI failure**: importing `AppColors.Blue500` directly into a feature composable
  instead of `MaterialTheme.colorScheme.primary` — re-theming and white-labelling silently
  breaks because the palette entry doesn't follow theme switches.
- **red-flag**: a raw palette class reference (`AppColors.`, `Palette.`, `DesignTokens.blue`)
  inside feature composable code; `Color(0xFF…)` assigned directly to a composable property.

## Guard checklist

For Compose Multiplatform UI code that AI generated or was Figma-derived, before merge:

- [ ] No `Color(0xFF…)` / `Color.*` literals in feature composables — all colors from `MaterialTheme.colorScheme.*` or `CompositionLocal`.
- [ ] All spacing/size from `LocalSpacing.current.*` or a named token constant — no bare dp in `.padding`/`.size`.
- [ ] No `TextStyle(fontSize=…, fontWeight=…)` in feature code — all text from `MaterialTheme.typography.*`.
- [ ] No reinvented Button/Card/TextField/BottomSheet — design_system composable referenced instead.
- [ ] No near-duplicate color/size literals that are off-by-one from a token value.
- [ ] No inline `TextStyle(…)` / `Modifier.background(Color(…))` with literals bypassing the theme.
- [ ] No `Color.White` / `Color.Black` in composable code — dark-mode uses semantic tokens; `darkColorScheme` wired.
- [ ] No inline SVG path / duplicate asset for an icon the system icon set already covers.
- [ ] No `RoundedCornerShape(N.dp)` / `elevation =` literals in feature composables — shape from `MaterialTheme.shapes`.
- [ ] Palette primitives (`AppColors.*`) used only in the theme layer; feature code references only semantic tokens.

## Halt conditions

Halt and report when:

- The codebase has no `MaterialTheme` definition — cannot evaluate token usage without a theme source of truth.
- The project uses a non-standard theming system not described in project `ctx/` — skip rather than misdiagnose.
- A guard violation cannot be resolved without knowing the correct token name — report the violation and ask.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Generation counterpart this skill enforces: [kmp-figma-to-code](../kmp-figma-to-code/SKILL.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Adjacent: [kmp-security](../kmp-security/SKILL.md) (security floor), [kmp-performance](../kmp-performance/SKILL.md) (stability, no literals), [kmp-module-structure](../kmp-module-structure/SKILL.md) (where design_system composables live)
- Bad → good Kotlin pairs for all 10 rules: [reference.md](./reference.md)
- Compose MaterialTheme: https://developer.android.com/reference/kotlin/androidx/compose/material3/MaterialTheme
- Material3 ColorScheme: https://m3.material.io/foundations/design-tokens/overview
- CompositionLocal: https://developer.android.com/develop/ui/compose/compositionlocal

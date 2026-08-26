---
name: flutter-design-system
description: Flutter design-system consistency guard — reuse existing design tokens and components
  instead of reinventing them, and detect/block the off-system code AI commonly produces (hardcoded
  colors, magic spacing/size, ad-hoc typography, reinvented components, off-scale variants, inline
  styles bypassing the theme, dark-mode/theme breaks, duplicated icons/assets, ad-hoc radius/elevation,
  primitive-instead-of-semantic tokens). The enforcement pair to flutter-figma-to-code. Auto-loads
  when writing or reviewing UI, themes, or tokens.
when_to_use: When building or reviewing UI, wiring themes/tokens, reviewing Figma-derived components,
  or on requests like "does this match the design system", "use the tokens", "design consistency review".
paths: "**/theme/**", "**/*_theme.dart", "**/design_system/**", "**/tokens.dart", "**/lib/**/*.dart", "**/widgets/**"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# flutter-design-system — design-system consistency guard

AI-generated Flutter code — especially [flutter-figma-to-code](../flutter-figma-to-code/SKILL.md)
output — **reinvents the design system instead of reusing it**: it hardcodes hex colors and magic
spacing numbers, builds a fifth bespoke `ElevatedButton` when one already exists in the widget
library, and emits values that silently break in dark mode. The result is drift: the same brand
blue in six slightly-different shades, spacing that ignores the scale, typography off the type
ramp. This skill is the **guard** (detect/block off-system code) plus **generation guidance**
(reuse existing tokens + components). It is the enforcement layer that makes
[flutter-figma-to-code](../flutter-figma-to-code/SKILL.md) safe to ship: generated UI must pass
THIS skill before merge.

## Scope

- Targets: Dart source under `lib/`, `**/theme/**`, `**/*_theme.dart`, `**/design_system/**`,
  `**/tokens.dart`, `**/widgets/**` — especially AI-generated or Figma-derived files.
- What it does: **detect off-system patterns → propose on-system alternatives** for each
  failure mode below.
- Delegate to adjacent skills: pixel-exact Figma translation → [flutter-figma-to-code];
  accessibility semantics → [flutter-widget-performance] (semantics labels, excludeFromSemantics);
  file/module placement → [flutter-module-structure]; security audit of generated code →
  [flutter-security].
- Reality: a Flutter app inherits one `ThemeData` tree. **Anything that bypasses it creates a
  second truth** — theme switches, dark mode, and white-label variants all break silently.

## Mode A — Reuse (generation guidance)

Before writing any new widget or token value, orient yourself in the existing system:

### Step 1 — Locate the token source and widget library

```bash
# Find ThemeData definition
grep -r "ThemeData(" lib/ --include="*.dart" -l

# Find ColorScheme
grep -r "ColorScheme\." lib/ --include="*.dart" -l | head -5

# Find ThemeExtensions (spacing, custom tokens)
grep -r "ThemeExtension" lib/ --include="*.dart" -l

# Find the design_system widget library
ls lib/design_system/ 2>/dev/null || ls lib/widgets/ 2>/dev/null
```

Do this FIRST. Never write a new color or spacing literal before knowing what
`ThemeData` already provides.

### Step 2 — Map a new screen to existing tokens and components

Read the token source, then map each design value to its semantic counterpart:

| Design need | Flutter semantic token |
|---|---|
| Brand primary color | `Theme.of(context).colorScheme.primary` |
| On-primary text | `colorScheme.onPrimary` |
| Surface / card background | `colorScheme.surface` |
| Error state | `colorScheme.error` |
| Body text | `Theme.of(context).textTheme.bodyMedium` |
| Headline | `textTheme.headlineMedium` |
| Spacing unit | `context.spacing.md` (or your `ThemeExtension`) |

Prefer semantic entries (`primary`, `surface`, `onSurface`) over palette entries
(`blue500`). A screen built on semantic tokens re-themes and switches dark mode
for free.

Map Figma instances to existing library widgets before writing any new markup:

```bash
# Does a button widget already exist?
grep -r "class.*Button" lib/design_system/ --include="*.dart" | head -10

# Does a card widget already exist?
grep -r "class.*Card" lib/design_system/ --include="*.dart" | head -10
```

If it exists, reference it. Building ad-hoc `Container`/`GestureDetector` markup
for what is a button is the most common AI drift.

### Step 3 — Extend the system in ONE place

A genuinely new design need is a **token or component addition reviewed once**,
not an inline literal used once. The calibration knob:

- New semantic color needed → add a `ThemeExtension` entry, not an inline `Color(0xFF…)`.
- New spacing value needed → add it to the spacing `ThemeExtension`, not `EdgeInsets.all(13)`.
- New component variant needed → add a parameter to the existing widget or a named constructor,
  not a second widget class with near-identical code.

```dart
// Add ONE extension entry instead of inlining everywhere
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({required this.highlight});
  final Color highlight;

  @override
  AppColorsExtension copyWith({Color? highlight}) =>
      AppColorsExtension(highlight: highlight ?? this.highlight);

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) =>
      AppColorsExtension(
        highlight: Color.lerp(highlight, other?.highlight, t) ?? highlight,
      );
}
```

Wire it in `ThemeData` once, consume via `Theme.of(context).extension<AppColorsExtension>()!`.

## Mode B — Guard (block off-system code)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded color

- **Rule**: no `Color(0xFF…)` / `Color(0xFFRRGGBB)` literals in widget code. All
  colors come from `Theme.of(context).colorScheme.*` or a named `ThemeExtension`.
  New colors → extend `ThemeData`, reviewed once.
- **Common AI failure**: Figma-to-code dumps `Color(0xFF3B82F6)` for every fill it
  reads. The next palette update or dark-mode switch leaves the widget stranded on
  the old value.
- **red-flag**: `Color(0xFF` appearing in widget files, `Colors.blue` / `Colors.red`
  literals outside `ThemeData` definitions, raw hex strings anywhere in `lib/`.

### 2. Magic spacing / size

- **Rule**: all padding, margin, gap, width, height that encodes a design-system
  spacing unit must come from the spacing `ThemeExtension` (e.g. `context.spacing.md`)
  or a named constant in the token file — not a bare number.
- **Common AI failure**: `EdgeInsets.all(13)`, `SizedBox(height: 24)`, `padding: 8`
  — numbers that match no token on the scale, creating unmaintainable one-offs.
- **red-flag**: `EdgeInsets.all(` / `EdgeInsets.symmetric(` / `SizedBox(height:` /
  `SizedBox(width:` with a bare integer that has no named-constant alias.

### 3. Ad-hoc typography

- **Rule**: font size, weight, family, and line height come from
  `Theme.of(context).textTheme.*`. Never set `fontSize:` / `fontWeight:` /
  `fontFamily:` inline in a `TextStyle` in widget code.
- **Common AI failure**: `TextStyle(fontSize: 15, fontWeight: FontWeight.w600)` —
  a one-off that ignores the type scale and breaks when the type ramp changes.
- **red-flag**: `TextStyle(fontSize:` / `fontWeight: FontWeight.` in widget files
  outside the `TextTheme` definition in `*_theme.dart`.

### 4. Reinvented component

- **Rule**: when the design system ships a widget (Button, Card, Modal, Input,
  BottomSheet), use it. Never rebuild the same widget as ad-hoc `Container` /
  `GestureDetector` / `Column` markup.
- **Common AI failure**: Figma-to-code sees a `PrimaryButton` frame and emits a
  `Container(decoration: BoxDecoration(…), child: GestureDetector(…))` instead of
  referencing `PrimaryButton(label: …, onTap: …)`.
- **red-flag**: a new `class` in a feature file that replicates a widget already in
  `lib/design_system/` or `lib/widgets/`; a `GestureDetector` wrapping styled
  `Container` text where a button widget exists.

### 5. Off-scale variant

- **Rule**: colors and sizes must be token values, not near-duplicates of tokens.
  `Color(0xFF3B83F7)` where the brand token is `Color(0xFF3B82F6)` is a one-off
  that looks intentional but is a typo/drift.
- **Common AI failure**: Figma layers often have a blue that is one step off the
  palette. The extractor rounds; the AI does not always notice.
- **red-flag**: hex values in the codebase that are within a few digits of an
  existing token value but are not the token; spacing numbers that are one unit
  off a scale step (e.g. 13 instead of 12 or 16).

### 6. Inline style bypassing theme

- **Rule**: do not pass a `TextStyle(…)` or `BoxDecoration(color: …)` containing
  literals directly to a widget in feature code. All decoration/style comes
  from the theme or a named style constant.
- **Common AI failure**: `Text('Hello', style: TextStyle(color: Colors.white,
  fontSize: 14))` — the theme is bypassed entirely; the widget ignores dark mode
  and palette changes.
- **red-flag**: `style: TextStyle(` with literals in feature widgets; `decoration:
  BoxDecoration(color: Color(0xFF…))` outside the design_system layer.

### 7. Dark-mode / theme break

- **Rule**: colors must come from `ColorScheme` semantic entries or an adaptive
  `ThemeExtension`. Never hardcode light-mode values (`Colors.white`,
  `Colors.black`, `Color(0xFFFFFFFF)`) as backgrounds or foregrounds — they
  produce invisible text or unreadable surfaces in dark mode.
- **Common AI failure**: `color: Colors.white` for a card background, `Colors.black`
  for body text — passes in light mode, invisible in dark mode. No `ThemeData.dark`
  counterpart wired.
- **red-flag**: `Colors.white` / `Colors.black` in widget code outside
  `ThemeData`; a `ThemeData` with no `.dark` companion; no `ColorScheme.fromSeed`
  or `ColorScheme.fromImageProvider` — only a hand-rolled `ColorScheme` with
  hardcoded light values.

### 8. Duplicated icon / asset

- **Rule**: use the icon set the design system already ships (`Icons.*`,
  `CupertinoIcons.*`, or the project's custom icon font / SVG sprite) instead of
  pasting a raw SVG path or adding a second copy of an existing asset.
- **Common AI failure**: Figma exports vector nodes as inline SVG path strings;
  AI copies them as `CustomPaint`/`Path` code instead of referencing the icon
  component. Or it adds `assets/icons/arrow.svg` when `Icons.arrow_forward` exists.
- **red-flag**: `Path()..moveTo(…)` reconstructing a UI icon; an SVG file in
  `assets/` that duplicates a named `Icons.*` glyph; `flutter_svg` used for
  an icon the system icon font already contains.

### 9. Ad-hoc radius / elevation / shadow

- **Rule**: corner radius, elevation, and shadow come from
  `Theme.of(context).cardTheme`, `ShapeDecoration`, or a named `ThemeExtension`
  token — not bare `borderRadius: BorderRadius.circular(7)` or `elevation: 3.5`.
- **Common AI failure**: every card and dialog gets its own `borderRadius: 12` or
  `elevation: 4` literal — out of sync with `CardTheme.shape` and impossible to
  update globally.
- **red-flag**: `BorderRadius.circular(` with a bare number in feature widgets;
  `elevation:` with a literal float; `BoxShadow(blurRadius:` outside the
  `ThemeData` / `ThemeExtension` definition.

### 10. Primitive instead of semantic token

- **Rule**: inside component and feature code, use semantic tokens
  (`colorScheme.primary`, `colorScheme.surface`, `textTheme.bodyMedium`) not
  palette primitives (`AppColors.blue500`, `const Color(0xFF60A5FA)`). Palette
  entries are defined once in the theme layer; they are never referenced directly
  from widget code.
- **Common AI failure**: importing `AppColors.blue500` directly into a feature widget
  instead of `colorScheme.primary` — re-theming and white-labelling silently breaks
  because the palette entry doesn't follow theme switches.
- **red-flag**: a raw palette class reference (`AppColors.`, `Palette.`,
  `DesignTokens.blue`) inside feature widget code; `const Color(0xFF…)` assigned
  directly to a widget property.

## Guard checklist

For Flutter UI code that AI generated or was Figma-derived, before merge:

- [ ] No `Color(0xFF…)` / `Colors.*` literals in feature widgets — all colors from `colorScheme.*` or `ThemeExtension`.
- [ ] All spacing/size from `context.spacing.*` or a named token constant — no bare integers in `EdgeInsets`/`SizedBox`.
- [ ] No `TextStyle(fontSize:…, fontWeight:…)` in feature code — all text from `textTheme.*`.
- [ ] No reinvented Button/Card/Input/Modal — design_system widget referenced instead.
- [ ] No near-duplicate color/size literals that are off-by-one from a token value.
- [ ] No inline `TextStyle(…)` / `BoxDecoration(color: …)` with literals bypassing the theme.
- [ ] No `Colors.white` / `Colors.black` in widget code — dark-mode uses semantic tokens; `ThemeData.dark` wired.
- [ ] No inline SVG path / duplicate asset for an icon the system icon set already covers.
- [ ] No `borderRadius: BorderRadius.circular(N)` / `elevation:` literals in feature widgets — shape from theme.
- [ ] Palette primitives (`AppColors.*`) used only in the theme layer; feature code references only semantic tokens.

## Halt conditions

Halt and report (per [skill-protocol.md](../../../_shared/skill-protocol.md)) when:

- The codebase has no `ThemeData` definition — cannot evaluate token usage without a theme source of truth.
- The project uses a non-standard theming system not described in project `ctx/` — skip rather than misdiagnose.
- A guard violation cannot be resolved without knowing the correct token name — report the violation and ask.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Generation counterpart this skill enforces: [flutter-figma-to-code](../flutter-figma-to-code/SKILL.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Adjacent: [flutter-security](../flutter-security/SKILL.md) (security floor, also applies to generated code), [flutter-widget-performance](../flutter-widget-performance/SKILL.md) (const, no literals), [flutter-module-structure](../flutter-module-structure/SKILL.md) (where design_system widgets live)
- Skill protocol: [skill-protocol.md](../../../_shared/skill-protocol.md)
- Bad → good Dart pairs for all 10 rules: [reference.md](./reference.md)
- Flutter ThemeData: https://api.flutter.dev/flutter/material/ThemeData-class.html
- Flutter ColorScheme: https://api.flutter.dev/flutter/material/ColorScheme-class.html
- Flutter ThemeExtension: https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- Material Design 3 tokens: https://m3.material.io/foundations/design-tokens/overview

# flutter-design-system — reference

Bad → good Dart pairs for every guard rule, plus Mode-A reuse examples.
The canonical source of truth for rule logic is [SKILL.md](./SKILL.md).

---

## Mode A — Locating the token source and mapping a new screen

### A1 — Orient before writing

```bash
# 1. Find ThemeData (the token source)
grep -r "ThemeData(" lib/ --include="*.dart" -l
# e.g. → lib/core/theme/app_theme.dart

# 2. Read its ColorScheme and TextTheme entries
grep -n "ColorScheme\|TextTheme\|ThemeExtension" lib/core/theme/app_theme.dart

# 3. Find the widget library
ls lib/design_system/ 2>/dev/null || ls lib/widgets/ 2>/dev/null
# e.g. → primary_button.dart  app_card.dart  app_text_field.dart ...

# 4. Check existing spacing tokens
grep -r "ThemeExtension" lib/core/theme/ --include="*.dart" -n
```

Only after this orientation do you write any widget or token reference.

### A2 — Map a new screen to existing tokens

Suppose Figma hands you a card with a blue background (`#3B82F6`), 16 dp
padding, body text at 14/regular, and a "Save" button.

```dart
// BAD — all values inlined from the Figma inspect panel
class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'John Doe',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          ),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E40AF),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// GOOD — tokens from theme, existing widget from design_system
class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<SpacingExtension>()!;

    return Card(                                    // uses CardTheme shape/elevation
      child: Padding(
        padding: EdgeInsets.all(spacing.md),        // token: md = 16
        child: Column(
          children: [
            Text('John Doe', style: theme.textTheme.bodyMedium),
            SizedBox(height: spacing.sm),           // token: sm = 8
            PrimaryButton(label: 'Save', onTap: _save), // existing design_system widget
          ],
        ),
      ),
    );
  }
}
```

### A3 — Adding ONE new token instead of inlining

When a genuinely new color is needed, extend `ThemeData` once — not in every caller.

```dart
// BAD — inlined in every widget that needs it
color: const Color(0xFFFFB703),  // repeated in 6 files → 6 diverging copies

// GOOD — add to ThemeExtension, define once, consume everywhere
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({required this.warning});
  final Color warning;

  @override
  AppColorsExtension copyWith({Color? warning}) =>
      AppColorsExtension(warning: warning ?? this.warning);

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) =>
      AppColorsExtension(
        warning: Color.lerp(warning, other?.warning, t) ?? warning,
      );
}

// In ThemeData definition (app_theme.dart):
ThemeData(
  extensions: const [
    AppColorsExtension(warning: Color(0xFFFFB703)),
  ],
  // ...
)

// In every consumer:
final warning = Theme.of(context).extension<AppColorsExtension>()!.warning;
```

---

## Rule 1 — Hardcoded color

```dart
// BAD — literal from Figma inspect panel
Container(
  color: const Color(0xFF3B82F6),   // brand blue hardcoded
  child: Text('Hello', style: TextStyle(color: const Color(0xFFFFFFFF))),
)

// GOOD — semantic ColorScheme entries; switches dark/light automatically
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
  ),
)
```

---

## Rule 2 — Magic spacing / size

```dart
// BAD — bare numbers, none of which map to the spacing scale
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
  child: SizedBox(height: 24, child: widget),
)

// GOOD — spacing ThemeExtension (or named spacing constants)
final s = Theme.of(context).extension<SpacingExtension>()!;

Padding(
  padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
  child: SizedBox(height: s.xl, child: widget),
)

// If using Flutter 3.27+ spacing: parameter on Row/Column, the same token applies:
Column(
  spacing: s.sm,
  children: [...],
)
```

---

## Rule 3 — Ad-hoc typography

```dart
// BAD — one-off TextStyle bypasses the type scale
Text(
  'Section header',
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
  ),
)

// GOOD — TextTheme entry; updates globally when the type ramp changes
Text(
  'Section header',
  style: Theme.of(context).textTheme.titleMedium,
)

// If a minor tweak is genuinely needed, copyWith from the base — never from scratch
Text(
  'Section header',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    color: Theme.of(context).colorScheme.primary, // still no literals
  ),
)
```

---

## Rule 4 — Reinvented component

```dart
// BAD — Figma-to-code emits raw markup for what is a PrimaryButton instance
GestureDetector(
  onTap: _submit,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF3B82F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'Submit',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  ),
)

// GOOD — reference the existing design_system widget
PrimaryButton(
  label: 'Submit',
  onTap: _submit,
)

// Similarly for cards:
// BAD
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
  ),
  child: ...,
)
// GOOD
AppCard(child: ...)
```

---

## Rule 5 — Off-scale variant

```dart
// BAD — Color(0xFF3B83F7) is one digit off the brand token (0xFF3B82F6)
//       and EdgeInsets.all(13) is off the 4dp grid (should be 12 or 16)
Container(
  color: const Color(0xFF3B83F7),
  padding: const EdgeInsets.all(13),
)

// GOOD — exact token; spacing on the scale
Container(
  color: Theme.of(context).colorScheme.primary, // resolves to 0xFF3B82F6
  padding: EdgeInsets.all(
    Theme.of(context).extension<SpacingExtension>()!.md, // 16, or sm = 12
  ),
)
```

When auditing: compare every hex literal against the token list and every spacing
number against the spacing scale. Off-by-one values are almost always drift,
not intentional.

---

## Rule 6 — Inline style bypassing theme

```dart
// BAD — TextStyle with literals passed directly to a feature widget
Text(
  user.name,
  style: const TextStyle(
    color: Color(0xFF1F2937),
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ),
)

// BAD — BoxDecoration with a literal color in a feature file
DecoratedBox(
  decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
  child: ...,
)

// GOOD — all style from the theme
Text(user.name, style: Theme.of(context).textTheme.titleSmall)

DecoratedBox(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceVariant,
  ),
  child: ...,
)
```

---

## Rule 7 — Dark-mode / theme break

```dart
// BAD — hardcoded light-mode values; invisible in dark mode
Scaffold(
  backgroundColor: Colors.white,
  body: Text(
    'Welcome',
    style: const TextStyle(color: Colors.black),
  ),
)

// BAD — ThemeData with no dark companion
MaterialApp(
  theme: ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3B82F6),
      // only light values — dark mode never wired
    ),
  ),
)

// GOOD — semantic tokens; dark theme defined alongside light
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.light,
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system,
)

// Widget usage: semantic, adaptive automatically
Scaffold(
  // no backgroundColor: — Scaffold reads Theme.of(context).scaffoldBackgroundColor
  body: Text(
    'Welcome',
    style: Theme.of(context).textTheme.bodyLarge, // color from TextTheme
  ),
)
```

---

## Rule 8 — Duplicated icon / asset

```dart
// BAD — Figma vector exported as CustomPaint path, duplicating Icons.arrow_forward
CustomPaint(
  painter: _ArrowPainter(),   // 40 lines of path math for a standard arrow icon
)

// BAD — SVG pasted for an icon the icon font already covers
SvgPicture.asset('assets/icons/arrow_forward.svg')  // when Icons.arrow_forward exists

// GOOD — use the system icon set
Icon(
  Icons.arrow_forward,
  color: Theme.of(context).colorScheme.onSurface,
)

// When a custom icon IS genuinely needed (not in Icons.*):
// 1. Add it to the project's custom icon font, NOT as an inline SVG path
// 2. Reference via the icon class, not SvgPicture
Icon(AppIcons.customArrow)

// If SVG is required (e.g. multi-color illustration):
SvgPicture.asset(
  'assets/illustrations/onboarding_hero.svg',  // illustration, not an icon
  semanticsLabel: 'Onboarding hero image',
)
```

Before adding any SVG or `CustomPaint` icon, run:
```bash
grep -r "Icons\." lib/ --include="*.dart" | grep -i "arrow\|close\|check\|menu" | head -5
```

---

## Rule 9 — Ad-hoc radius / elevation / shadow

```dart
// BAD — per-widget literals for corner radius and elevation
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(7),       // arbitrary, not on the scale
    boxShadow: [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 3.5,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)

// BAD — inline elevation on a Card ignoring CardTheme
Card(elevation: 3.5, child: ...)

// GOOD — shape and elevation from theme
// In ThemeData:
ThemeData(
  cardTheme: const CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),
)

// In widget code — no shape or elevation literals:
Card(child: ...)

// For surfaces that need explicit shape token from a ThemeExtension:
final shape = Theme.of(context).extension<ShapeExtension>()!;
Container(
  decoration: BoxDecoration(
    borderRadius: shape.cardRadius,   // BorderRadius token, defined once
    color: Theme.of(context).colorScheme.surface,
  ),
)
```

---

## Rule 10 — Primitive instead of semantic token

```dart
// BAD — palette primitive imported directly into a feature widget
import 'package:my_app/core/theme/app_colors.dart';

// In widget:
Text(
  'Action',
  style: TextStyle(color: AppColors.blue500),   // primitive bypasses re-theming
)

Container(color: AppColors.gray100)             // breaks on dark theme or white-label

// GOOD — semantic token from ColorScheme
Text(
  'Action',
  style: TextStyle(color: Theme.of(context).colorScheme.primary),
)

Container(color: Theme.of(context).colorScheme.surfaceVariant)

// Palette constants (AppColors.blue500) are defined ONCE in the theme layer:
// lib/core/theme/app_theme.dart
ThemeData _buildLightTheme() => ThemeData(
  colorScheme: const ColorScheme.light(
    primary: AppColors.blue500,   // palette → semantic mapping here only
    surface: AppColors.gray100,
  ),
)

// Every other file in the project references colorScheme.*, never AppColors.* directly.
```

---

## Quick-scan commands

Run these to surface the most common violations in a new codebase or PR:

```bash
# Hardcoded colors (rules 1, 5, 10)
grep -rn "Color(0xFF" lib/ --include="*.dart" | grep -v "_theme.dart\|tokens.dart\|design_system"

# Magic spacing (rule 2)
grep -rn "EdgeInsets\.all([0-9]\|EdgeInsets\.symmetric\|SizedBox(height\|SizedBox(width" lib/ --include="*.dart" \
  | grep -v "_theme.dart\|tokens.dart\|design_system"

# Ad-hoc typography (rule 3)
grep -rn "TextStyle(fontSize\|fontWeight: FontWeight\." lib/ --include="*.dart" \
  | grep -v "_theme.dart\|tokens.dart\|design_system"

# Dark-mode white/black literals (rule 7)
grep -rn "Colors\.white\|Colors\.black" lib/ --include="*.dart" \
  | grep -v "_theme.dart\|tokens.dart"

# Primitive palette imports in feature code (rule 10)
grep -rn "AppColors\.\|Palette\." lib/ --include="*.dart" \
  | grep -v "_theme.dart\|tokens.dart\|app_colors.dart"

# Ad-hoc radius/elevation (rule 9)
grep -rn "BorderRadius\.circular(\|elevation: [0-9]" lib/ --include="*.dart" \
  | grep -v "_theme.dart\|tokens.dart\|design_system"
```

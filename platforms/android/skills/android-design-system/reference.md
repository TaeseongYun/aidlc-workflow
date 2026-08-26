# android-design-system — Reference

Code examples for `SKILL.md`. One bad→good Kotlin/Compose pair per guard rule, plus
Mode-A worked examples (locating tokens, mapping a screen, adding one token). Decision
criteria and halt conditions live in `SKILL.md`.

---

## Rule 1 — Hardcoded color

```kotlin
// BAD: raw hex literal — ignores the active ColorScheme; breaks dark mode
Text(
    text = label,
    color = Color(0xFF3366FF),   // hardcoded brand blue, not a semantic role
)

Box(
    modifier = Modifier.background(Color(0xFFFFFFFF))  // always white, invisible in dark mode
)
```

```kotlin
// GOOD: semantic ColorScheme role — resolves correctly for light and dark
Text(
    text = label,
    color = MaterialTheme.colorScheme.primary,
)

Box(
    modifier = Modifier.background(MaterialTheme.colorScheme.surface)
)
```

---

## Rule 2 — Magic spacing/size

```kotlin
// BAD: raw dp literals — no relation to the spacing scale; breaks when scale changes
Column(
    verticalArrangement = Arrangement.spacedBy(13.dp),
    modifier = Modifier.padding(13.dp),
)
```

```kotlin
// GOOD: spacing token from core/designsystem — one place to update, everywhere changes
// AppTokens (generated from DTCG tokens.json, lives in core/designsystem):
//   val spaceSm = 8.dp
//   val spaceMd = 16.dp
Column(
    verticalArrangement = Arrangement.spacedBy(AppTokens.spaceSm),
    modifier = Modifier.padding(AppTokens.spaceMd),
)
```

---

## Rule 3 — Ad-hoc typography

```kotlin
// BAD: inline font config — duplicates the type ramp, diverges when the scale updates
Text(
    text = title,
    fontSize = 15.sp,
    fontWeight = FontWeight(600),
    letterSpacing = 0.5.sp,
)
```

```kotlin
// GOOD: MaterialTheme.typography slot — correct size/weight/tracking everywhere
Text(
    text = title,
    style = MaterialTheme.typography.titleMedium,
    color = MaterialTheme.colorScheme.onSurface,
)
```

If the exact Figma style does not map to an existing `Typography` slot, add a new
`TextStyle` to `core/designsystem/Type.kt` and reference it — do not inline.

---

## Rule 4 — Reinvented component

```kotlin
// BAD: bespoke "button" from raw primitives — misses ripple, semantics, disabled state,
// and any future designsystem update
Row(
    modifier = Modifier
        .background(Color(0xFF3366FF), RoundedCornerShape(8.dp))
        .clickable { onClick() }
        .padding(horizontal = 16.dp, vertical = 8.dp),
    verticalAlignment = Alignment.CenterVertically,
) {
    Text(text = label, color = Color.White)
}
```

```kotlin
// GOOD: designsystem composable — role, ripple, disabled, focus, a11y included
PrimaryButton(
    text = label,
    onClick = onClick,
    enabled = enabled,
)
```

Grep `**/designsystem/**/*.kt` before building any control to confirm it does not
already exist.

---

## Rule 5 — Off-scale variant

```kotlin
// BAD: near-duplicate literal — #3B83F7 vs brand token #3B82F6; one hex digit off;
// accumulates into six slightly-different blues over time
Box(modifier = Modifier.background(Color(0xFF3B83F7)))
```

```kotlin
// GOOD: exact token — one source of truth; grep the token file to confirm the match
Box(modifier = Modifier.background(MaterialTheme.colorScheme.primary))
// or, for a primitive within core/designsystem only:
// Box(modifier = Modifier.background(AppTokens.brandPrimary))  // Color(0xFF3B82F6)
```

When a Figma value is close but not identical to a token, raise a design question
("Is this intentional?") rather than emitting the literal.

---

## Rule 6 — Inline style bypassing theme

```kotlin
// BAD: visual properties hardcoded inline — theme switch has no effect
Box(
    modifier = Modifier
        .background(Color(0xFFEEEEEE))
        .clip(RoundedCornerShape(8.dp))
        .border(1.dp, Color(0xFFCCCCCC))
)
```

```kotlin
// GOOD: theme-resolved values — survives re-theming and dark mode
Box(
    modifier = Modifier
        .background(MaterialTheme.colorScheme.surfaceVariant)
        .clip(MaterialTheme.shapes.small)
        .border(1.dp, MaterialTheme.colorScheme.outline)
)
```

---

## Rule 7 — Dark-mode / theme break

```kotlin
// BAD: hardcoded light/dark pair — duplicates the theme, breaks on custom color schemes
val bgColor = if (isSystemInDarkTheme()) Color(0xFF1A1A1A) else Color.White
Box(modifier = Modifier.background(bgColor))

Text(text = body, color = Color.Black)   // invisible on dark background
```

```kotlin
// GOOD: semantic ColorScheme role — the MaterialTheme does the switching
Box(modifier = Modifier.background(MaterialTheme.colorScheme.background))

Text(text = body, color = MaterialTheme.colorScheme.onBackground)
```

Dark mode comes from providing a `darkColorScheme` in the theme definition
(`core/designsystem/Theme.kt`), not from `isSystemInDarkTheme()` branches inside
individual composables.

---

## Rule 8 — Duplicated icon/asset

```kotlin
// BAD: inline vector path reconstruction — brittle, large, duplicates the icon set
val arrowPath = Path().apply {
    moveTo(12f, 4f); lineTo(20f, 12f); lineTo(12f, 20f)
    moveTo(4f, 12f); lineTo(20f, 12f)
}
Canvas(modifier = Modifier.size(24.dp)) { drawPath(arrowPath, color = Color.Black) }
```

```kotlin
// GOOD: existing resource — one place, automatically tinted by LocalContentColor
Icon(
    painter = painterResource(R.drawable.ic_arrow_forward),
    contentDescription = stringResource(R.string.cd_navigate_forward),
    tint = MaterialTheme.colorScheme.onSurface,
)
```

Before adding a new drawable, run:
```bash
find . -name "ic_*.xml" -o -name "ic_*.kt" | xargs grep -l "arrow"
```
to confirm the icon does not already exist under a different name.

---

## Rule 9 — Ad-hoc radius / elevation / shadow

```kotlin
// BAD: literal radius and elevation — not on the shapes/elevation scale
Card(
    shape = RoundedCornerShape(7.dp),       // 7 matches no token
    modifier = Modifier.shadow(elevation = 3.dp),  // 3 matches no elevation token
) { /* … */ }
```

```kotlin
// GOOD: theme shape and elevation tokens
Card(
    shape = MaterialTheme.shapes.medium,   // typically 12.dp, defined once in Theme.kt
    elevation = CardDefaults.cardElevation(defaultElevation = AppTokens.elevationMd),
) { /* … */ }
```

If `MaterialTheme.shapes.small/medium/large` does not match the design, add a named
shape constant to `core/designsystem/Shape.kt` — do not emit a raw literal.

---

## Rule 10 — Primitive instead of semantic token

```kotlin
// BAD: palette primitive in composable code — breaks on re-theme (white-label, seasonal)
Text(
    text = ctaLabel,
    color = AppTokens.brandBlue,          // wired to primitive; survives re-theme? no
    modifier = Modifier.background(AppTokens.white),
)
```

```kotlin
// GOOD: semantic role — re-themed by swapping the ColorScheme, composable unchanged
Text(
    text = ctaLabel,
    color = MaterialTheme.colorScheme.onPrimary,
    modifier = Modifier.background(MaterialTheme.colorScheme.primary),
)
```

Palette primitives (`AppTokens.brandBlue`, `Color(0xFF3366FF)`) belong **only** in
`core/designsystem` when building the `lightColorScheme` / `darkColorScheme`. Anywhere
else, use the semantic `colorScheme.*` role.

---

## Mode-A Example 1 — Locate token source + map a new screen

Before writing any new composable, run this sequence:

```bash
# 1. Find the active theme definition
find . -name "*Theme.kt" -path "*/designsystem/*"
# e.g. → app/core/designsystem/src/main/kotlin/com/example/designsystem/Theme.kt

# 2. Find all existing composables
find . -name "*.kt" -path "*/designsystem/*" | head -20
# → PrimaryButton.kt, AppCard.kt, AppTextField.kt, AppChip.kt …

# 3. Find the token/color palette
find . -name "*Color*.kt" -o -name "*Type*.kt" -o -name "AppTokens.kt" | grep -v test
```

Read `Theme.kt` to see how `lightColorScheme` / `darkColorScheme` are wired.
Read `Type.kt` for the `Typography` slots in use.

Now map the new `CheckoutSummaryScreen` to what already exists:

| Design element | Token / composable to use |
|---|---|
| Section heading "Order Total" | `MaterialTheme.typography.titleMedium` |
| Body text prices | `MaterialTheme.typography.bodyMedium` |
| Primary CTA "Place Order" | `PrimaryButton(text, onClick, enabled)` |
| Divider between sections | `HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)` |
| Row padding | `AppTokens.spaceMd` (16.dp) |
| Card background | `MaterialTheme.colorScheme.surface` with `MaterialTheme.shapes.medium` |
| Error color for out-of-stock | `MaterialTheme.colorScheme.error` |

Zero new composables needed. Zero new literals.

---

## Mode-A Example 2 — Add ONE token instead of inlining

Design calls for a 24 dp "section gap" that does not exist on the current scale
(`spaceSm = 8`, `spaceMd = 16`, `spaceLg = 32`).

```kotlin
// BAD: inline the one-off
Column(verticalArrangement = Arrangement.spacedBy(24.dp)) { /* … */ }
```

```kotlin
// GOOD: add the token once in core/designsystem, reference everywhere
// In core/designsystem/src/main/kotlin/com/example/designsystem/Tokens.kt:
object AppTokens {
    val spaceSm  = 8.dp
    val spaceMd  = 16.dp
    val spaceSection = 24.dp   // ← new; reviewed once; reused everywhere  // ponytail: one token addition beats N inline literals
    val spaceLg  = 32.dp
}

// In the composable:
Column(verticalArrangement = Arrangement.spacedBy(AppTokens.spaceSection)) { /* … */ }
```

The token addition is a one-line diff in `core/designsystem`. Every future screen that
needs 24 dp reuses it without a review comment.

---

## Mode-A Example 3 — Figma-to-code output review checklist

After running `android-figma-to-code`, apply this checklist before merge:

| Check | Look for | Fix |
|---|---|---|
| Colors | `Color(0xFF...)` in composable body | → `MaterialTheme.colorScheme.*` |
| Spacing | `.padding(N.dp)` with literal N | → `AppTokens.*` constant |
| Typography | `fontSize = N.sp` / `fontWeight = FontWeight(N)` | → `MaterialTheme.typography.*` slot |
| Components | `Row/Column` that visually duplicates a designsystem control | → reference existing composable |
| Shapes | `RoundedCornerShape(N.dp)` literal | → `MaterialTheme.shapes.*` |
| Dark mode | `Color.White` / `Color.Black` as backgrounds or text | → `colorScheme.background` / `colorScheme.onBackground` |
| Icons | Inline `Path` / new drawable that duplicates existing icon | → `painterResource(R.drawable.ic_*)` |
| Primitives | `AppTokens.brand*` in composable body outside designsystem | → `colorScheme.*` semantic role |

Pass all 8 checks → safe to merge (alongside [android-security](../android-security/SKILL.md)).

---

## References

- `SKILL.md` for rules, halt conditions, and Mode-A/B structure
- Generation counterpart: [android-figma-to-code](../android-figma-to-code/SKILL.md)
- Material Design 3 color roles: https://m3.material.io/styles/color/roles
- Material Design 3 type scale: https://m3.material.io/styles/typography/type-scale-tokens
- Compose `MaterialTheme` API: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary#MaterialTheme
- W3C DTCG token format (for the token source): https://tr.designtokens.org/format/

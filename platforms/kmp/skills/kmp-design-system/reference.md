# kmp-design-system — reference

Bad → good Kotlin pairs for every guard rule, plus Mode-A reuse examples.
The canonical source of truth for rule logic is [SKILL.md](./SKILL.md).

---

## Mode A — Locating the token source and mapping a new screen

### A1 — Orient before writing

```bash
# 1. Find MaterialTheme definition (the token source)
grep -r "MaterialTheme\b" --include="*.kt" -l . | head -5
# e.g. → shared/src/commonMain/kotlin/com/example/theme/AppTheme.kt

# 2. Read its ColorScheme and Typography entries
grep -n "colorScheme\|typography\|CompositionLocal\|LocalSpacing" \
  shared/src/commonMain/kotlin/com/example/theme/AppTheme.kt

# 3. Find the composable library
find . -type d -name "design_system" | head -5
# or
ls shared/src/commonMain/kotlin/com/example/design_system/

# 4. Check existing spacing tokens
grep -r "staticCompositionLocalOf\|compositionLocalOf" --include="*.kt" . | head -10
```

Only after this orientation do you write any composable or token reference.

### A2 — Map a new screen to existing tokens

Suppose Figma hands you a card with a blue background (`#3B82F6`), 16 dp
padding, body text at 14/regular, and a "Save" button.

```kotlin
// BAD — all values inlined from the Figma inspect panel
@Composable
fun ProfileCard(onSave: () -> Unit) {
    Box(
        modifier = Modifier
            .padding(16.dp)
            .background(
                color = Color(0xFF3B82F6),
                shape = RoundedCornerShape(12.dp),
            )
    ) {
        Column {
            Text(
                "John Doe",
                style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal),
            )
            Box(
                modifier = Modifier
                    .background(Color(0xFF1E40AF))
                    .clickable { onSave() }
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text("Save", style = TextStyle(color = Color.White, fontSize = 14.sp))
            }
        }
    }
}

// GOOD — tokens from theme, existing composable from design_system
@Composable
fun ProfileCard(onSave: () -> Unit) {
    val spacing = LocalSpacing.current
    AppCard {                                                  // uses CardDefaults shape/elevation
        Padding(all = spacing.md) {
            Column(verticalArrangement = Arrangement.spacedBy(spacing.sm)) {
                Text("John Doe", style = MaterialTheme.typography.bodyMedium)
                PrimaryButton(label = "Save", onClick = onSave) // existing design_system composable
            }
        }
    }
}
```

### A3 — Adding ONE new token instead of inlining

When a genuinely new color is needed, extend via `CompositionLocal` once — not in every caller.

```kotlin
// BAD — inlined in every composable that needs it
color = Color(0xFFFFB703)  // repeated in 6 files → 6 diverging copies

// GOOD — add to a CompositionLocal data class, define once, consume everywhere
data class AppColors(
    val warning: Color,
)

val LocalAppColors = staticCompositionLocalOf {
    AppColors(warning = Color.Unspecified)
}

// In AppTheme:
CompositionLocalProvider(
    LocalAppColors provides AppColors(warning = Color(0xFFFFB703))
) {
    content()
}

// In every consumer:
val warning = LocalAppColors.current.warning
```

---

## Rule 1 — Hardcoded color

```kotlin
// BAD — literal from Figma inspect panel
Box(modifier = Modifier.background(Color(0xFF3B82F6))) {
    Text("Hello", color = Color(0xFFFFFFFF))
}

// GOOD — semantic ColorScheme entries; switches dark/light automatically
Box(modifier = Modifier.background(MaterialTheme.colorScheme.primary)) {
    Text(
        "Hello",
        color = MaterialTheme.colorScheme.onPrimary,
    )
}
```

---

## Rule 2 — Magic spacing / size

```kotlin
// BAD — bare dp numbers, none of which map to the spacing scale
Box(modifier = Modifier.padding(horizontal = 13.dp, vertical = 7.dp)) {
    Spacer(modifier = Modifier.height(24.dp))
}

// GOOD — spacing CompositionLocal (or named spacing constants)
val s = LocalSpacing.current

Box(modifier = Modifier.padding(horizontal = s.md, vertical = s.xs)) {
    Spacer(modifier = Modifier.height(s.xl))
}

// Same token applies to Arrangement:
Column(verticalArrangement = Arrangement.spacedBy(s.sm)) { /* … */ }
```

---

## Rule 3 — Ad-hoc typography

```kotlin
// BAD — one-off TextStyle bypasses the type scale
Text(
    "Section header",
    style = TextStyle(
        fontSize = 15.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = FontFamily.SansSerif,
    ),
)

// GOOD — Typography entry; updates globally when the type ramp changes
Text(
    "Section header",
    style = MaterialTheme.typography.titleMedium,
)

// If a minor tweak is genuinely needed, copyWith from the base — never from scratch
Text(
    "Section header",
    style = MaterialTheme.typography.titleMedium.copy(
        color = MaterialTheme.colorScheme.primary, // still no literals
    ),
)
```

---

## Rule 4 — Reinvented composable

```kotlin
// BAD — Figma-to-code emits raw markup for what is a PrimaryButton instance
Box(
    modifier = Modifier
        .background(
            color = Color(0xFF3B82F6),
            shape = RoundedCornerShape(8.dp),
        )
        .clickable { onSubmit() }
        .padding(horizontal = 24.dp, vertical = 12.dp),
) {
    Text(
        "Submit",
        style = TextStyle(color = Color.White, fontWeight = FontWeight.SemiBold),
    )
}

// GOOD — reference the existing design_system composable
PrimaryButton(
    label = "Submit",
    onClick = onSubmit,
)

// Similarly for cards:
// BAD
Box(
    modifier = Modifier
        .background(Color.White, RoundedCornerShape(12.dp))
        .shadow(elevation = 4.dp, shape = RoundedCornerShape(12.dp))
) { /* … */ }

// GOOD
AppCard { /* … */ }
```

---

## Rule 5 — Off-scale variant

```kotlin
// BAD — Color(0xFF3B83F7) is one digit off the brand token (0xFF3B82F6)
//       and Modifier.padding(13.dp) is off the 4dp grid (should be 12.dp or 16.dp)
Box(
    modifier = Modifier
        .background(Color(0xFF3B83F7))
        .padding(13.dp),
)

// GOOD — exact token; spacing on the scale
Box(
    modifier = Modifier
        .background(MaterialTheme.colorScheme.primary) // resolves to 0xFF3B82F6
        .padding(LocalSpacing.current.md),             // 16.dp, or sm = 12.dp
)
```

When auditing: compare every hex literal against the token list and every dp number
against the spacing scale. Off-by-one values are almost always drift, not intentional.

---

## Rule 6 — Inline style bypassing theme

```kotlin
// BAD — TextStyle with literals passed directly to a feature composable
Text(
    user.name,
    style = TextStyle(
        color = Color(0xFF1F2937),
        fontSize = 16.sp,
        fontWeight = FontWeight.Medium,
    ),
)

// BAD — background with a literal color in a feature file
Box(modifier = Modifier.background(Color(0xFFF9FAFB))) { /* … */ }

// GOOD — all style from the theme
Text(user.name, style = MaterialTheme.typography.titleSmall)

Box(
    modifier = Modifier.background(MaterialTheme.colorScheme.surfaceVariant)
) { /* … */ }
```

---

## Rule 7 — Dark-mode / theme break

```kotlin
// BAD — hardcoded light-mode values; invisible in dark mode
Scaffold(
    containerColor = Color.White,
) {
    Text(
        "Welcome",
        style = TextStyle(color = Color.Black),
    )
}

// BAD — only lightColorScheme defined; darkColorScheme never wired
@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(primary = Color(0xFF3B82F6)),
        // dark mode never wired — invisible text in dark theme
        content = content,
    )
}

// GOOD — semantic tokens; dark theme defined alongside light
private val LightColors = lightColorScheme(
    primary = Color(0xFF3B82F6),
    // … other roles
)
private val DarkColors = darkColorScheme(
    primary = Color(0xFF93C5FD),
    // … dark-mode counterparts
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}

// Widget usage: semantic, adaptive automatically
Scaffold {  // no containerColor: — Scaffold reads MaterialTheme.colorScheme.background
    Text(
        "Welcome",
        style = MaterialTheme.typography.bodyLarge, // color from Typography
    )
}
```

---

## Rule 8 — Duplicated icon / asset

```kotlin
// BAD — Figma vector exported as DrawScope path, duplicating Icons.ArrowForward
Canvas(modifier = Modifier.size(24.dp)) {
    // 40 lines of path math for a standard arrow icon
    drawPath(arrowPath, color = Color.Black)
}

// BAD — SVG added to composeResources when Icons.ArrowForward exists
Icon(
    painter = painterResource(Res.drawable.ic_arrow_forward),
    contentDescription = null,
)

// GOOD — use the system icon set
Icon(
    imageVector = Icons.Default.ArrowForward,
    contentDescription = null,
    tint = MaterialTheme.colorScheme.onSurface,
)

// When a custom icon IS genuinely needed (not in Icons.*):
// 1. Add the SVG to composeResources/drawable/ and reference via painterResource
// 2. Never reconstruct paths inline in DrawScope
Icon(
    painter = painterResource(Res.drawable.ic_custom_arrow),
    contentDescription = null,
)
```

Before adding any SVG or `Canvas` icon, check:
```bash
grep -r "Icons\." --include="*.kt" . | grep -i "arrow\|close\|check\|menu" | head -5
```

---

## Rule 9 — Ad-hoc radius / elevation / shadow

```kotlin
// BAD — per-composable literals for corner radius and elevation
Box(
    modifier = Modifier
        .shadow(elevation = 3.5.dp, shape = RoundedCornerShape(7.dp))
        .background(Color.White, RoundedCornerShape(7.dp))
)

// BAD — inline elevation on a Card ignoring MaterialTheme.shapes
Card(elevation = CardDefaults.cardElevation(defaultElevation = 3.5.dp)) { /* … */ }

// GOOD — shape and elevation from theme
// In AppTheme:
MaterialTheme(
    shapes = Shapes(
        medium = RoundedCornerShape(12.dp), // defined once
    ),
)

// In composable code — no shape or elevation literals:
Card { /* … */ }  // uses MaterialTheme.shapes.medium automatically

// For surfaces that need an explicit shape token from a CompositionLocal:
val shape = LocalAppShapes.current
Box(
    modifier = Modifier
        .background(MaterialTheme.colorScheme.surface, shape.cardShape)
)
```

---

## Rule 10 — Primitive instead of semantic token

```kotlin
// BAD — palette primitive imported directly into a feature composable
import com.example.theme.AppColors

// In composable:
Text(
    "Action",
    color = AppColors.Blue500,  // primitive bypasses re-theming
)
Box(modifier = Modifier.background(AppColors.Gray100))  // breaks on dark theme

// GOOD — semantic token from ColorScheme
Text(
    "Action",
    color = MaterialTheme.colorScheme.primary,
)
Box(modifier = Modifier.background(MaterialTheme.colorScheme.surfaceVariant))

// Palette constants (AppColors.Blue500) are defined ONCE in the theme layer:
// shared/.../theme/AppTheme.kt
private val LightColorScheme = lightColorScheme(
    primary = AppColors.Blue500,    // palette → semantic mapping here only
    surface = AppColors.Gray100,
)

// Every other file references MaterialTheme.colorScheme.*, never AppColors.* directly.
```

---

## Quick-scan commands

Run these to surface the most common violations in a new codebase or PR:

```bash
# Hardcoded colors (rules 1, 5, 10)
grep -rn "Color(0xFF" --include="*.kt" . \
  | grep -v "Theme\|Colors\|Palette\|Token\|design_system"

# Magic spacing (rule 2)
grep -rn "\.padding([0-9]\|\.height([0-9]\|\.width([0-9]\|\.size([0-9]" --include="*.kt" . \
  | grep -v "Theme\|Token\|design_system"

# Ad-hoc typography (rule 3)
grep -rn "fontSize\s*=\|fontWeight\s*=" --include="*.kt" . \
  | grep "TextStyle" | grep -v "Theme\|Typography\|Token"

# Dark-mode white/black literals (rule 7)
grep -rn "Color\.White\|Color\.Black\b" --include="*.kt" . \
  | grep -v "Theme\|Token"

# Primitive palette imports in feature code (rule 10)
grep -rn "AppColors\.\|Palette\." --include="*.kt" . \
  | grep -v "Theme\|Token\|AppColors\.kt"

# Ad-hoc radius/elevation (rule 9)
grep -rn "RoundedCornerShape([0-9]\|elevation\s*=\s*[0-9]" --include="*.kt" . \
  | grep -v "Theme\|Token\|design_system"
```

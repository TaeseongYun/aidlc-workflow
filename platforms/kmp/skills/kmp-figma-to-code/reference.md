# kmp-figma-to-code — Reference

Deep-dive for `SKILL.md`. End-to-end pipeline, a worked example, per-node code, and
the token transform. Decision criteria live in `SKILL.md`.

## 1. Pipeline end to end

```bash
export FIGMA_TOKEN=figd_xxx
python3 scripts/figma/figma_export.py --file <FILE_KEY> --node <NODE_ID> --out ./design/out
# → ./design/out/manifest.json  (normalized UI tree)
# → ./design/out/tokens.json    (DTCG design tokens)
```

`FILE_KEY`/`NODE_ID` come from the Figma URL
(`figma.com/design/<FILE_KEY>/...?node-id=<NODE_ID>`). See the shared tool's
[README](../../../../scripts/figma/README.md) for the manifest contract. Map
**tokens first** (they define the theme composables reference), then composables.

## 2. Worked example

`manifest.json` (the tool's sample `OrderCard`, abbreviated):

```jsonc
{ "type": "stack", "name": "OrderCard",
  "size": { "widthMode": "fill", "heightMode": "hug" },
  "style": { "fill": "#ffffff", "cornerRadius": 12, "fillToken": true },
  "layout": { "direction": "column", "gap": 8,
              "padding": { "top": 16, "right": 16, "bottom": 16, "left": 16 }, "align": "center" },
  "children": [
    { "type": "text", "text": { "content": "Order #42",
      "style": { "fontSize": 18, "fontWeight": 600, "color": "#1a1a1a" } } },
    { "type": "instance", "component": { "name": "PrimaryButton", "props": { "label": "Pay" } } }
  ] }
```

→ composable (`fillToken` → a theme surface color, **not** `Color(0xFFFFFFFF)`; sizes
from `LocalSpacing.current`, text style from `MaterialTheme.typography`):

```kotlin
// generated — re-run figma_export to update; wrap for behavior, don't edit here
@Composable
fun OrderCard(
    orderId: String,
    onPay: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val spacing = LocalSpacing.current
    Surface(
        color = MaterialTheme.colorScheme.surface,      // fillToken, not Color(0xFFFFFFFF)
        shape = RoundedCornerShape(spacing.cornerMd),   // cornerRadius 12 → token
        modifier = modifier.fillMaxWidth(),             // widthMode: fill
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally, // align: center
            verticalArrangement = Arrangement.spacedBy(spacing.sm), // gap 8 → token
            modifier = Modifier.padding(spacing.md)     // padding 16 → token
                .wrapContentHeight(),                   // heightMode: hug
        ) {
            Text(
                text = "Order #$orderId",
                style = MaterialTheme.typography.titleMedium,
            )
            PrimaryButton(label = "Pay", onClick = onPay)
        }
    }
}
```

Note what the human added that Figma can't express: the `PrimaryButton`
design-system composable (not remade `Box` markup), the `onPay` behavior, and the
`Modifier.semantics`/role decisions the button composable already carries. Colors,
sizes, and the text style are **theme references**, never literals — so dark mode
and re-theming just work.

## 3. Node → Kotlin

```kotlin
// stack (column) → Column; gap → Arrangement.spacedBy(token), padding → Modifier.padding, align → alignment
Column(
    verticalArrangement = Arrangement.spacedBy(LocalSpacing.current.sm),
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier.padding(LocalSpacing.current.md),
) { /* children */ }

// stack (row) → Row
Row(
    horizontalArrangement = Arrangement.spacedBy(LocalSpacing.current.sm),
    verticalAlignment = Alignment.CenterVertically,
) { /* children */ }

// text → Text with a typography style (style/color/size from theme, never literals)
Text(title, style = MaterialTheme.typography.titleMedium)

// instance → the composable named by the node; params from component.props
PrimaryButton(label = label, onClick = onPay)

// image → Image/AsyncImage; contentDescription required (decorative → null)
AsyncImage(
    model = node.image.src,
    contentDescription = describeNode(node.name), // null for decorative
)

// rect → Box with Modifier.background from theme tokens
Box(
    modifier = Modifier
        .background(
            color = MaterialTheme.colorScheme.surfaceVariant,
            shape = RoundedCornerShape(LocalSpacing.current.sm),
        )
        .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(LocalSpacing.current.sm))
)

// frame (direction none) → Box, children use Modifier.align (overlays only)
Box(modifier = Modifier.fillMaxSize()) {
    // each child: Modifier.align(Alignment.TopStart) etc.
}

// vector → Icon from icon set / painterResource for custom SVG; never reconstruct paths
Icon(
    painter = painterResource(Res.drawable.ic_cart),
    contentDescription = null, // decorative icon inside labeled button
    tint = MaterialTheme.colorScheme.onSurface,
)
```

`widthMode: fill` → `Modifier.fillMaxWidth()`; `hug` → `Modifier.wrapContentWidth()` /
`Arrangement` without weight; `fixed` → a token dimension (never raw dp).

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" } },
  "space": { "sm": { "$type": "dimension", "$value": 8 },
             "md": { "$type": "dimension", "$value": 16 } } }
```

Colors map into a `ColorScheme`; dimensions into a `CompositionLocal` spacing data class
that composables read as `LocalSpacing.current.*`:

```kotlin
// generated theme fragment — from tokens.json (run in build/CI)
data class AppSpacing(
    val sm: Dp,   // space.sm → 8.dp
    val md: Dp,   // space.md → 16.dp
    val cornerMd: Dp = 12.dp,
)

val LocalSpacing = staticCompositionLocalOf { AppSpacing(sm = 8.dp, md = 16.dp) }

// colorScheme fragment — color.brand.primary / color.surface
private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF3366FF),          // color.brand.primary — lives in the theme, not composables
    surface = Color(0xFFFFFFFF),          // color.surface
    // … other roles generated from token modes
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,       // typography tokens → Typography
    ) {
        CompositionLocalProvider(
            LocalSpacing provides AppSpacing(sm = 8.dp, md = 16.dp),
        ) {
            content()
        }
    }
}
```

DTCG modes (light/dark) become `lightColorScheme`/`darkColorScheme` — don't hardcode
one mode into the composables.

## 5. Gotchas

- **Auto-layout → Column/Row + Arrangement.spacedBy.** `direction` row/column, `gap` →
  `Arrangement.spacedBy(token)`, `padding` → `Modifier.padding(token)`, `justify`/`align` →
  `horizontalArrangement`/`verticalAlignment`. `direction: none` = absolute layout →
  `Box` with `Modifier.align`, and only for real overlays.
- **Sizing.** `fill` → `Modifier.fillMaxWidth()`/`fillMaxHeight()`, `hug` →
  `Modifier.wrapContentWidth()`/`wrapContentHeight()`, `fixed` → a token dimension; never
  dump the raw dp as a fixed size.
- **Variants → params.** A component set's variant/boolean properties arrive in
  `component.props` — map them to the composable's function parameters, not to forked
  markup.
- **Icons.** `vector` nodes are icons — export via the Figma `/images` endpoint / your
  icon set and render with `Icon`/`painterResource`; don't reconstruct path data in
  `DrawScope`.
- **Text style/color.** The manifest has no heading/label distinction — you assign the
  `Typography` style; color/size come from theme tokens, never `Color(0xFF…)` or raw `sp`
  literals ([kmp-design-system](../kmp-design-system/SKILL.md)).
- **Stability for recomposition perf.** Generated data classes passed to composables should
  be annotated `@Immutable` or use `kotlinx.collections.immutable` collections so the
  Compose compiler can skip recomposition ([kmp-performance](../kmp-performance/SKILL.md)).
- **Dark mode.** Comes from token modes → `darkColorScheme`, not a second hardcoded palette.

## 6. Regenerate workflow

- Generated composables in a dedicated dir (e.g. `feature/<name>/presentation/generated/`),
  imported by hand-written wrappers that add state/behavior. See
  [kmp-module-structure](../kmp-module-structure/SKILL.md).
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- The generated code is **input to review**, not merge-ready: run it past
  [kmp-security](../kmp-security/SKILL.md) (and the [kmp-design-system](../kmp-design-system/SKILL.md)
  no-literals bar) first.

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

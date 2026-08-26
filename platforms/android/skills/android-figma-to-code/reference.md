# android-figma-to-code — Reference

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

→ composable (Compose + theme tokens; `fillToken` → a color token, not `#ffffff`):

```kotlin
// generated — re-run figma_export to update; wire behavior in the screen, don't edit here
@Composable
fun OrderCard(orderId: String, onPay: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)               // shape token, not 12.dp
            .background(MaterialTheme.colorScheme.surface)   // token, not #ffffff
            .padding(AppTokens.spaceMd),                     // 16 via token
        verticalArrangement = Arrangement.spacedBy(AppTokens.spaceSm),  // 8 via token
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.order_number, orderId),  // string resource, not a literal
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        PrimaryButton(text = stringResource(R.string.pay), onClick = onPay)  // designsystem composable
    }
}
```

Note what the human added that Figma can't express: the `surface`/`onSurface` color
tokens and `titleMedium` type token (not raw hex/px), the `stringResource` strings
(not literals), the `PrimaryButton` designsystem composable (not remade `Row`), and
the `onPay` behavior. Figma has none of that.

## 3. Node → composable

```kotlin
// stack (column) → Column; gap → Arrangement.spacedBy, padding/align from layout
Column(
    verticalArrangement = Arrangement.spacedBy(8.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = Modifier.padding(16.dp),
) { /* … */ }

// text → Text with a typography + color token (never a raw hex); string from resources
Text(text = title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)

// instance → the composable named by the node; args from component.props
PrimaryButton(text = label, onClick = onClick)

// image → model is the node's resolved image.src; contentDescription required (a11y)
AsyncImage(model = node.image.src, contentDescription = describe(node.name))

// rect → Box styled from tokens
Box(Modifier.clip(RoundedCornerShape(8.dp)).background(MaterialTheme.colorScheme.surfaceVariant))

// frame (direction none) → Box, children as overlays only
Box { /* overlaid children */ }

// vector → exported asset, don't reconstruct paths
Icon(painter = painterResource(R.drawable.ic_star), contentDescription = null)
```

`widthMode: fill`→`Modifier.fillMaxWidth()`/`weight(1f)`, `hug`→`wrapContentWidth/Height`,
`fixed`→ a token dp (avoid raw px→dp).

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" } },
  "space": { "md": { "$type": "dimension", "$value": 16 } } }
```

A small transform maps DTCG → a `core/designsystem` theme fragment (run in build/CI):

```kotlin
// generated theme fragment — DTCG tokens → Compose ColorScheme / dp scale
object AppTokens {
    val brandPrimary = Color(0xFF3366FF)
    val surface = Color(0xFFFFFFFF)
    val spaceSm = 8.dp
    val spaceMd = 16.dp
}

internal val LightColors = lightColorScheme(
    primary = AppTokens.brandPrimary,
    surface = AppTokens.surface,
    // onSurface, etc. from their own tokens
)
```

Feed the `ColorScheme` into `MaterialTheme(...)`; composables read
`MaterialTheme.colorScheme.*` / `AppTokens.*`, never raw literals. **Dark mode comes
from token modes** (a `darkColorScheme` built from the same tokens' dark values), not
a second hardcoded palette.

## 5. Gotchas

- **Auto-layout → Column/Row.** `direction` row/column → `Row`/`Column`, `gap`→
  `Arrangement.spacedBy`, `padding`→`Modifier.padding`, `justify`/`align`→
  `Arrangement.*` / `horizontalAlignment`/`verticalAlignment`. `direction: none` =
  absolute layout → `Box` and only for real overlays.
- **Sizing.** `fill`→`fillMaxWidth()`/`weight(1f)`, `hug`→`wrapContentWidth/Height`,
  `fixed`→ a token dp; never dump the raw px as `.width(...)`.
- **Variants → args.** A component set's variant/boolean properties arrive in
  `component.props` — map them to the composable's parameters, not to forked markup.
- **Icons.** `vector` nodes are icons — export via the Figma `/images` endpoint or
  your icon set and use `painterResource`; don't reconstruct paths from the manifest.
- **Text roles + strings.** The manifest has no heading/label distinction — you pick
  the `MaterialTheme.typography.*` style. Its `color`/size come from tokens, and the
  content comes from a string resource, not an inline literal.
- **Dark mode.** Comes from token modes (a `darkColorScheme`), not a second palette.

## 6. Regenerate workflow

- Generated composables in a dedicated dir (e.g. `feature/<name>/ui/generated/`),
  called by hand-written screens that add state/behavior. See
  [android-module-structure] for where generated composables and designsystem tokens
  live.
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- The generated code is **input to review**, not merge-ready: run it past
  [android-security] first (no hardcoded strings/URLs/secrets, exported-surface
  rules).

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

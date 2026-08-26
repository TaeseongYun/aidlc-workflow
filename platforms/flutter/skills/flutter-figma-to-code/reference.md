# flutter-figma-to-code — Reference

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
**tokens first** (they define the theme widgets reference), then widgets.

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

→ widget (`fillToken` → a theme surface color, **not** `Color(0xFFFFFFFF)`; sizes
from `context.spacing`, text style from `textTheme`):

```dart
// generated — re-run figma_export to update; wrap for behavior, don't edit here
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.orderId, required this.onPay});

  final String orderId;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,                 // fillToken, not Color(0xFFFFFFFF)
        borderRadius: BorderRadius.circular(context.spacing.md),  // cornerRadius 12 → token
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),      // padding 16 → token
        child: Column(
          mainAxisSize: MainAxisSize.min,                 // heightMode: hug
          crossAxisAlignment: CrossAxisAlignment.center,  // align: center
          spacing: context.spacing.sm,                    // gap 8 (Flutter 3.27+); else SizedBox
          children: [
            Text('Order #$orderId', style: theme.textTheme.titleMedium),
            PrimaryButton(label: 'Pay', onPressed: onPay),
          ],
        ),
      ),
    );
  }
}
```

Note what the human added that Figma can't express: the `PrimaryButton`
design-system widget (not remade `Container` markup), the `onPay` behavior, and the
`Semantics`/role decisions the button widget already carries. Colors, sizes, and the
text style are **theme references**, never literals — so dark mode and re-theming
just work. `const` goes on any static leaf; the outer widget can't be `const` here
because it takes runtime params.

## 3. Node → Dart

```dart
// stack (column)  → Column; gap → spacing:/SizedBox, padding → Padding, align → axis alignment
Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  spacing: context.spacing.sm,
  children: [/* … */],
);

// text → Text with a textTheme style (style/color/size from theme, never literals)
Text(title, style: Theme.of(context).textTheme.titleMedium);

// instance → the widget named by the node; params from component.props
PrimaryButton(label: label, onPressed: onPay);

// image → the node's resolved image.src; semanticLabel required (decorative → excludeFromSemantics: true)
Image.network(node.image.src, semanticLabel: describe(node.name));

// rect → DecoratedBox / Container from theme tokens
DecoratedBox(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(context.spacing.sm),
    border: Border.all(color: Theme.of(context).colorScheme.outline),
  ),
);

// frame (direction none) → Stack, children Positioned (overlays only)
Stack(children: const [/* Positioned … */]);

// vector → flutter_svg / Icon from an exported asset, don't reconstruct paths
SvgPicture.asset('assets/icons/cart.svg');
```

`widthMode: fill`→`Expanded`/`double.infinity`, `hug`→`MainAxisSize.min`,
`fixed`→ a token dimension (avoid raw px).

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" } },
  "space": { "sm": { "$type": "dimension", "$value": 8 },
             "md": { "$type": "dimension", "$value": 16 } } }
```

Colors map into a `ColorScheme` fragment; dimensions into a spacing `ThemeExtension`
that widgets read as `context.spacing.*` (the same extension
[flutter-widget-performance] uses):

```dart
// generated theme fragment — from tokens.json (run in build/CI)
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({required this.sm, required this.md});
  final double sm;   // space.sm → 8
  final double md;   // space.md → 16

  @override
  AppSpacing copyWith({double? sm, double? md}) =>
      AppSpacing(sm: sm ?? this.sm, md: md ?? this.md);
  @override
  AppSpacing lerp(AppSpacing? o, double t) => o == null ? this : AppSpacing(
      sm: lerpDouble(sm, o.sm, t)!, md: lerpDouble(md, o.md, t)!);
}

// sugar so widgets read context.spacing.md
extension SpacingX on BuildContext {
  AppSpacing get spacing => Theme.of(this).extension<AppSpacing>()!;
}

// colorScheme fragment — color.brand.primary / color.surface
const _seed = Color(0xFF3366FF); // from color.brand.primary — lives in the theme, not widgets
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  extensions: const [AppSpacing(sm: 8, md: 16)],
  textTheme: /* typography tokens → TextTheme */,
);
```

DTCG modes (light/dark) become `ThemeData` / `ThemeData.dark` variants — don't
hardcode one mode into the widgets.

## 5. Gotchas

- **Auto-layout → Column/Row + spacing.** `direction` row/column, `gap`→`spacing:`
  (Flutter 3.27+) / `SizedBox` / a `Gap`, `padding`→`Padding`, `justify`/`align`→
  `mainAxisAlignment`/`crossAxisAlignment`. `direction: none` = absolute layout →
  `Stack`/`Positioned`, and only for real overlays.
- **Sizing.** `fill`→`Expanded`/`double.infinity`, `hug`→`MainAxisSize.min`/
  intrinsic, `fixed`→ a token dimension; never dump the raw px as a fixed size.
- **Variants → params.** A component set's variant/boolean properties arrive in
  `component.props` — map them to the widget's constructor params, not to forked
  markup.
- **Icons.** `vector` nodes are icons — export via the Figma `/images` endpoint /
  your icon set and render with `flutter_svg` or `Icon`; don't reconstruct SVG paths.
- **Text style/color.** The manifest has no heading/label distinction — you assign
  the `TextTheme` style; color/size come from theme tokens, never `Color(0xFF…)` or
  raw `fontSize` ([flutter-widget-performance]).
- **`const` for rebuild perf.** Put `const` on static leaf subtrees so they skip
  rebuilds ([flutter-widget-performance]).
- **Dark mode.** Comes from token modes → `ThemeData.dark`, not a second hardcoded
  palette.

## 6. Regenerate workflow

- Generated widgets in a dedicated dir (e.g. `lib/features/<name>/presentation/generated/`),
  imported by hand-written wrappers that add state/behavior. See
  [flutter-module-structure].
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- The generated code is **input to review**, not merge-ready: run it past
  [flutter-security] (and the [flutter-widget-performance] `const`/no-literals bar)
  first.

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

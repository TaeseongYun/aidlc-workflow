# ios-figma-to-code — Reference

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
**tokens first** (they define the theme views reference), then views.

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

→ view (SwiftUI + token refs; `fillToken` → `Color("Surface")`, not
`Color(red:…)`):

```swift
// generated — re-run figma_export to update; wrap for behavior, don't edit here
struct OrderCard: View {
    let orderId: String
    let onPay: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {                 // gap 8  → spacing token
            Text("Order #\(orderId)")
                .font(.headline)                       // type token, not fontSize: 18
                .foregroundStyle(Color("Content"))     // color token, not #1a1a1a
            PrimaryButton(title: "Pay", action: onPay) // design-system view, not remade
        }
        .frame(maxWidth: .infinity)                    // widthMode: fill
        .padding(Spacing.md)                           // padding 16 → spacing token
        .background(Color("Surface"))                  // fillToken, not Color(red:…)
        .cornerRadius(Radius.md)                       // radius token (12), not a literal
    }
}
```

Note what the human added that Figma can't express: the `PrimaryButton`
design-system view (not remade SwiftUI), token references for color/spacing/type
(not raw hex/`CGFloat`), and the `onPay` behavior — screen state/effects come
later via `@Observable` ([ios-state-concurrency]), not inside this generated view.

## 3. Node → SwiftUI

```swift
// stack (column) → VStack; spacing/padding/alignment from layout
VStack(alignment: .center, spacing: Spacing.sm) { … }
    .padding(Spacing.md)

// stack (row) → HStack; same params
HStack(alignment: .top, spacing: Spacing.sm) { … }

// text → Text with a font token + color token (role/semantics are yours to add)
Text(title).font(.headline).foregroundStyle(Color("Content"))

// instance → the view named by the node; props from component.props
PrimaryButton(title: label, action: onTap)

// image → url from the node's resolved image.src; accessibilityLabel required
AsyncImage(url: URL(string: node.image.src)) { $0.resizable() } placeholder: { ProgressView() }
    .accessibilityLabel(Text(describe(node.name)))

// rect → shape/background from tokens
RoundedRectangle(cornerRadius: Radius.md)
    .fill(Color("Elevated"))
    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color("Muted")))

// vector → SF Symbol or an exported asset
Image(systemName: "creditcard").foregroundStyle(Color("Content"))

// frame (direction none) → ZStack, children overlaid (overlays only)
ZStack { children }
```

`widthMode: fill`→`.frame(maxWidth: .infinity)`, `hug`→ intrinsic (no frame),
`fixed`→ a token dimension (avoid raw `CGFloat`).

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" } },
  "space": { "md": { "$type": "dimension", "$value": 16 } } }
```

Map DTCG → the `DesignSystem` package. Two equivalent targets:

**Asset-catalog color sets** — emit one `.colorset` per `color` token so
`Color("Surface")` resolves through the catalog. Prefer this: it gets dark mode
for free (see below).

**A `Theme` enum** for dimensions/typography (and colors that don't need the
catalog):

```swift
// generated from tokens.json — re-run figma_export to update
enum Spacing { static let sm: CGFloat = 8; static let md: CGFloat = 16 }
enum Radius  { static let md: CGFloat = 12 }
enum Theme {
    static let brandPrimary = Color("BrandPrimary")   // from the color set
    static let headline = Font.custom("Inter-SemiBold", size: 18)
}
```

**Dark mode via token modes → asset-catalog appearances.** A DTCG color with
light/dark modes becomes a single color set with `Any`/`Dark` appearances in the
`.xcassets`, resolved automatically by the trait environment. Do **not** emit a
second hardcoded palette or a `colorScheme == .dark ? … : …` fork.

## 5. Gotchas

- **Auto-layout → stack.** `direction` column→`VStack`, row→`HStack`; `gap`→ the
  `spacing:` param (not `.padding`); `padding`→ `.padding(EdgeInsets(...))` or a
  uniform `.padding(Spacing.*)`; `align`→ the stack `alignment:`. `direction: none`
  = absolute layout → `ZStack`, and only for real overlays.
- **Spacing vs padding.** `gap` is *between* children (`spacing:`); `padding` is
  *around* the stack (`.padding`). Don't collapse one into the other.
- **Sizing.** `fill`→`.frame(maxWidth: .infinity)`, `hug`→ intrinsic (no frame at
  all), `fixed`→ a token dimension; never dump the raw px as a
  `.frame(width:height:)` layout — it breaks Dynamic Type.
- **Variants → view params.** A component set's variant/boolean properties arrive in
  `component.props` — map them to the view's init parameters, not to branching CSS-
  style modifiers.
- **Icons.** `vector` nodes are icons — use an SF Symbol (`Image(systemName:)`) or
  export the asset to the catalog; don't reconstruct vector paths from the manifest.
- **Raster assets are webp.** The shared pipeline (`figma_images.py`) delivers
  raster images as webp to keep bundle size down — add them to the asset catalog
  as-is (decoded natively on iOS 14+); don't convert back to png.
- **Color & font from tokens.** The manifest's `color`/`fontSize` are hints; the
  view uses `Color("...")` / a `Font` token, not `Color(red:…)` / `.font(.system(size: 18))`.
- **Dark mode.** Comes from asset-catalog appearances driven by token modes, not a
  second hardcoded palette.
- **Keep generated views free of business logic.** No network, no persistence, no
  `@Observable` store inside the generated view — wire state separately
  ([ios-state-concurrency]).

## 6. Regenerate workflow

- Generated views in a dedicated dir of the `DesignSystem` package (e.g.
  `Sources/DesignSystem/Generated/`), imported by hand-written wrappers that add
  data/behavior. See [ios-module-structure].
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- The generated code is **input to review**, not merge-ready: run it past
  [ios-security] first, and wire `@Observable` state via [ios-state-concurrency].

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

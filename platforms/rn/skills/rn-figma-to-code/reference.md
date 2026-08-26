# rn-figma-to-code — Reference

Deep-dive for `SKILL.md`. End-to-end pipeline, a worked example, per-node code, the
token transform, and the RN-vs-web gotchas. Decision criteria live in `SKILL.md`.
The pipeline is **identical** to the web sibling
[frontend-figma-to-code](../../../frontend/skills/frontend-figma-to-code/reference.md);
only the emitter (RN `View`/`Text` + `StyleSheet`) differs.

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
**tokens first** (they define the theme styles reference), then components.

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

→ RN function component (`StyleSheet` referencing theme tokens; `fillToken` →
`theme.colors['surface']`, not `#ffffff`):

```tsx
// generated — re-run figma_export to update; wrap for behavior, don't edit here
import { View, Text, StyleSheet } from 'react-native';
import { theme } from '../theme';
import { PrimaryButton } from '../components/PrimaryButton';

export function OrderCard({ orderId, onPay }: { orderId: string; onPay: () => void }) {
  return (
    <View style={styles.card}>
      <Text style={styles.title} accessibilityRole="header">{`Order #${orderId}`}</Text>
      <PrimaryButton label="Pay" onPress={onPay} />
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'column',   // RN default, explicit for clarity
    gap: theme.space.sm,       // 8 via token; needs RN ≥ 0.71
    padding: theme.space.md,   // 16 via token, not a raw literal
    alignItems: 'center',
    width: '100%',             // widthMode: fill
    borderRadius: theme.radius.lg,          // cornerRadius 12 via token
    backgroundColor: theme.colors['surface'], // fillToken → token, not '#ffffff'
  },
  title: { ...theme.text.titleM, color: theme.colors['content'] },
});
```

Note what the human added that Figma can't express: `accessibilityRole="header"`
on the title (RN has no `<h2>` — the role is the a11y signal), the `PrimaryButton`
design-system component (not remade markup), and the `onPay` behavior. The text is
interpolated as a **string** — RN `<Text>` has no `dangerouslySetInnerHTML`, but the
same rule holds: never inject unescaped HTML/markup.

## 3. Node → RN code

```tsx
// stack (column) → View, flexDirection column; gap/padding/align from layout
<View style={{ flexDirection: 'column', gap: 8, padding: 16, alignItems: 'center' }}>…</View>

// stack (row) → flexDirection: 'row'
<View style={{ flexDirection: 'row', gap: 12 }}>…</View>

// text → <Text>; add accessibilityRole="header" where the node is a heading (a11y)
<Text style={styles.title} accessibilityRole="header">{title}</Text>

// instance → the design-system component named by the node; props from component.props
<PrimaryButton label={label} onPress={onPress} />

// image → uri is the node's resolved image.src; accessibilityLabel required (a11y)
<Image source={{ uri: node.image.src }} accessible accessibilityLabel={describe(node.name)} style={styles.img} />

// rect → View styled from tokens
<View style={styles.divider} />

// frame (direction none) → relative container, children position:'absolute' (overlays only)
<View style={{ position: 'relative' }}>{children}</View>
```

`widthMode: fill`→`flex: 1` or `width: '100%'`; `hug`→ intrinsic (no explicit size);
`fixed`→ a token dimension (avoid raw px literals). RN default `flexDirection` is
`'column'`, so a column stack needs no override — set it explicitly only for clarity.

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" },
             "content": { "$type": "color", "$value": "#1a1a1a" } },
  "space":  { "sm": { "$type": "dimension", "$value": 8 },
              "md": { "$type": "dimension", "$value": 16 } },
  "radius": { "lg": { "$type": "dimension", "$value": 12 } },
  "typography": { "titleM": { "$type": "typography",
                              "$value": { "fontSize": 18, "fontWeight": 600, "lineHeight": 24 } } } }
```

A small transform flattens DTCG → a typed TS theme object (run in build/CI), which
`StyleSheet` consumes directly:

```ts
// scripts/tokens-to-theme.ts — DTCG → a typed theme object
import tokens from '../design/out/tokens.json';
const flat = (o: any, p: string[] = []): Record<string, any> =>
  '$value' in o ? { [p.join('-')]: o.$value }
                : Object.assign({}, ...Object.entries(o).map(([k, v]) => flat(v, [...p, k])));
export const theme = {
  colors: flat(tokens.color),   // { 'brand-primary': '#3366ff', surface: '#ffffff', content: '#1a1a1a' }
  space:  flat(tokens.space),   // { md: 16 }
  radius: flat(tokens.radius),  // { lg: 12 }
  text: Object.fromEntries(     // { titleM: { fontSize: 18, fontWeight: 600, lineHeight: 24 } }
    Object.entries<any>(tokens.typography).map(([k, v]) => [k, v.$value])),
} as const;
```

`StyleSheet.create` then references `theme.colors['brand-primary']` / `theme.space.md`
— no raw literals in components. DTCG **modes** (light/dark) become theme variants
resolved at runtime via `useColorScheme()` — don't hardcode a second palette.

## 5. Gotchas (RN vs web)

- **No DOM/CSS/className.** RN styles are plain objects in `StyleSheet.create`, not
  class strings. There is no cascade, no selectors, no `!important`.
- **Flexbox only, `flex` not `display`.** No `display: flex`/`block`/`grid`; layout
  is always flex. `flexDirection` **defaults to `'column'`** (web defaults to row) —
  a column stack needs no override; a row stack must set `flexDirection: 'row'`.
- **`gap` needs RN ≥ 0.71.** On older RN, emit margins instead. `justify`/`align`→
  `justifyContent`/`alignItems`.
- **Units.** Most numeric props are unitless density-independent points, not px/rem.
  `%` strings work on `width`/`height` but not everywhere (e.g. not `gap`) — prefer
  numbers or `flex`.
- **Sizing.** `fill`→`flex: 1`/`width: '100%'`, `hug`→ intrinsic (omit size),
  `fixed`→ a token dimension; never dump the raw px as the layout width.
- **Accessibility folds in here (no separate RN a11y skill).** The manifest has no
  heading/paragraph/control distinction — you assign it: `accessibilityRole="header"`
  on headings, `accessibilityRole="button"`/`accessibilityLabel` on controls,
  `accessibilityLabel` on meaningful images (decorative →
  `accessibilityElementsHidden`), touch targets ≥ 44pt. Same semantic/label
  principle as the web sibling [frontend-figma-to-code], expressed via a11y props.
- **Icons.** `vector` nodes are icons — export via the Figma `/images` endpoint or
  your icon set (`react-native-svg`); don't reconstruct paths from the manifest.
- **Dark mode.** Comes from token modes + `useColorScheme()`, not a second hardcoded
  palette.

## 6. Regenerate workflow

- Generated components in a dedicated dir (e.g. `components/generated/`), imported
  by hand-written wrappers that add data/behavior. See [rn-architecture].
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- Generated lists of rows: wrap in `FlatList`/`FlashList` with stable keys →
  [rn-performance-ux].
- The generated code is **input to review**, not merge-ready: run it past
  [rn-security] first.

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- Web sibling (shared pipeline): [../../../frontend/skills/frontend-figma-to-code/SKILL.md](../../../frontend/skills/frontend-figma-to-code/SKILL.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

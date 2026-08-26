# frontend-figma-to-code — Reference

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
**tokens first** (they define the theme components reference), then components.

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

→ component (Tailwind + token classes; `fillToken` → `bg-surface`, not `#ffffff`):

```tsx
// generated — re-run figma_export to update; wrap for behavior, don't edit here
export function OrderCard({ orderId, onPay }: { orderId: string; onPay: () => void }) {
  return (
    <section className="flex flex-col items-center gap-2 w-full rounded-xl bg-surface p-4">
      <h2 className="text-lg font-semibold text-content">{`Order #${orderId}`}</h2>
      <Button variant="primary" onClick={onPay}>Pay</Button>
    </section>
  );
}
```

Note what the human added that Figma can't express: `<section>`/`<h2>` semantics
(not `<div>`), the `<Button>` design-system component (not remade markup), and the
`onPay` behavior. The text is interpolated as a **string** — never
`dangerouslySetInnerHTML`. (`bg-surface`/`text-content`/`rounded-xl` are
illustrative theme classes mapped from your tokens — not literal Figma values.)

## 3. Node → JSX

```tsx
// stack (column)  → flex-col; gap/padding/align from layout
<div className="flex flex-col gap-2 p-4 items-center">…</div>

// text → semantic element by role + type token (role is yours to decide → a11y)
<h2 className="text-lg font-semibold text-content">{title}</h2>

// instance → the design-system component named by the node; props from component.props
<Button variant="primary">{label}</Button>

// image → src is the node's resolved image.src; alt is required (a11y)
<Image src={node.image.src} alt={describe(node.name)} width={w} height={h} />

// rect → styled div from tokens
<div className="rounded-md border border-muted bg-elevated" />

// frame (direction none) → relative container, children absolutely placed (overlays only)
<div className="relative">{children}</div>
```

`widthMode: fill`→`w-full`, `hug`→`w-fit`, `fixed`→ a token width (avoid raw px).

## 4. Token transform (DTCG → theme)

`tokens.json`:

```json
{ "color": { "brand": { "primary": { "$type": "color", "$value": "#3366ff" } },
             "surface": { "$type": "color", "$value": "#ffffff" } },
  "space": { "md": { "$type": "dimension", "$value": 16 } } }
```

A small transform flattens DTCG → your styling system (run in build/CI):

```ts
// scripts/tokens-to-tailwind.ts — DTCG → Tailwind theme fragment
import tokens from "./design/out/tokens.json";
const flat = (o: any, p: string[] = []): Record<string, any> =>
  "$value" in o ? { [p.join("-")]: o.$value }
                : Object.assign({}, ...Object.entries(o).map(([k, v]) => flat(v, [...p, k])));
export const colors = flat(tokens.color);   // { "brand-primary": "#3366ff", surface: "#ffffff" }
```

Emit CSS custom properties (`--color-brand-primary`) or a Tailwind `theme.extend`
fragment. DTCG modes (light/dark) become theme variants — don't hardcode one mode.

## 5. Gotchas

- **Auto-layout → flex.** `direction` row/column, `gap`→`gap-*`, `padding`→`p-*`,
  `justify`/`align`→ `justify-*`/`items-*`. `direction: none` = absolute layout →
  `relative`/`absolute` and only for real overlays.
- **Sizing.** `fill`→`w-full`/`flex-1`, `hug`→`w-fit`/`h-fit`, `fixed`→ a token
  width; never dump the raw px as the layout width.
- **Variants → props.** A component set's variant/boolean properties arrive in
  `component.props` — map them to the library component's props, not to CSS forks.
- **Icons.** `vector` nodes are icons — export via the Figma `/images` endpoint or
  your icon set; don't reconstruct SVG paths from the manifest.
- **Text roles.** The manifest has no heading/paragraph/label distinction — you
  assign the semantic element ([frontend-accessibility]). Its `color`/size come from
  type tokens.
- **Dark mode.** Comes from token modes, not a second hardcoded palette.

## 6. Regenerate workflow

- Generated components in a dedicated dir (e.g. `components/generated/`), imported
  by hand-written wrappers that add data/behavior. See [frontend-module-structure].
- On a design change: re-run `figma_export` → review the `manifest.json`/`tokens.json`
  diff → regenerate. Never hand-patch a generated file in place.
- The generated code is **input to review**, not merge-ready: run it past
  [frontend-accessibility] and [frontend-security] first.

## References

- Shared extractor + manifest contract: [`scripts/figma/README.md`](../../../../scripts/figma/README.md)
- W3C DTCG: https://tr.designtokens.org/format/
- Figma REST API: https://www.figma.com/developers/api
- `SKILL.md` for the rules and mapping tables.

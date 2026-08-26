# figma_export — Figma → manifest + design tokens

Shared extraction tool behind every platform's `*-figma-to-code` skill. It turns a
Figma frame into two **platform-agnostic, reproducible** artifacts that per-platform
emitters map to code:

| Output | What it is |
|---|---|
| `manifest.json` | Normalized UI tree. Auto-layout → `direction`/`gap`/`padding`, sizing → `fixed`/`fill`/`hug`, component instances → `{component, props}`, text → content + type style. |
| `tokens.json` | Design tokens in [W3C DTCG](https://tr.designtokens.org/format/) format (`color` / `dimension` / `typography`), from Figma **variables** when the plan exposes them, else from published **styles**. |

Stdlib only (`urllib`) — no `pip install`. Python 3.9+.

## Usage

```bash
export FIGMA_TOKEN=figd_xxxxxxxx          # Figma personal access token (file:read)
python3 scripts/figma/figma_export.py --file <FILE_KEY> --node <NODE_ID> --out ./out
```

`FILE_KEY` and `NODE_ID` come straight from a Figma URL:

```
https://www.figma.com/design/<FILE_KEY>/Name?node-id=<NODE_ID>
```

The URL's `node-id` uses `-` (e.g. `12-345`); the tool accepts that or the API's
`:` form. Omit `--node` to export the top-level frames of the first page.

The token needs only **read** scope (`file:read`) — keep it in an env var or a
secret store, never commit it. `--out` is confined to the working tree (writes
outside it are rejected); the emitted `manifest.json`/`tokens.json` contain design
data only, never the token.

## Offline self-check

```bash
python3 scripts/figma/figma_export.py --demo     # normalizes a bundled sample, asserts output → "OK"
```

No token or network needed — this is the tool's regression test.

## The manifest contract (IR)

```jsonc
{
  "figmaFileKey": "abc",
  "screens": [
    {
      "id": "1:2", "name": "OrderCard", "type": "stack",
      "size": { "width": 320, "height": 120, "widthMode": "fill", "heightMode": "hug" },
      "style": { "fill": "#ffffff", "cornerRadius": 12, "fillToken": true },
      "layout": { "direction": "column", "gap": 8,
                  "padding": { "top": 16, "right": 16, "bottom": 16, "left": 16 },
                  "justify": "start", "align": "center", "wrap": false },
      "children": [
        { "type": "text", "text": { "content": "Order #42",
          "style": { "fontFamily": "Inter", "fontSize": 18, "fontWeight": 600, "color": "#1a1a1a" } } },
        { "type": "instance", "component": { "id": "9:9", "name": "PrimaryButton",
          "props": { "label": "Pay" } } }
      ]
    }
  ]
}
```

Node `type` is one of: `frame`, `stack`, `text`, `image`, `rect`, `vector`,
`instance`. `fillToken: true` means the fill was bound to a Figma variable/style —
emit a **token reference**, not the raw hex. An `image` node carries
`image: { ref, src }` — `ref` is the Figma `imageRef` and `src` is the resolved
fill download URL (filled from the image-fills endpoint; `null` if that call was
skipped). Each platform skill documents how it maps these to its widgets and theme.

## Notes / limits

- Variables API (`/variables/local`) is Enterprise-only; the tool falls back to
  published styles automatically. Variable **aliases** and BOOLEAN vars are skipped
  in the baseline — extend `tokens_from_variables` if you need them.
- Absolute-positioned children (`direction: none`) carry size but no flow; treat
  them as overlay/`Stack` at the use site.
- Vectors/icons are emitted as `vector` nodes — export the asset separately
  (`/images` endpoint) rather than reconstructing paths.
- Raster `image` nodes carry `image.ref` (the Figma `imageRef`); the tool resolves
  `image.src` to a download URL via the file image-fills endpoint
  (`/v1/files/:key/images`). If that call is unavailable, `src` stays `null` and the
  caller supplies the asset — bind components to `image.src`, not a bare URL.

# scripts/figma — Figma → manifest, tokens, assets

Shared tooling behind every platform's `*-figma-to-code` skill.

| Tool | Role |
|---|---|
| `figma_export.py` | Figma frame → `manifest.json` (normalized UI tree) + `tokens.json` (DTCG design tokens) |
| `figma_images.py` | manifest → `assets/` (icons as svg, raster images as **webp**) + `--frames` per-screen PNG renders |
| `figma_token.py` | check / save (hidden input) / clear the persisted access token |

Stdlib only (`urllib`) — no `pip install`. Python 3.9+. The one external
helper: webp conversion in `figma_images.py` shells out to `cwebp`
(`brew install webp`), with Pillow as an optional fallback.

## figma_export — manifest + design tokens

Turns a Figma frame into two **platform-agnostic, reproducible** artifacts that
per-platform emitters map to code:

| Output | What it is |
|---|---|
| `manifest.json` | Normalized UI tree. Auto-layout → `direction`/`gap`/`padding`, sizing → `fixed`/`fill`/`hug`, component instances → `{component, props}`, text → content + type style. |
| `tokens.json` | Design tokens in [W3C DTCG](https://tr.designtokens.org/format/) format (`color` / `dimension` / `typography`), from Figma **variables** when the plan exposes them, else from published **styles**. |

```bash
export FIGMA_TOKEN=figd_xxxxxxxx          # or: python3 scripts/figma/figma_token.py --save
python3 scripts/figma/figma_export.py --file <FILE_KEY> --node <NODE_ID> --out ./out
```

`FILE_KEY` and `NODE_ID` come straight from a Figma URL:

```
https://www.figma.com/design/<FILE_KEY>/Name?node-id=<NODE_ID>
```

The URL's `node-id` uses `-` (e.g. `12-345`); the tool accepts that or the API's
`:` form. Omit `--node` to export the top-level frames of the first page.

`--out` is confined to the working tree (writes outside it are rejected); the
emitted `manifest.json`/`tokens.json` contain design data only, never the token.

## figma_images — assets + frame renders

The manifest records *which* nodes need binary assets; the image-fill `src`
URLs figma_export resolves are **signed and expire**. `figma_images.py` renders
those nodes through the Figma images API into durable local files the platform
skills wire in:

```bash
# icons/images referenced by the manifest -> ./out/assets/ + assets-index.json
python3 scripts/figma/figma_images.py --manifest ./out/manifest.json

# per-screen PNG renders -> ./out/frames/ + frames-index.json
# (visual reference for scope confirmation — never an implementation source)
python3 scripts/figma/figma_images.py --manifest ./out/manifest.json --frames

# offline: list asset candidates without a token or network
python3 scripts/figma/figma_images.py --manifest ./out/manifest.json --list
```

Asset candidates are `image` nodes (raster fills), `vector` nodes and small
icon-named containers (exported whole as `svg`), and nodes the designer flagged
for export in Figma (`exportHint` in the manifest). A matched node absorbs its
subtree — one export per asset, no double-rendering of children.

**Raster assets ship as WebP, not PNG** — PNG straight into the app bundle
inflates install size. The Figma images API can't emit webp, so the tool
renders png and converts locally via `cwebp` (`brew install webp`) or Pillow;
without an encoder it falls back to png with a warning (`--format webp` makes
the missing encoder a hard error, `--format png` opts out). Frames stay PNG —
they are a visual reference for scope confirmation, never shipped. The
`assets-index.json` / `frames-index.json` files map node ids to files; bind
components to the index entries, not to expiring URLs. Partial download
failures are recorded in the index, not fatal.

## figma_token — access token management

Every script resolves the token as: `$FIGMA_TOKEN` env var first, then the
`~/.figma-token` file (chmod 600, overridable via `FIGMA_TOKEN_FILE`).

```bash
python3 scripts/figma/figma_token.py --check   # is a token resolvable? (never prints it)
python3 scripts/figma/figma_token.py --save    # prompt with hidden input, persist to ~/.figma-token
python3 scripts/figma/figma_token.py --clear   # delete the token file
```

`--save` reads stdin when piped (`printf '%s' "$TOKEN" | … --save`), so the
token never lands in shell history. The token needs only **read** scope
(`file:read`) — it is never echoed, logged, or written anywhere except the
600-permission token file. Never commit it.

## Offline self-checks

```bash
python3 scripts/figma/figma_export.py --demo     # normalizes a bundled sample, asserts output → "OK"
python3 scripts/figma/figma_images.py --demo     # asserts candidate collection on a sample manifest
```

No token or network needed — these are the tools' regression tests.

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
skipped). `exportHint: true` marks a node the designer flagged for export
(Figma export settings) — `figma_images.py` treats it as an asset. Each platform
skill documents how it maps these to its widgets and theme.

## Notes / limits

- Variables API (`/variables/local`) is Enterprise-only; the tool falls back to
  published styles automatically. Variable **aliases** and BOOLEAN vars are skipped
  in the baseline — extend `tokens_from_variables` if you need them.
- Absolute-positioned children (`direction: none`) carry size but no flow; treat
  them as overlay/`Stack` at the use site.
- Vectors/icons are emitted as `vector` nodes — export the binary with
  `figma_images.py` rather than reconstructing paths.
- Raster `image` nodes carry `image.ref` (the Figma `imageRef`); the tool resolves
  `image.src` to a download URL via the file image-fills endpoint
  (`/v1/files/:key/images`). Those URLs expire — for anything that outlives the
  session, export durable files with `figma_images.py` and bind to
  `assets-index.json` entries instead.

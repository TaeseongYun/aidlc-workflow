---
name: frontend-figma-to-code
description: Frontend (web) Figma → code pipeline. Turn a Figma frame into React/Next components and design-token theme via a reproducible manifest, using the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→component mapping (frame/stack→flex, text→semantic element, instance→design-system component, image→next/image), token→theme mapping (DTCG color/dimension/typography → Tailwind theme / CSS variables), auto-layout→flex, fill/hug sizing, and the rule that generated code is a starting point that must still pass frontend-accessibility and frontend-security before merge. Use when generating UI from Figma, wiring design tokens, or reviewing Figma-derived components.
when_to_use: When converting a Figma design/frame into web components, setting up or updating design tokens from Figma, running the figma_export tool, or reviewing code generated/derived from Figma. Also for "figma to react", "figma to code", "design tokens", "generate component from design".
paths: **/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/manifest.json, **/theme/**/*.ts, **/tailwind.config.*
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# frontend-figma-to-code

Pipeline for turning a Figma frame into web components + a token-driven theme,
reproducibly. Built on the shared extractor
[`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md): Figma REST
API + token → a platform-agnostic `manifest.json` and DTCG `tokens.json`, which
this skill maps to React/Next + your styling system. Project `ctx/` overrides this
document. Deep-dive (worked example, per-node code, token transform) lives in
[reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to components, mapping
  DTCG tokens to the theme, and the review rules for Figma-derived code.
- Covers: node→component and token→theme mapping, layout translation
  (auto-layout→flex), regenerate-safe output.
- Doesn't cover: where generated files live → [frontend-module-structure]; wiring
  data/behavior into the shell → [frontend-architecture] / [frontend-api-contract];
  **the two safety floors generated code must still pass** →
  [frontend-accessibility] and [frontend-security].

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (Tailwind theme / CSS variables)   [do this first]
3. Components manifest.json tree  →  React components (layout + token refs)
4. Wire      add semantics (a11y), data/behavior, then review vs the safety floors
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → the theme first, then have
  components reference theme values. A node with `fillToken: true` or a text style
  emits a **token reference**, never the resolved raw hex/px.
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. Output must pass
  [frontend-accessibility] (semantic element per role, `alt`, labels, focus/keyboard)
  and [frontend-security] before merge.
- **Map instances to existing design-system components.** A manifest `instance`
  (e.g. `PrimaryButton`) → your library's `<Button>`, not re-created markup
  ([frontend-module-structure]: one component library).
- **Layout from the manifest's layout**, not absolute pixels: `direction`/`gap`/
  `padding` → flex; `widthMode: fill`→`w-full`, `hug`→`w-fit`. Ignore absolute
  x/y except for genuine overlays.
- **Keep output regenerate-safe.** Generated components live in a dedicated dir;
  behavior/data go in wrappers. Re-run the extractor when the design changes rather
  than hand-patching generated files.

Don't:

- Paste raw hex/px pulled from Figma into components — it breaks theming and dark
  mode. Extend the token/theme instead.
- Emit `<div onClick>` for what is a button/link — a Figma frame has no role
  ([frontend-accessibility]).
- Rebuild a design-system component as ad-hoc markup instead of referencing it.
- Dump absolutely-positioned, fixed-`w`/`h` nodes as the layout (breaks responsive).
- Render Figma text via `dangerouslySetInnerHTML`, or copy a Figma-embedded URL /
  key / secret into code ([frontend-security]).
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → component mapping

| manifest node | Web output |
|---|---|
| `stack` (column/row) | `<div className="flex flex-col/flex-row" gap/padding from layout>` (or a `<Stack>` primitive) |
| `frame` (direction none) | `<div className="relative">` — children are overlays |
| `text` | semantic element by role (`<h1..h6>/<p>/<span>/<label>`) + type-token class → [frontend-accessibility] |
| `instance` | the design-system component named by `component.name`, `props` from `component.props` |
| `image` | `next/image` or `<img>` with **required `alt`** |
| `rect` | styled `<div>` (bg/border/radius from tokens) |
| `vector` | inline SVG / icon component (export the asset, don't reconstruct paths) |

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | Tailwind `theme.colors.*` / CSS custom property (`--color-*`) |
| `dimension` | spacing/size scale (`theme.spacing.*`) |
| `typography` | a text-style utility / typography token (family, size, weight, line-height) |

One styling system only ([frontend-module-structure]) — map tokens into it, don't
add a second.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire data/behavior by hand |
| A reused design-system component (button, card) | reference the existing component; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the token/theme module only |
| Pixel-exact one-off (marketing) | generate as a starting point; expect manual polish |
| Complex interaction / animation / state | hand-build — the manifest gives layout only |

## Refactor / red-flag signals

- Raw hex/px literals in a generated component instead of token references.
- `<div onClick>` / non-semantic output where the node is a control.
- Absolute-positioned, fixed-size generated layout.
- Duplicated markup where a design-system component already exists.
- A Figma text string rendered through `dangerouslySetInnerHTML`.
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Safety floors generated code must pass: [frontend-accessibility](../frontend-accessibility/SKILL.md), [frontend-security](../frontend-security/SKILL.md)
- Adjacent: [frontend-module-structure](../frontend-module-structure/SKILL.md), [frontend-api-contract](../frontend-api-contract/SKILL.md)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

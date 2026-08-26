---
name: android-figma-to-code
description: Android (Jetpack Compose) Figma → code pipeline. Turn a Figma frame into Compose composables and a token-driven theme via a reproducible manifest, using the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→composable mapping (stack→Column/Row, frame→Box, text→Text with MaterialTheme.typography, instance→composable, image→AsyncImage), token→theme mapping (DTCG color/dimension/typography → ColorScheme/Typography/dp scale / designsystem tokens), auto-layout→Arrangement/Modifier, fill/hug sizing, and the rule that generated code must reference designsystem tokens/resources not literals and still pass android-security before merge. Use when generating UI from Figma, wiring design tokens, or reviewing Figma-derived composables. Also for "figma to compose", "figma to code", "design tokens", "generate composable".
when_to_use: When converting a Figma design/frame into Compose composables, setting up or updating design tokens from Figma, running the figma_export tool, or reviewing code generated/derived from Figma. Also for "figma to compose", "figma to code", "design tokens", "generate composable from design".
paths: **/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/ui/theme/**/*.kt, **/designsystem/**/*.kt, **/*Theme.kt
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# android-figma-to-code

Pipeline for turning a Figma frame into Compose composables + a token-driven theme,
reproducibly. Built on the shared extractor
[`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md): Figma REST
API + token → a platform-agnostic `manifest.json` and DTCG `tokens.json`, which
this skill maps to Jetpack Compose + your `core/designsystem` theme. Project `ctx/`
overrides this document. Deep-dive (worked example, per-node code, token transform)
lives in [reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to composables, mapping
  DTCG tokens to the theme, and the review rules for Figma-derived code.
- Covers: node→composable and token→theme mapping, layout translation
  (auto-layout→`Arrangement`/`Modifier`), regenerate-safe output.
- Doesn't cover: where generated files live → [android-module-structure]; wiring
  state/behavior into the screen → [android-viewmodel-state] / [android-architecture];
  **the safety floor generated code must still pass** → [android-security].

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (ColorScheme / Typography / dp scale)   [do this first]
3. Composables manifest.json tree  →  @Composable functions (layout + token refs)
4. Wire      add contentDescription (a11y), state/behavior, then review vs the safety floor
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → the theme first, then have
  composables reference `MaterialTheme.*` / designsystem token values. A node with
  `fillToken: true` or a text style emits a **token reference**, never the resolved
  raw hex/px.
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. Output must reference
  string/dimension/color resources (guidance.md: no literals in feature composables)
  and pass [android-security] before merge.
- **Map instances to existing designsystem composables.** A manifest `instance`
  (e.g. `PrimaryButton`) → your `core/designsystem` composable, not re-created
  layout ([android-module-structure]: one designsystem module).
- **Layout from the manifest's layout**, not absolute pixels: `direction`/`gap`/
  `padding` → `Column`/`Row` + `Arrangement.spacedBy`/`Modifier.padding`;
  `widthMode: fill`→`fillMaxWidth()`, `hug`→`wrapContentWidth()`. Ignore absolute
  x/y except for genuine overlays (`Box`).
- **Keep output regenerate-safe.** Generated composables live in a dedicated dir;
  state/behavior go in the screen/ViewModel. Re-run the extractor when the design
  changes rather than hand-patching generated files.

Don't:

- Paste raw hex/px pulled from Figma into composables — it breaks theming and dark
  mode. Extend the token/theme instead.
- Emit a plain `Box`/`Text` with a `Modifier.clickable` for what is a real button —
  a Figma frame has no role; use the designsystem control + `contentDescription`.
- Rebuild a designsystem composable as ad-hoc `Column`/`Row` markup instead of
  referencing it.
- Dump fixed-`.width(320.dp)`/absolute-offset nodes as the layout (breaks adaptive
  sizing and different screen widths).
- Hardcode a user-facing string or a Figma-embedded URL / key / secret into a
  composable ([android-security]); strings come from resources / are passed in.
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → composable mapping

| manifest node | Compose output |
|---|---|
| `stack` (column/row) | `Column`/`Row` — `gap`→`Arrangement.spacedBy(8.dp)`, `padding`→`Modifier.padding(...)`, `align`→`horizontalAlignment`/`verticalAlignment`, `justify`→`Arrangement.*` |
| `frame` (direction none) | `Box` — children placed as overlays |
| `text` | `Text(...)` with `MaterialTheme.typography.*` (or a designsystem type token); color from a theme token, **not** a raw hex; string from resources / passed in → [android-security] |
| `instance` | the composable named by `component.name` (e.g. `PrimaryButton`), args from `component.props` |
| `image` | `AsyncImage`/`Image` with **`contentDescription`** (decorative → `null`) |
| `rect` | `Box` with `Modifier.background(...).clip(RoundedCornerShape(...))`/`.border(...)` from tokens |
| `vector` | `Icon`/`painterResource` — exported asset, don't reconstruct paths |

Sizing: `fill`→`Modifier.fillMaxWidth()`/`weight(1f)`, `hug`→`wrapContentWidth/Height`,
`fixed`→ a token dp (avoid raw px→dp literals).

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | Compose `ColorScheme` / a designsystem color token |
| `dimension` | a `dp` scale (designsystem spacing/size token) |
| `typography` | a `Typography` style (family, size, weight, line-height) |

One theme only ([android-module-structure]: `core/designsystem`) — map tokens into
it, don't add a second palette.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire state/behavior in the ViewModel by hand |
| A reused designsystem composable (button, card) | reference the existing composable; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the token/theme module only |
| Pixel-exact one-off (marketing) | generate as a starting point; expect manual polish |
| Complex interaction / animation / state | hand-build — the manifest gives layout only |

## Refactor / red-flag signals

- Raw hex/px literals in a generated composable instead of token/resource references.
- `Box`+`clickable` / non-semantic output where the node is a real control.
- Fixed-`.width()`/absolute-offset generated layout.
- Duplicated `Column`/`Row` markup where a designsystem composable already exists.
- A user-facing string hardcoded instead of coming from a string resource.
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [android-architecture](../android-architecture/SKILL.md)
- Safety floor generated code must pass: [android-security](../android-security/SKILL.md)
- Adjacent: [android-module-structure](../android-module-structure/SKILL.md) (where generated composables/designsystem tokens live), [android-viewmodel-state](../android-viewmodel-state/SKILL.md) (wire state/behavior)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

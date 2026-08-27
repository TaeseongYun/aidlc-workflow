---
name: kmp-figma-to-code
description: KMP (Kotlin Multiplatform) Figma → code pipeline. Turn a Figma frame into Compose Multiplatform composables and a token-driven Material3 theme via a reproducible manifest, using the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→composable mapping (stack→Column/Row, frame→Box with absolute children, text→Text with MaterialTheme.typography, instance→named composable, image→AsyncImage/Image with contentDescription), token→theme mapping (DTCG color/dimension/typography → ColorScheme/custom CompositionLocals/Typography), auto-layout→Column/Row, fill/hug sizing via Modifier.fillMaxWidth/wrapContentSize, and the rule that generated code is a starting point that must still pass kmp-security before merge. Use when generating composables from Figma, wiring design tokens, or reviewing Figma-derived composables. Also for "figma to compose", "figma to code", "design tokens", "generate composable from design".
when_to_use: When converting a Figma design/frame into Compose Multiplatform composables, setting up or updating design tokens (ColorScheme/Typography/CompositionLocals) from Figma, running the figma_export tool, or reviewing composables generated/derived from Figma. Also for "figma to compose", "figma to kmp", "design tokens", "generate composable".
paths: "**/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/*Theme*.kt, **/theme/**/*.kt, **/design_system/**/*.kt, **/ui/**/*.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# kmp-figma-to-code

Pipeline for turning a Figma frame into Compose Multiplatform composables + a
token-driven Material3 theme, reproducibly. Built on the shared extractor
[`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md): Figma REST
API + token → a platform-agnostic `manifest.json` and DTCG `tokens.json`, which
this skill maps to `@Composable` functions + your `MaterialTheme` (`ColorScheme`,
`Typography`, and custom `CompositionLocal` scales such as `LocalSpacing`). Project
`ctx/` overrides this document. Deep-dive (worked example, per-node code, token
transform) lives in [reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to composables, mapping DTCG
  tokens to the theme, and the review rules for Figma-derived Kotlin.
- Covers: node→composable and token→theme mapping, layout translation
  (auto-layout→`Column`/`Row`), `Modifier` sizing, no-literals output, regenerate-safe files.
- Doesn't cover: where generated files live → [kmp-module-structure](../kmp-module-structure/SKILL.md);
  wiring state/behavior → [kmp-architecture](../kmp-architecture/SKILL.md) / [kmp-state-management](../kmp-state-management/SKILL.md);
  **the safety floor generated code must still pass** → [kmp-security](../kmp-security/SKILL.md).

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (ColorScheme / Typography / LocalSpacing CompositionLocal)  [do this first]
3. Composables  manifest.json tree  →  @Composable functions (layout + theme refs, stable data classes)
4. Wire      add Modifier.semantics, state/behavior, then review vs the safety floor
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → the theme first, then have
  composables read theme values (`MaterialTheme.colorScheme`, `MaterialTheme.typography`,
  `LocalSpacing.current`). A node with `fillToken: true` or a text style emits a
  **theme reference**, never a resolved `Color(0xFF…)` / raw dp literal
  ([kmp-design-system](../kmp-design-system/SKILL.md): no literals).
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. Output must pass
  [kmp-security](../kmp-security/SKILL.md) before merge.
- **Map instances to existing design-system composables.** A manifest `instance`
  (e.g. `PrimaryButton`) → your library's composable, not re-created `Box`/`Row` markup
  ([kmp-module-structure](../kmp-module-structure/SKILL.md): one design_system module).
- **Layout from the manifest's layout**, not absolute pixels: `direction`→`Column`/
  `Row`, `gap`→`Spacer`/`Arrangement.spacedBy`, `padding`→`Modifier.padding(…)`;
  `widthMode: fill`→`Modifier.fillMaxWidth()`, `hug`→`wrapContentSize()` /
  `Arrangement` without weight. Ignore absolute x/y except for genuine overlays.
- **Keep output regenerate-safe.** Generated composables live in a dedicated dir;
  state/behavior go in wrappers. Re-run the extractor when the design changes rather
  than hand-patching generated files.

Don't:

- Paste raw `Color(0xFF…)` / hardcoded dp values pulled from Figma into composables — it
  breaks theming and dark mode. Extend the token/theme instead.
- Emit a tappable `Box`/`Row` with `clickable` modifier for what is a button — a Figma
  frame has no role; use the design-system composable or add `Modifier.semantics { role = Role.Button }`.
- Rebuild a design-system composable as ad-hoc `Box`/`Column` markup instead of
  referencing it.
- Dump absolutely-positioned, fixed-size children as the layout (breaks responsiveness)
  — reserve `Box` with absolute positioning for real overlays.
- Copy a Figma-embedded URL / key / secret into code ([kmp-security](../kmp-security/SKILL.md)).
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → composable mapping

| manifest node | Compose Multiplatform output |
|---|---|
| `stack` (column/row) | `Column`/`Row` — `gap`→`Arrangement.spacedBy(LocalSpacing.current.sm)`; `padding`→`Modifier.padding(…)`; `align`→`horizontalAlignment`/`verticalAlignment` |
| `frame` (direction none) | `Box` — children use `Modifier.align(Alignment.*)` for overlays only |
| `text` | `Text(…, style = MaterialTheme.typography.*)` (or a type token) — no raw hex/size |
| `instance` | the composable named by `component.name` (e.g. `PrimaryButton`); params from `component.props` |
| `image` | `AsyncImage` (Coil) or `Image` with `contentDescription` (decorative → `contentDescription = null`) |
| `rect` | `Box(modifier = Modifier.background(color, shape))` with color/shape from theme/`CompositionLocal` |
| `vector` | `Icon` from the icon set / `painterResource` for SVG — never reconstruct paths |

Sizing: `fill`→`Modifier.fillMaxWidth()`/`fillMaxHeight()`; `hug`→`wrapContentSize()` /
intrinsic; `fixed`→ a token dimension (`LocalSpacing.current.md`, not raw dp).

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | `ColorScheme` entry / a custom `CompositionLocal<Color>` set |
| `dimension` | a `CompositionLocal<Dp>` spacing scale (e.g. `LocalSpacing`) |
| `typography` | `Typography` / `TextStyle` entry (family, size, weight, lineHeight) |

One theme only ([kmp-module-structure](../kmp-module-structure/SKILL.md)) — map tokens into
`MaterialTheme`, don't add a second palette. Dark mode comes from token **modes** →
`darkColorScheme`, not a hardcoded second palette.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire state/behavior by hand |
| A reused design-system composable (button, card) | reference the existing composable; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the theme/`CompositionLocal` only |
| Pixel-exact one-off (marketing) | generate as a starting point; expect manual polish |
| Complex interaction / animation / state | hand-build — the manifest gives layout only |

## Refactor / red-flag signals

- Raw `Color(0xFF…)` / hardcoded dp literals in a generated composable instead of theme refs.
- Tappable `Box`/`Row` with `.clickable` and no `Modifier.semantics { role = Role.Button }`.
- Absolute-positioned, fixed-size children used as the whole layout.
- Duplicated `Box`/`Column` markup where a design-system composable already exists.
- Unstable lambda captures causing unnecessary recomposition ([kmp-performance](../kmp-performance/SKILL.md)).
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Safety floor generated code must pass: [kmp-security](../kmp-security/SKILL.md)
- Adjacent: [kmp-performance](../kmp-performance/SKILL.md) (stability, no literals), [kmp-module-structure](../kmp-module-structure/SKILL.md) (where generated composables/design_system live)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

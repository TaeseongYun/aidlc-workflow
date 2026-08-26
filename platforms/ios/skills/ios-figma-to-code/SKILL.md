---
name: ios-figma-to-code
description: iOS (SwiftUI) Figma → code pipeline. Turn a Figma frame into SwiftUI views and a token-driven theme via a reproducible manifest, using the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→view mapping (stack→VStack/HStack, frame→ZStack, text→Text with a font token, instance→a named View, image→Image/AsyncImage), token→theme mapping (DTCG color→asset-catalog color set / a Color token, dimension→a spacing enum, typography→a Font token), auto-layout→stack spacing/padding, fill/hug sizing, and the rule that generated code is a starting point that must still pass ios-security before merge. Use when generating a view from Figma, wiring design tokens, or reviewing Figma-derived views. Also for "figma to swiftui", "design tokens", "generate view".
when_to_use: When converting a Figma design/frame into SwiftUI views, setting up or updating design tokens (asset-catalog color sets / a Theme enum) from Figma, running the figma_export tool, or reviewing code generated/derived from Figma. Also for "figma to swiftui", "figma to code", "design tokens", "generate view from design".
paths: **/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/*Theme.swift, **/DesignSystem/**/*.swift, **/*.xcassets/**
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# ios-figma-to-code

Pipeline for turning a Figma frame into SwiftUI views + a token-driven theme,
reproducibly. Built on the shared extractor
[`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md): Figma REST
API + token → a platform-agnostic `manifest.json` and DTCG `tokens.json`, which
this skill maps to SwiftUI + your design-system package. Project `ctx/` overrides
this document. Deep-dive (worked example, per-node code, token transform) lives in
[reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to views, mapping DTCG
  tokens to the theme, and the review rules for Figma-derived code.
- Covers: node→view and token→theme mapping, layout translation
  (auto-layout→stack spacing/padding), regenerate-safe output.
- Doesn't cover: where generated files live → [ios-module-structure] (the
  `DesignSystem` SPM package); wiring data/behavior into the view →
  [ios-state-concurrency] (`@Observable` state); **the safety floor generated code
  must still pass** → [ios-security].

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (asset-catalog color sets / a Theme enum)   [do this first]
3. Views     manifest.json tree  →  SwiftUI views (layout + token refs)
4. Wire      add accessibility, @Observable state/behavior, then review vs the safety floor
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → the theme first, then have
  views reference theme values. A node with `fillToken: true` or a text style emits
  a **token reference** (`Color("Surface")` / `Spacing.md` / a `Font` token), never
  the resolved raw hex/px.
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. Output must pass
  [ios-security] before merge (no embedded secrets/URLs copied from the frame, no
  raw hex leaking a design system).
- **Map instances to existing design-system views.** A manifest `instance`
  (e.g. `PrimaryButton`) → your package's `PrimaryButton` view, not re-created
  markup ([ios-module-structure]: one `DesignSystem` package).
- **Layout from the manifest's layout**, not absolute pixels: `direction`→
  `VStack`/`HStack`/`ZStack`, `gap`→ the `spacing:` param, `padding`→
  `.padding(...)`, `align`→ the stack alignment; `widthMode: fill`→
  `.frame(maxWidth: .infinity)`, `hug`→ intrinsic (no frame). Ignore absolute x/y
  except for genuine overlays.
- **Keep output regenerate-safe.** Generated views live in a dedicated dir of the
  `DesignSystem` package; behavior/data go in wrappers. Re-run the extractor when
  the design changes rather than hand-patching generated files.

Don't:

- Paste raw hex/`CGFloat` literals pulled from Figma into views — it breaks theming
  and dark mode. Extend the token/theme instead (asset-catalog color set /
  `Spacing`/`Font` token).
- Emit a tappable `Text`/`Image` where the node is a button — a Figma frame has no
  role; use a `Button` and give it an accessibility label.
- Rebuild a design-system view as ad-hoc SwiftUI instead of referencing it.
- Dump absolutely-positioned, fixed-`.frame(width:height:)` nodes as the layout
  (breaks Dynamic Type and adaptive sizing).
- Copy a Figma-embedded URL / key / secret into code ([ios-security]).
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → SwiftUI mapping

| manifest node | SwiftUI output |
|---|---|
| `stack` (column) | `VStack(alignment:, spacing:)` — `spacing:` from `gap`, `.padding(...)` from `padding`, `alignment:` from `align` |
| `stack` (row) | `HStack(alignment:, spacing:)` — same params |
| `frame` (direction none) | `ZStack` — children are overlays |
| `text` | `Text(...).font(<font token>)` with color from a token (`Color("...")` or a `Theme` enum) — **not** a raw hex |
| `instance` | the SwiftUI view named by `component.name` (e.g. `PrimaryButton`); props from `component.props` |
| `image` | `Image`/`AsyncImage` with `.accessibilityLabel(...)` (decorative → `.accessibilityHidden(true)`) |
| `rect` | `RoundedRectangle(cornerRadius:)` / `.background(...)` / `.overlay` border, all from tokens |
| `vector` | SF Symbol (`Image(systemName:)`) or an exported asset-catalog image (don't reconstruct paths) |

Sizing: `fill`→`.frame(maxWidth: .infinity)`, `hug`→ intrinsic (no frame),
`fixed`→ a token dimension (avoid raw `CGFloat` literals scattered through views).

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | an asset-catalog color set (`Color("Surface")`) or a `Color` token enum (`Theme.surface`) |
| `dimension` | a spacing enum (`Spacing.md`) |
| `typography` | a `Font` token (`Theme.headline` / `.font(.custom(...))`) |

One theme surface only ([ios-module-structure]: `DesignSystem`) — map tokens into
it, don't add a second palette.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire `@Observable` state/behavior by hand |
| A reused design-system view (button, card) | reference the existing view; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the color set / `Theme` module only |
| Pixel-exact one-off (marketing) | generate as a starting point; expect manual polish |
| Complex interaction / animation / state | hand-build — the manifest gives layout only |

## Refactor / red-flag signals

- Raw hex / `CGFloat` literals in a generated view instead of token references.
- A tappable `Text`/`Image` where the node is a control (should be a `Button`).
- Absolute-positioned, fixed-`.frame(width:height:)` generated layout.
- Duplicated SwiftUI where a design-system view already exists.
- A second hardcoded dark palette instead of asset-catalog appearances / token modes.
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Safety floor generated code must pass: [ios-security](../ios-security/SKILL.md)
- Adjacent: [ios-module-structure](../ios-module-structure/SKILL.md) (the `DesignSystem` SPM package, where generated views live), [ios-state-concurrency](../ios-state-concurrency/SKILL.md) (wire `@Observable` state)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

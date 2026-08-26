---
name: flutter-figma-to-code
description: Flutter (Dart) Figma → code pipeline. Turn a Figma frame into Flutter widgets and a token-driven theme via a reproducible manifest, using the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→widget mapping (stack→Column/Row, frame→Stack, text→Text with Theme textTheme, instance→named widget, image→Image.network), token→theme mapping (DTCG color/dimension/typography → ColorScheme/TextTheme/ThemeExtension spacing), auto-layout→Column/Row, fill/hug sizing, `const` + no-literals conventions (matching flutter-widget-performance), and the rule that generated code is a starting point that must still pass flutter-security before merge. Use when generating widgets from Figma, wiring design tokens, or reviewing Figma-derived widgets. Also for "figma to flutter", "figma to code", "design tokens", "generate widget from design".
when_to_use: When converting a Figma design/frame into Flutter widgets, setting up or updating design tokens (ColorScheme/TextTheme/ThemeExtension) from Figma, running the figma_export tool, or reviewing widgets generated/derived from Figma. Also for "figma to flutter", "figma to code", "design tokens", "generate widget".
paths: **/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/*_theme.dart, **/theme/**/*.dart, **/design_system/**/*.dart
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# flutter-figma-to-code

Pipeline for turning a Figma frame into Flutter widgets + a token-driven theme,
reproducibly. Built on the shared extractor
[`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md): Figma REST
API + token → a platform-agnostic `manifest.json` and DTCG `tokens.json`, which
this skill maps to Flutter widgets + your `ThemeData` (`ColorScheme`, `TextTheme`,
a spacing `ThemeExtension`). Project `ctx/` overrides this document. Deep-dive
(worked example, per-node code, token transform) lives in [reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to widgets, mapping DTCG
  tokens to the theme, and the review rules for Figma-derived Dart.
- Covers: node→widget and token→theme mapping, layout translation
  (auto-layout→`Column`/`Row`), `const` + no-literals output, regenerate-safe files.
- Doesn't cover: where generated files live → [flutter-module-structure]; wiring
  state/behavior into the shell → [flutter-architecture] / [flutter-state-management];
  **the safety floor generated code must still pass** → [flutter-security].

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (ColorScheme / TextTheme / spacing ThemeExtension)  [do this first]
3. Widgets   manifest.json tree  →  Flutter widgets (layout + theme refs, const where static)
4. Wire      add semantics, state/behavior, then review vs the safety floor
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → the theme first, then have
  widgets read theme values (`Theme.of(context)`, `context.spacing`). A node with
  `fillToken: true` or a text style emits a **theme reference**, never a resolved
  `Color(0xFF…)` / raw size ([flutter-widget-performance]: no literals).
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. Output must pass
  [flutter-security] before merge.
- **Map instances to existing design-system widgets.** A manifest `instance`
  (e.g. `PrimaryButton`) → your library's widget, not re-created `Container` markup
  ([flutter-module-structure]: one design_system).
- **Layout from the manifest's layout**, not absolute pixels: `direction`→`Column`/
  `Row`, `gap`→`SizedBox`/`spacing:`, `padding`→`Padding(EdgeInsets…)`;
  `widthMode: fill`→`Expanded`/`double.infinity`, `hug`→`MainAxisSize.min`. Ignore
  absolute x/y except for genuine overlays.
- **`const` static subtrees.** Leaf/static widgets get `const` constructors so they
  skip rebuilds ([flutter-widget-performance]).
- **Keep output regenerate-safe.** Generated widgets live in a dedicated dir;
  state/behavior go in wrappers. Re-run the extractor when the design changes rather
  than hand-patching generated files.

Don't:

- Paste raw `Color(0xFF…)` / hardcoded sizes pulled from Figma into widgets — it
  breaks theming and dark mode. Extend the token/theme instead.
- Emit a tappable `GestureDetector`/`Container` for what is a button — a Figma frame
  has no role; use the design-system widget or a `Semantics`-labelled control.
- Rebuild a design-system widget as ad-hoc `Container`/`Column` markup instead of
  referencing it.
- Dump absolutely-positioned, fixed-size `Positioned` nodes as the layout (breaks
  responsiveness) — reserve `Stack`/`Positioned` for real overlays.
- Copy a Figma-embedded URL / key / secret into code ([flutter-security]).
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → widget mapping

| manifest node | Flutter output |
|---|---|
| `stack` (column/row) | `Column`/`Row` — `gap`→`SizedBox`/`spacing:` (Flutter 3.27+) or a `Gap`; `padding`→`Padding`; `align`→`crossAxisAlignment`/`mainAxisAlignment` |
| `frame` (direction none) | `Stack` — children are `Positioned` overlays only |
| `text` | `Text(…, style: Theme.of(context).textTheme.*)` (or a type token) — no raw hex/size |
| `instance` | the widget named by `component.name` (e.g. `PrimaryButton`); params from `component.props` |
| `image` | `Image.network`/`CachedNetworkImage` with `semanticLabel` (decorative → `excludeFromSemantics: true`) |
| `rect` | `Container`/`DecoratedBox` with `BoxDecoration(color, borderRadius, border)` from theme/`ThemeExtension` |
| `vector` | `flutter_svg` / `Icon` (export the asset, don't reconstruct paths) |

Sizing: `fill`→`Expanded`/`double.infinity`; `hug`→`mainAxisSize: MainAxisSize.min`
/ intrinsic; `fixed`→ a token dimension (via `context.spacing`, not raw px).

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | `ColorScheme` entry / a color `ThemeExtension` set |
| `dimension` | a spacing `ThemeExtension` (`context.spacing.*`, matching [flutter-widget-performance]) |
| `typography` | `TextTheme` entry (family, size, weight, height) |

One theme only ([flutter-module-structure]) — map tokens into `ThemeData`, don't add
a second palette. Dark mode comes from token **modes** → `ThemeData.dark`, not a
hardcoded second palette.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire state/behavior by hand |
| A reused design-system widget (button, card) | reference the existing widget; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the theme/`ThemeExtension` only |
| Pixel-exact one-off (marketing) | generate as a starting point; expect manual polish |
| Complex interaction / animation / state | hand-build — the manifest gives layout only |

## Refactor / red-flag signals

- Raw `Color(0xFF…)` / hardcoded sizes in a generated widget instead of theme refs.
- Tappable `Container`/`GestureDetector` where the node is a control (no `Semantics`).
- Absolute-positioned, fixed-size `Positioned` used as the whole layout.
- Duplicated `Container`/`Column` markup where a design-system widget already exists.
- Non-`const` leaf widgets that never change ([flutter-widget-performance]).
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Safety floor generated code must pass: [flutter-security](../flutter-security/SKILL.md)
- Adjacent: [flutter-widget-performance](../flutter-widget-performance/SKILL.md) (const, theme/spacing tokens, no literals), [flutter-module-structure](../flutter-module-structure/SKILL.md) (where generated widgets/design_system live)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

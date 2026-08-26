---
name: rn-figma-to-code
description: React Native (TS) Figma → code pipeline — the mobile delta on the web sibling frontend-figma-to-code. Turn a Figma frame into RN function components + a token-driven theme via the shared scripts/figma extractor (Figma REST API + token → normalized manifest.json + DTCG tokens.json). Covers node→RN mapping (stack→View flexDirection, text→Text, instance→design-system component, image→Image), token→theme mapping (DTCG color/dimension/typography → a typed theme object / StyleSheet, or NativeWind theme), and the RN deltas vs web: no DOM/CSS/className, StyleSheet objects not classes, flexDirection default column, flex not display, gap needs RN≥0.71. Accessibility folds in here (RN has no separate a11y skill) via accessibilityRole/accessibilityLabel; generated code is a starting point that must still pass rn-security before merge. Use when generating RN UI from Figma, wiring design tokens, or reviewing Figma-derived components. Also for "figma to react native", "figma to code", "design tokens".
when_to_use: When converting a Figma design/frame into React Native components, setting up or updating design tokens from Figma, running the figma_export tool, or reviewing code generated/derived from Figma for a mobile app. Also for "figma to react native", "figma to code", "design tokens", "generate component from design".
paths: **/tokens.json, **/*.tokens.json, **/design-tokens/**, **/figma*.json, **/theme/**/*.ts, **/*.styles.ts, **/*theme*.ts
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write
---

# rn-figma-to-code

Pipeline for turning a Figma frame into React Native (TS) components + a
token-driven theme, reproducibly. This is the **mobile delta** on the web sibling
[frontend-figma-to-code](../../../frontend/skills/frontend-figma-to-code/SKILL.md):
same extractor, same manifest/token contract, different emitter. Built on the
shared extractor [`scripts/figma/figma_export.py`](../../../../scripts/figma/README.md):
Figma REST API + token → a platform-agnostic `manifest.json` and DTCG
`tokens.json`, which this skill maps to RN `<View>`/`<Text>` + a `StyleSheet`
theme. Project `ctx/` overrides this document. Deep-dive (worked example,
per-node code, token transform) lives in [reference.md](./reference.md).

## Scope

- In scope: running the extractor, mapping the manifest to RN components, mapping
  DTCG tokens to a theme/StyleSheet, and the review rules for Figma-derived code.
- Covers: node→component and token→theme mapping, layout translation
  (auto-layout→flexbox), the **RN-vs-web deltas** (no DOM/CSS/className,
  StyleSheet), accessibility (roles/labels — folded in here), regenerate-safe output.
- Doesn't cover: where generated files live / one styling system →
  [rn-architecture]; wiring data/behavior into the shell →
  [rn-state-data]; list virtualization for generated lists →
  [rn-performance-ux]; **the safety floor generated code must still pass** →
  [rn-security].

## Pipeline (4 stages)

```
1. Extract   scripts/figma/figma_export.py --file KEY --node ID  →  manifest.json + tokens.json
2. Tokens    tokens.json (DTCG)  →  theme (typed theme object / StyleSheet tokens)   [do this first]
3. Components manifest.json tree  →  RN components (View/Text + StyleSheet.create)
4. Wire      add semantics (a11y roles/labels), data/behavior, then review vs rn-security
```

The manifest + tokens are the **reviewable diff** of a design change — commit them.

## Core rules

Do:

- **Tokens are the source of truth.** Map DTCG tokens → a theme object first, then
  have `StyleSheet` styles reference theme values. A node with `fillToken: true` or
  a text style emits a **token reference** (`theme.colors['surface']`), never the
  resolved raw hex/px.
- **Treat generated code as a starting point, not the deliverable.** Figma carries
  no notion of role, semantics, or safety — you add them. RN has no separate a11y
  skill, so the semantic/label rules live here: interactive and heading nodes get
  `accessibilityRole`, images/controls get `accessibilityLabel`. Output must pass
  [rn-security] before merge.
- **Map instances to existing design-system components.** A manifest `instance`
  (e.g. `PrimaryButton`) → your library's `<Button>`, not re-created markup
  ([rn-architecture]: one component library).
- **Layout from the manifest's layout**, not absolute pixels: `direction`/`gap`/
  `padding` → flexbox; `widthMode: fill`→`flex: 1`/`width: '100%'`, `hug`→ intrinsic
  (no explicit size). Ignore absolute x/y except for genuine overlays.
- **Keep output regenerate-safe.** Generated components live in a dedicated dir;
  behavior/data go in wrappers. Re-run the extractor when the design changes rather
  than hand-patching generated files.

Don't:

- Paste raw hex/px pulled from Figma into `StyleSheet` — it breaks theming and dark
  mode. Extend the token/theme instead.
- Use CSS/DOM habits: no `className`, no `display: flex`, no `%` where a prop wants
  a number. RN is flexbox-only with `StyleSheet` objects.
- Emit a `<View>` where the node is a control, with no `accessibilityRole` — a Figma
  frame has no role (fold a11y in here; see the web sibling for the shared principle).
- Dump absolutely-positioned, fixed-`width`/`height` nodes as the layout (breaks
  responsive across device sizes).
- Rebuild a design-system component as ad-hoc `<View>`/`<Text>` markup.
- Copy a Figma-embedded URL / key / secret into code ([rn-security]).
- Hand-edit a generated file in place, then lose the edit on the next export.

## Node → component mapping

| manifest node | RN output |
|---|---|
| `stack` (column) | `<View style={{ flexDirection: 'column', gap, padding, alignItems, justifyContent }}>` (RN default `flexDirection` is `'column'`) |
| `stack` (row) | `<View style={{ flexDirection: 'row', … }}>` |
| `frame` (direction none) | `<View style={{ position: 'relative' }}>` — children `position: 'absolute'` overlays |
| `text` | `<Text>` — RN has no semantic headings; add `accessibilityRole="header"` where the node is a heading. Type style from a theme token |
| `instance` | the design-system component named by `component.name`, `props` from `component.props` |
| `image` | `<Image>` (or `FastImage`) with `accessible` + `accessibilityLabel`; decorative → `accessibilityElementsHidden` |
| `rect` | `<View>` with `StyleSheet` (`backgroundColor`, `borderRadius`, `borderWidth`) from tokens |
| `vector` | `react-native-svg` / icon set (export the asset, don't reconstruct paths) |

Sizing: `fill`→`flex: 1` / `width: '100%'`; `hug`→ intrinsic (no explicit size);
`fixed`→ a token dimension (avoid raw px literals scattered through styles).

## Token → theme mapping

| DTCG `$type` | Theme target |
|---|---|
| `color` | `theme.colors['brand-primary']` (typed theme object; or NativeWind theme color) |
| `dimension` | spacing/size scale (`theme.space.md`) |
| `typography` | a text-style token (family, size, weight, lineHeight) applied in `StyleSheet` |

One styling system only ([rn-architecture]) — map tokens into the project's
convention (`StyleSheet`, styled-components, or NativeWind); don't add a second. No
Tailwind `className` by default in RN.

## Decision table

| Situation | Approach |
|---|---|
| New screen scaffold from a finalized frame | generate layout + tokens, then wire data/behavior by hand |
| A reused design-system component (button, card) | reference the existing component; don't regenerate |
| Only tokens changed (color/spacing/type) | re-run extractor → update the theme/token module only |
| A generated list of rows | wrap in `FlatList`/`FlashList` with stable keys → [rn-performance-ux] |
| Complex interaction / animation / state | hand-build — the manifest gives layout only → [rn-state-data] |

## Refactor / red-flag signals

- Raw hex/px literals in a generated `StyleSheet` instead of token references.
- CSS/DOM leakage: `className`, `display: flex`, `%` where a number is expected.
- Interactive/heading node output with no `accessibilityRole`/`accessibilityLabel`.
- Absolute-positioned, fixed-size generated layout.
- Duplicated `<View>`/`<Text>` markup where a design-system component already exists.
- A Figma-embedded URL/key/secret copied into code.
- Generated files hand-edited in place with no regenerate story.

## References

- Shared extractor: [`scripts/figma/`](../../../../scripts/figma/README.md)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Safety floor generated code must pass: [rn-security](../rn-security/SKILL.md)
- Adjacent: [rn-performance-ux](../rn-performance-ux/SKILL.md) (lists/memoization for generated lists), [rn-state-data](../rn-state-data/SKILL.md) (wire state)
- Web sibling (shared pipeline): [../../../frontend/skills/frontend-figma-to-code/SKILL.md](../../../frontend/skills/frontend-figma-to-code/SKILL.md)
- W3C DTCG token format: https://tr.designtokens.org/format/
- Figma REST API (files, nodes, variables): https://www.figma.com/developers/api
- Worked example, per-node code, token transform: [reference.md](./reference.md)

---
name: ios-design-system
description: iOS design-system consistency guard — reuse existing design tokens and components
  instead of reinventing them, and detect/block the off-system code AI commonly produces (hardcoded
  colors, magic spacing/size, ad-hoc typography, reinvented components, off-scale variants, inline
  styles bypassing the theme, dark-mode/theme breaks, duplicated icons/assets, ad-hoc radius/elevation,
  primitive-instead-of-semantic tokens). The enforcement pair to ios-figma-to-code. Auto-loads
  when writing or reviewing UI, themes, or tokens.
when_to_use: When building or reviewing SwiftUI views, wiring themes/tokens, reviewing Figma-derived
  components, or on requests like "does this match the design system", "use the tokens",
  "design consistency review", "check for hardcoded colors".
paths: "**/*.xcassets/**, **/Theme/**, **/DesignSystem/**, **/*Theme.swift, **/*.swift"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# ios-design-system — design-system consistency guard

AI-generated UI code — especially output from `ios-figma-to-code` — **reinvents
the design system instead of reusing it**: it hardcodes hex colors and magic
`CGFloat` numbers, builds a fifth bespoke `Button` when one already exists in the
`DesignSystem` package, and emits values that break in dark mode. The result is
drift: the same brand blue in six slightly-different shades, spacing that ignores
the scale, typography off the type ramp. This skill is a **guard** (detect/block
off-system code) plus **generation guidance** (reuse existing tokens + components).
It is the enforcement layer that makes `ios-figma-to-code` safe to ship: generated
UI must pass THIS skill before merge. Guard rules must not be relaxed. Project
`ctx/` overrides this document, but the design-system floor is never lowered.

## Scope

- Targets: SwiftUI source, asset-catalog color sets (`*.xcassets`), theme files
  (`*Theme.swift`), and anything under `DesignSystem/` or `Theme/`.
- What it does: **detect off-system patterns → propose token/component references**
  for each failure mode below.
- Delegate: Figma manifest → token mapping → [ios-figma-to-code] (this skill
  enforces what that skill generates); module layout of `DesignSystem` package →
  [ios-module-structure]; accessibility on views → [ios-accessibility]; overall
  architecture → [ios-architecture].
- Reality check: **consistency is the product**. A color token in a `.colorset`
  adapts to dark mode, Dynamic Type, and brand refresh automatically. A hardcoded
  hex does none of these, and duplicates silently diverge. The smallest unit of
  design-system debt is one `Color(red: 0.23, green: 0.51, blue: 1.0)`.

## Mode A — Reuse (generation guidance)

Before writing any UI code, locate the token source and component library:

```
1. Glob **/*.xcassets/**/*.colorset  → asset-catalog color names
2. Grep *Theme.swift, */DesignSystem/**/*.swift  → Spacing/Radius/Font token enums
3. Grep */DesignSystem/**/*.swift for struct/class  → existing component views
```

Then map:

- **Semantic named colors** (`Color("Surface")`, `Color("BrandPrimary")`) over
  `Color(red:green:blue:)` or any hex literal. The `.colorset` gives dark-mode
  appearance for free.
- **Spacing enum** (`Spacing.md`, `Spacing.sm`) over any raw `CGFloat` padding or
  spacing value.
- **Font/Typography token** (`Theme.headline`, `.font(.custom("Inter-SemiBold", size: 18))` from the
  token enum) over inline `.font(.system(size: 15, weight: .semibold))`.
- **Existing component views** (`PrimaryButton`, `CardView`, `InputField`) over
  re-built SwiftUI from scratch.
- **Radius/Shadow token** (`Radius.md`, `Shadow.card`) over literal
  `.cornerRadius(12)` or hand-rolled `.shadow(radius: 3, x: 0, y: 2)`.

**Extending the system (the calibration knob):** a genuinely new design need is a
token or component addition reviewed once — never an inline literal. Add ONE color
set to `.xcassets` + ONE entry to the `Theme` enum; don't inline the value
everywhere it appears. That one addition is cheaper than every reviewer catching
six divergent literals forever.

Mode A steps for a new screen derived from `ios-figma-to-code` output:

1. Map all `color` tokens → existing `.colorset` names (or add one to `.xcassets`).
2. Map all `dimension` tokens → existing `Spacing.*` / `Radius.*` entries (or add one).
3. Map all `typography` tokens → existing `Theme.*` font entries (or add one).
4. Replace every manifest `instance` → the existing `DesignSystem` view by name.
5. Only after all four: write the SwiftUI layout referencing tokens, not literals.

## Mode B — Guard (block off-system code)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded color

- **Rule**: all colors come from the asset catalog (`Color("Name")`) or a `Theme`
  color enum. No hex literals, no `Color(red:green:blue:)`, no
  `UIColor(red:green:blue:alpha:)` inline in a component.
- **Common AI failure**: Figma exports a hex; the model pastes it directly as
  `Color(hex: "#3B82F6")` or `Color(red: 0.23, green: 0.51, blue: 1.0)` into a
  view modifier, bypassing the asset catalog entirely.
- **red-flag**: any hex string literal (`"#..."`), `Color(red:`, `Color(hex:`,
  `UIColor(red:` inline in a `View` body or `ViewModifier`.

### 2. Magic spacing / size

- **Rule**: padding, spacing, frame sizes, and edge insets reference a spacing
  token enum (e.g. `Spacing.md`, `Spacing.sm`, `Layout.iconSize`). Raw integer or
  `CGFloat` literals in `.padding`, `.frame`, `EdgeInsets`, or `spacing:` are
  off-system.
- **Common AI failure**: model reads the Figma spec ("padding 13") and emits
  `.padding(13)` or `EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)`.
- **red-flag**: `.padding(<literal>)`, `spacing: <literal>`, `.frame(width: <literal>)`,
  `EdgeInsets(top: <non-zero literal>` where the project has a `Spacing` enum.

### 3. Ad-hoc typography

- **Rule**: font size, weight, and family come from a typography token or a named
  `Font` extension on the `Theme`/`DesignSystem`. Per-component
  `.font(.system(size:weight:))` overrides are off-system.
- **Common AI failure**: Figma has "SemiBold 15px Body"; model emits
  `.font(.system(size: 15, weight: .semibold))` inline on every `Text` node.
- **red-flag**: `.font(.system(size: <literal>`, `.font(.custom("…", size: <literal>))`
  inline in a view (not in the token enum), raw `fontWeight:` / `fontSize:` assignments.

### 4. Reinvented component

- **Rule**: if the `DesignSystem` package ships a `PrimaryButton`, `CardView`,
  `InputField`, or equivalent, **use it**. Do not build a structurally equivalent
  view from scratch alongside the existing one.
- **Common AI failure**: model generates a self-contained `ButtonView` with a
  `RoundedRectangle` background and a `Text` label, not knowing `PrimaryButton`
  already exists three files over.
- **red-flag**: a new `struct` that wraps a `Button`/`Text`/`TextField` in a
  `RoundedRectangle` background and matches the visual signature of an existing
  `DesignSystem` component.

### 5. Off-scale variant

- **Rule**: use exact token values. Near-duplicate literals (`#3B83F7` vs brand
  `#3B82F6`, `Spacing` 14 vs 16) are off-system and diverge silently.
- **Common AI failure**: model adjusts Figma's hex by one digit "to match the
  screen", or rounds a spacing value to the nearest even number rather than the
  nearest token.
- **red-flag**: a color or size literal that is within ~5 units of an existing
  token but not the token value; multiple near-duplicate hex strings in the same
  file.

### 6. Inline style bypassing theme

- **Rule**: the `DesignSystem` / `Theme` module is the only style surface.
  Per-view `.foregroundStyle(…)` / `.background(…)` with literal arguments that
  are not token references bypass it.
- **Common AI failure**: a generated view that individually sets `.foregroundStyle`,
  `.background`, `.cornerRadius`, and `.shadow` with literals on each subview
  instead of applying a single token-backed view modifier or referencing a
  `DesignSystem` style.
- **red-flag**: three or more distinct style modifiers with literal arguments on a
  single view — a sign the component is its own ad-hoc style sheet rather than a
  token consumer.

### 7. Dark-mode / theme break

- **Rule**: colors adapt to dark mode through asset-catalog appearances (the
  `.colorset` `Any`/`Dark` appearance pair) or `@Environment(\.colorScheme)` in the
  `Theme` layer. Hardcoded `Color.white`, `Color.black`, or `Color(red:…)` on
  surfaces or text do not adapt.
- **Common AI failure**: model hardcodes `Color.white` as a card background or
  `Color.black` for text, which inverts semantically in dark mode; or adds a
  `colorScheme == .dark ? darkColor : lightColor` fork in the view body instead of
  relying on an adaptive color set.
- **red-flag**: `Color.white` / `Color.black` on a surface or primary text,
  `colorScheme == .dark ?` in a view body, or a second `if traitCollection.userInterfaceStyle == .dark` branch.

### 8. Duplicated icon / asset

- **Rule**: icons come from SF Symbols (`Image(systemName:)`) or an existing asset
  catalog image (`Image("iconName")`). Don't re-add an asset that the catalog
  already has, and don't reconstruct an icon as a `Path`/`Shape` when the symbol
  or asset already exists.
- **Common AI failure**: model copies a raw SVG path from Figma into a SwiftUI
  `Path { … }` closure, or adds a new `.imageset` for an icon that already has a
  `.imageset` under a slightly different name.
- **red-flag**: a `Path { context in … }` or `addLine`/`addCurve` chain that looks
  like a Figma vector export; a new `.imageset` name that duplicates or near-matches
  an existing catalog entry.

### 9. Ad-hoc radius / elevation / shadow

- **Rule**: corner radius, shadow radius/offset/opacity, and elevation come from
  token enums (`Radius.md`, `Shadow.card`). Literal `.cornerRadius(7)`,
  `.shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)` inline in a
  component are off-system.
- **Common AI failure**: model reads Figma's "corner radius: 12, drop shadow:
  blur 8, offset 0/2" and emits the values directly as modifier arguments.
- **red-flag**: `.cornerRadius(<non-zero literal>)`, `.shadow(radius: <literal>`,
  `.shadow(color: … opacity: <literal>` in a view body (not in a `ViewModifier` or
  token definition).

### 10. Primitive instead of semantic token

- **Rule**: inside component code, reference **semantic** tokens
  (`Color("Surface")`, `Color("ContentPrimary")`, `Theme.brandPrimary`) not palette
  primitives (`Color("Blue500")`, a raw `#3366FF`). Semantic tokens survive
  re-theming; primitives break it silently.
- **Common AI failure**: model emits `Color("Blue500")` or `Color("Gray100")`
  (palette-primitive names from the DTCG output) in view code instead of the
  semantic alias `Color("Surface")` or `Color("ContentSecondary")`.
- **red-flag**: color names that read like palette slots (`Blue500`, `Neutral200`,
  `Brand100`) appearing in view code rather than in the token mapping layer.

## Design-system review checklist

For iOS UI code before merge (especially AI/Figma-generated):

- [ ] All colors from asset catalog (`Color("Name")`) or `Theme` enum — no hex/`Color(red:`.
- [ ] All padding/spacing from `Spacing.*` token — no raw `CGFloat` in `.padding`/`spacing:`.
- [ ] All typography from `Theme.*` font token — no inline `.font(.system(size:weight:))`.
- [ ] Existing `DesignSystem` components used — no reinvented `Button`/`Card`/`Input`.
- [ ] Token values exact, not near-duplicates — no off-by-one literals.
- [ ] No three-or-more literal-argument style modifiers stacked on one view.
- [ ] Dark mode via asset-catalog appearances — no `Color.white`/`.black` on surfaces or text.
- [ ] Icons from SF Symbols or existing `.imageset` — no inline `Path` reconstructions.
- [ ] Corner radius/shadow from `Radius.*`/`Shadow.*` tokens — no literal `.cornerRadius`/`.shadow`.
- [ ] Semantic color names (`Surface`, `ContentPrimary`) in views, not palette primitives (`Blue500`).

## Halt conditions

Stop and report (do not auto-fix) when:

- A color literal cannot be mapped to any existing `.colorset` name and no `Theme`
  entry covers the semantic intent — a new token is needed (report the gap, don't
  inline).
- A component duplicates an existing `DesignSystem` view so closely that merging
  both would cause a naming conflict — escalate to the team.
- A `ctx/` override explicitly relaxes a rule for this project — note the override
  and apply it exactly.

Output on halt:

```markdown
## Design-system guard — halted

Halt reason:
- (specific reason: missing token / component conflict / ctx override)

Required before merge:
1. ...
```

## References

- Generation counterpart (what this skill enforces): [ios-figma-to-code](../ios-figma-to-code/SKILL.md)
- Team baseline: [../../guidance.md](../../guidance.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Adjacent: [ios-module-structure](../ios-module-structure/SKILL.md) (DesignSystem package layout), [ios-accessibility](../ios-accessibility/SKILL.md) (a11y), [ios-security](../ios-security/SKILL.md) (safety floor)
- Skill protocol: `{{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md`
- Apple — Asset catalogs / color sets: https://developer.apple.com/documentation/xcode/asset_catalog_format
- Apple — EnvironmentValues: https://developer.apple.com/documentation/swiftui/environmentvalues
- W3C DTCG token format: https://tr.designtokens.org/format/
- Deep dive (bad→good Swift pairs per rule): [reference.md](./reference.md)

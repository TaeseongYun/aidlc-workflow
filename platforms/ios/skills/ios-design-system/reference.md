# ios-design-system — Reference

Deep-dive for `SKILL.md`. **Bad (❌) vs good (✅)** Swift/SwiftUI pairs per guard
rule, plus Mode-A reuse walkthroughs. Decision criteria and the review checklist
live in `SKILL.md`. This skill enforces the output of
[ios-figma-to-code](../ios-figma-to-code/SKILL.md).

---

## Mode A — Reuse walkthrough

### A1. Locate tokens and components before writing any view

```bash
# 1. What color sets exist?
find . -name "*.colorset" -path "*.xcassets/*" | sed 's/.*\/\(.*\)\.colorset/\1/'
# → Surface, BrandPrimary, ContentPrimary, ContentSecondary, Elevated, Muted, …

# 2. What spacing/radius/font tokens are defined?
grep -rn "static let" --include="*.swift" Sources/DesignSystem/Tokens/
# → Spacing.sm = 8, Spacing.md = 16, Spacing.lg = 24
# → Radius.sm = 8,  Radius.md = 12, Radius.lg = 16
# → Theme.headline, Theme.body, Theme.caption

# 3. What component views exist?
grep -rn "^struct\|^class\|^public struct" --include="*.swift" Sources/DesignSystem/Components/
# → PrimaryButton, SecondaryButton, CardView, InputField, TagView, IconButton, …
```

Map Figma-derived values to these names first. If a value has no token, add one
(see A2) — never inline the literal.

### A2. Adding ONE new token instead of inlining

A new screen needs a `Spacing.xl` (32 pt) that the token file doesn't have yet:

```swift
// ❌ inline the one-off everywhere it appears
.padding(32)
VStack(spacing: 32) { … }
.frame(minHeight: 32)

// ✅ add it once to the token enum, then reference it everywhere
// Sources/DesignSystem/Tokens/Spacing.swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32   // ← added once, reviewed once
}

// In every view:
.padding(Spacing.xl)
VStack(spacing: Spacing.xl) { … }
```

Same principle for a new color: add ONE `.colorset` entry (with `Any`/`Dark`
appearances) and ONE `Theme` enum entry referencing it. Never add the hex inline.

---

## 1. Hardcoded color

```swift
// ❌ hex literal / Color(red:) in a view — breaks theming and dark mode
struct OrderStatusBadge: View {
    var body: some View {
        Text("Shipped")
            .foregroundStyle(Color(red: 0.23, green: 0.51, blue: 1.0))   // hardcoded
            .background(Color(hex: "#EFF6FF"))                             // hardcoded
    }
}

// ✅ asset-catalog named color — resolves the right appearance automatically
struct OrderStatusBadge: View {
    var body: some View {
        Text("Shipped")
            .foregroundStyle(Color("BrandPrimary"))    // from BrandPrimary.colorset
            .background(Color("Surface"))              // from Surface.colorset
            .padding(.horizontal, Spacing.sm)
    }
}
```

If neither `BrandPrimary` nor `Surface` exists in the catalog, add the
`.colorset` (Mode A2) — do not inline the hex.

---

## 2. Magic spacing / size

```swift
// ❌ raw CGFloat literals scattered through padding and spacing
struct ProfileCard: View {
    var body: some View {
        VStack(spacing: 13) {               // magic number
            Text(name).padding(.bottom, 6)  // magic number
        }
        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
    }
}

// ✅ spacing token enum — one source of truth for the scale
struct ProfileCard: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(name).padding(.bottom, Spacing.xs)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
    }
}
```

`13` is not `Spacing.sm` (8) or `Spacing.md` (16) — it's an off-scale value.
Round to the nearest token; if no token is close, add `Spacing.smPlus` once.

---

## 3. Ad-hoc typography

```swift
// ❌ inline font size + weight on every Text — duplicates the type ramp
struct ArticleCard: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))  // duplicated everywhere
            Text(subtitle)
                .font(.system(size: 13, weight: .regular))   // duplicated everywhere
        }
    }
}

// ✅ typography token from the Theme enum
struct ArticleCard: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(Theme.headline)     // Theme.headline = .custom("Inter-SemiBold", size: 18)
            Text(subtitle).font(Theme.caption)   // Theme.caption  = .custom("Inter-Regular", size: 13)
        }
    }
}

// In Sources/DesignSystem/Tokens/Theme.swift (generated from tokens.json):
enum Theme {
    static let headline = Font.custom("Inter-SemiBold", size: 18)
    static let body     = Font.custom("Inter-Regular",  size: 16)
    static let caption  = Font.custom("Inter-Regular",  size: 13)
}
```

---

## 4. Reinvented component

```swift
// ❌ building a new primary-action button from scratch alongside the existing one
struct CheckoutView: View {
    var body: some View {
        // AI-generated bespoke button — DesignSystem.PrimaryButton already exists
        Button(action: onPay) {
            Text("Pay Now")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("BrandPrimary"))
                .cornerRadius(10)
        }
    }
}

// ✅ use the existing DesignSystem component
struct CheckoutView: View {
    var body: some View {
        PrimaryButton(title: "Pay Now", action: onPay)
        // PrimaryButton lives in Sources/DesignSystem/Components/PrimaryButton.swift
    }
}
```

If `PrimaryButton` needs a new variant (e.g. destructive), add the variant to
`PrimaryButton` once — don't create a parallel `DangerButton` from scratch.

---

## 5. Off-scale variant

```swift
// ❌ near-duplicate of a token but not the token
.foregroundStyle(Color(red: 0.232, green: 0.513, blue: 1.0))  // ≈ BrandPrimary but off by rounding
.padding(14)   // one point away from Spacing.md (16); not a token value
.cornerRadius(11)  // one point away from Radius.md (12); not a token value

// ✅ use the exact token — map, don't round-trip through Figma's px output
.foregroundStyle(Color("BrandPrimary"))
.padding(Spacing.md)
.cornerRadius(Radius.md)
```

Off-scale variants look identical at design time and diverge in production. If
the Figma spec says 14 and the nearest token is 16, use the token and flag the
spec discrepancy to the designer — don't round silently.

---

## 6. Inline style bypassing theme

```swift
// ❌ three-or-more literal style modifiers stacked on one view — ad-hoc stylesheet
Text(label)
    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
    .background(Color(red: 0.97, green: 0.97, blue: 0.97))
    .cornerRadius(8)
    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)

// ✅ a single token-backed ViewModifier (or the existing DesignSystem component)
Text(label)
    .modifier(TagStyle())   // TagStyle is defined once in DesignSystem/Styles/

// Sources/DesignSystem/Styles/TagStyle.swift
struct TagStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color("ContentPrimary"))
            .background(Color("Elevated"))
            .cornerRadius(Radius.sm)
            .modifier(Shadow.sm)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
    }
}
```

---

## 7. Dark-mode / theme break

```swift
// ❌ hardcoded light-mode color on a surface — inverts semantically in dark mode
struct ContentCard: View {
    var body: some View {
        VStack { … }
            .background(Color.white)          // ← breaks in dark mode
            .foregroundStyle(Color.black)     // ← breaks in dark mode
    }
}

// ❌ manual colorScheme fork in the view body — duplicates the adaptation logic
struct ContentCard: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack { … }
            .background(colorScheme == .dark ? Color(hex: "#1C1C1E") : Color.white)
    }
}

// ✅ asset-catalog color set with Any/Dark appearances — adapts automatically
struct ContentCard: View {
    var body: some View {
        VStack { … }
            .background(Color("Surface"))        // Surface.colorset: Any=#FFFFFF, Dark=#1C1C1E
            .foregroundStyle(Color("ContentPrimary"))
    }
}
// No colorScheme check needed — the trait environment resolves it.
```

---

## 8. Duplicated icon / asset

```swift
// ❌ raw Path reconstruction from Figma's vector export
struct HeartIcon: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 12, y: 21))
            path.addCurve(to: CGPoint(x: 12, y: 5), …)
            // … 30 more lines of path data
        }
        .fill(Color("BrandPrimary"))
    }
}

// ❌ adding a second imageset when "heart.fill" already covers it
// ❌ Heart.imageset added to xcassets when heart.fill SF Symbol works fine

// ✅ SF Symbol (covers the vast majority of icon needs)
Image(systemName: "heart.fill")
    .foregroundStyle(Color("BrandPrimary"))

// ✅ existing asset catalog entry (when a custom icon is genuinely needed)
Image("IconHeart")
    .renderingMode(.template)
    .foregroundStyle(Color("BrandPrimary"))
// Check with: find . -name "*.imageset" | grep -i heart  before adding a new one.
```

---

## 9. Ad-hoc radius / elevation / shadow

```swift
// ❌ literal corner radius and hand-rolled shadow in a view body
struct NotificationBanner: View {
    var body: some View {
        HStack { … }
            .cornerRadius(7)                                    // off-token literal
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)  // hand-rolled
    }
}

// ✅ radius and shadow tokens
struct NotificationBanner: View {
    var body: some View {
        HStack { … }
            .cornerRadius(Radius.sm)           // Radius.sm = 8 (nearest token to 7)
            .modifier(Shadow.card)             // Shadow.card defined once in DesignSystem
    }
}

// Sources/DesignSystem/Tokens/Shadow.swift
struct Shadow {
    static let card = ShadowModifier(color: Color("ShadowDefault"), radius: 4, x: 0, y: 2, opacity: 0.10)
    static let sm   = ShadowModifier(color: Color("ShadowDefault"), radius: 2, x: 0, y: 1, opacity: 0.08)
}
```

---

## 10. Primitive instead of semantic token

```swift
// ❌ palette primitive in component code — re-theming silently breaks it
struct AlertBanner: View {
    var body: some View {
        HStack { … }
            .background(Color("Blue500"))       // primitive: breaks when brand changes
            .foregroundStyle(Color("Gray100"))  // primitive: semantic intent unclear
    }
}

// ✅ semantic token — survives re-theming and communicates intent
struct AlertBanner: View {
    var body: some View {
        HStack { … }
            .background(Color("BrandPrimary"))      // semantic: "this is the brand surface"
            .foregroundStyle(Color("OnBrandPrimary")) // semantic: "text on brand surface"
    }
}

// The palette primitive lives only in the token mapping layer:
// Sources/DesignSystem/Tokens/Theme.swift (generated from tokens.json):
//   Color("BrandPrimary")  →  xcassets: Any=#3366FF (Blue500), Dark=#5580FF
// View code never references "Blue500" directly.
```

---

## Full review checklist

- [ ] Colors: `Color("Name")` or `Theme.*` — no hex, no `Color(red:`.
- [ ] Spacing: `Spacing.*` — no raw `CGFloat` in `.padding`/`spacing:`/`.frame`.
- [ ] Typography: `Theme.*` font token — no inline `.font(.system(size:weight:))`.
- [ ] Components: existing `DesignSystem` views used — no structural duplicates.
- [ ] Token values exact, not off-scale near-duplicates.
- [ ] No three-or-more literal-argument style modifiers on a single view.
- [ ] `Color.white`/`Color.black` absent on surfaces/text — asset-catalog appearances used.
- [ ] Icons: SF Symbol or existing `.imageset` — no `Path` reconstructions.
- [ ] `.cornerRadius` / `.shadow` from token enums — no literals in view bodies.
- [ ] Semantic names (`Surface`, `ContentPrimary`) in views — not palette slots (`Blue500`).

## References

- `SKILL.md` for rules, checklist, and halt conditions.
- Generation counterpart: [ios-figma-to-code](../ios-figma-to-code/SKILL.md) — this skill enforces its output.
- Token format: https://tr.designtokens.org/format/
- Apple asset catalog format: https://developer.apple.com/documentation/xcode/asset_catalog_format
- SwiftUI EnvironmentValues: https://developer.apple.com/documentation/swiftui/environmentvalues
- Team baseline: [../../guidance.md](../../guidance.md)

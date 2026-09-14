---
name: ios-i18n
description: iOS internationalization guard — translation keys, ICU pluralization, named placeholders,
  locale-aware date/number/currency formatting, and RTL-safe layout, plus detect/block the i18n
  anti-patterns AI ships (hardcoded user-facing strings, sentence concatenation, manual pluralization,
  hardcoded date/number/currency formats, hardcoded left/right layout, missing placeholders, hardcoded
  locale, missing translations, text baked into images). Auto-loads when writing or reviewing
  user-facing UI text.
when_to_use: When adding/reviewing user-facing text, formatting dates/numbers/currency, handling
  plurals, or laying out UI, or on requests like "is this localizable", "add i18n", "does this
  support RTL".
paths: "**/*.swift, **/*.xcstrings, **/*.strings, **/*.stringsdict"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-i18n — internationalization guard

AI-generated SwiftUI code is **English-hardcoded**: it writes `Text("Submit")`
instead of a String Catalog key, concatenates translated fragments that break
across word-order languages, pluralizes with `count == 1 ? "item" : "items"`,
hard-formats dates as `"MM/dd/yyyy"`, prepends `"$"` to a number, and pins
layout to `.leading`/`.trailing` without RTL mirroring. Retrofitting i18n after
shipping is expensive and error-prone. This skill is the **guard** that catches
these patterns at write time and enforces the iOS i18n stack:
`Localizable.strings` / String Catalog (`.xcstrings`), `String(localized:)` /
`NSLocalizedString`, `.stringsdict` plurals, `Locale`-aware `formatted()` /
`DateFormatter` / `NumberFormatter`, and logical layout (`leading`/`trailing` +
`environment(\.layoutDirection, .rightToLeft)`).

The rules here are **safety rules** and must not be relaxed. Project `ctx/`
overrides this document, but the i18n floor is never lowered.

## Scope

- **In scope**: user-facing text in SwiftUI views, string resources
  (`.strings`, `.xcstrings`, `.stringsdict`), date/number/currency formatting,
  layout direction safety, plural handling.
- **Delegate**:
  - Accessible labels that also need translation → [ios-accessibility](../ios-accessibility/SKILL.md)
    (accessibilityLabel strings are user-facing and must also be localized).
  - Typography choices for CJK / Arabic script → [ios-design-system](../ios-design-system/SKILL.md).
  - Architecture for locale-switching or feature flags → [ios-architecture](../ios-architecture/SKILL.md).

## Core guidance (Do)

- **Externalize all user-facing strings** to a String Catalog (`.xcstrings`) or
  `Localizable.strings`. Use `String(localized: "key")` (Swift 5.7+) or
  `NSLocalizedString("key", comment: "…")`. Never inline literal UI text.
- **Use `.stringsdict` or String Catalog plural rules** for any count-dependent
  string. Never `count == 1 ? "item" : "items"`.
- **Use named placeholders** — `"%@ sent %lld items"` with argument labels in
  the catalog, or `String(localized: "\(name) sent \(count) items")` in Swift
  5.9+ string catalogs — so translators can reorder.
- **Format dates, times, numbers, and currency with locale-aware APIs**:
  `Date.formatted(.dateTime.month().day().year())`, `value.formatted(.number)`,
  `amount.formatted(.currency(code: "USD"))`, or explicit `DateFormatter` /
  `NumberFormatter` with `locale = .current`.
- **Use logical layout**: SwiftUI's default stack alignment is already
  logical (`leading`/`trailing` map to the correct side for the active
  locale). Avoid `Alignment.left`/`.right`; never hard-set
  `environment(\.layoutDirection, .leftToRight)`. Mirror custom assets with
  `.flipsForRightToLeftLayoutDirection(true)` where needed.
- **Provide a base/fallback locale** (typically `en`) so missing keys never
  silently display raw key strings or blank text.

## Guard rules (Mode B)

Each item: **rule → common AI failure → red-flag**. Code pairs in [reference.md](./reference.md).

### 1. Hardcoded user-facing string

- **Rule**: every string the user reads comes from a localization key in
  `.xcstrings` / `Localizable.strings`, loaded via `String(localized:)` or
  `NSLocalizedString`. No inline string literals in `Text(…)` or UI-bound
  properties.
- **Common AI failure**: `Text("Submit")`, `Text("Welcome, \(name)!")`,
  `Button("Continue") { … }` — all with raw English literals.
- **red-flag**: `Text("…")` with a plain string literal; any UI-visible string
  that is not a key lookup.

### 2. Sentence concatenation

- **Rule**: build localizable sentences as a **single keyed string with
  placeholders**, never by concatenating separately translated fragments.
  Word order differs across languages; concatenation produces grammatically
  broken output.
- **Common AI failure**: `Text(NSLocalizedString("You have", …) + " \(count) " + NSLocalizedString("items", …))`.
- **red-flag**: `+` between two `NSLocalizedString`/`String(localized:)` calls,
  or a localized string joined with a runtime variable outside a single
  format string.

### 3. Manual pluralization

- **Rule**: use `.stringsdict` plural rules or String Catalog plural variants
  for any quantity-dependent string. English `"s"` suffixing fails for Arabic,
  Russian, and many other languages.
- **Common AI failure**: `count == 1 ? String(localized: "item") : String(localized: "items")`,
  `"\(count) item\(count == 1 ? "" : "s")"`.
- **red-flag**: a ternary or `+ "s"` pattern gating on a count inside a
  localized string context.

### 4. Hardcoded date/time format

- **Rule**: never pass a hand-written format string (`"MM/dd/yyyy"`,
  `"HH:mm"`) to a formatter in UI-facing code. Use `Date.formatted(…)` with
  style options, or configure `DateFormatter` with `locale = .current` and
  `dateStyle`/`timeStyle` — never `dateFormat`.
- **Common AI failure**: `formatter.dateFormat = "MM/dd/yyyy"`,
  `DateFormatter().string(from: date)` with a hard pattern.
- **red-flag**: `dateFormat =` assignment in a UI-bound formatter; a hard
  date-pattern string literal in a view or view model.

### 5. Hardcoded number/currency format

- **Rule**: format numbers and currency with `Formatter` APIs bound to the
  user locale. Never concatenate a currency symbol (`"$"`, `"€"`) with a raw
  numeric string or use `String(format: "%.2f", value)` for UI display.
- **Common AI failure**: `"$\(price)"`, `String(format: "%.2f", amount)`,
  `"\(Int(price)) USD"`.
- **red-flag**: a literal currency symbol in a string interpolation; raw
  `String(format:)` for a user-visible numeric value.

### 6. Non-RTL-safe layout

- **Rule**: use SwiftUI logical alignment (`HStack` leading/trailing, `.leading`
  text alignment, `Spacer()` between elements). Never force
  `environment(\.layoutDirection, .leftToRight)`. Custom arrow/chevron assets
  that indicate direction must flip with `.flipsForRightToLeftLayoutDirection(true)`.
- **Common AI failure**: `HStack { Spacer(); content }` to "left-align" (works
  in LTR only), explicit `.environment(\.layoutDirection, .leftToRight)`,
  hardcoded `padding(.leading, 16)` as the sole alignment mechanism.
- **red-flag**: `environment(\.layoutDirection, .leftToRight)` in a view;
  `Alignment.left` / `.right`; directional-only padding used as layout logic.

### 7. Missing placeholders

- **Rule**: any string that includes runtime values (names, counts, amounts)
  must carry `%@` / `%lld` positional or named placeholders in the resource
  key so translators can reorder them. Do not split the value out via
  concatenation.
- **Common AI failure**: `String(localized: "Hello") + " " + name` — the
  translator sees only `"Hello"` and cannot place `name` correctly.
- **red-flag**: a localized string abutted with `+` to a runtime value;
  a string key that should contain a placeholder but has none.

### 8. Hardcoded locale

- **Rule**: pass `Locale.current` (or omit the locale argument — it defaults
  to current) to all formatters and locale-sensitive APIs. Never hardcode
  `Locale(identifier: "en_US")` or `Locale(identifier: "en")` in UI-facing
  code.
- **Common AI failure**: `formatter.locale = Locale(identifier: "en_US")`,
  `Calendar(identifier: .gregorian)` constructed without `locale = .current`.
- **red-flag**: `Locale(identifier:)` with a hardcoded BCP 47 tag passed to
  a UI-facing formatter or calendar.

### 9. Missing translations / no fallback

- **Rule**: every string key must have an entry in the base/fallback locale
  (typically `en`). Configure `CFBundleDevelopmentRegion` and verify that
  Xcode's "Export Localizations" surfaces no missing entries before release.
  A missing key must never surface as blank text or a raw key string.
- **Common AI failure**: adding a new `String(localized: "new_key")` without
  adding `"new_key"` to the `.xcstrings` / `Localizable.strings` base file;
  removing a key from the catalog without updating all call sites.
- **red-flag**: a `String(localized:)` key not present in the base `.xcstrings`
  or `Localizable.strings`; a `.stringsdict` key with no matching lookup.

### 10. Text baked into images

- **Rule**: no user-facing text is rendered inside image assets. Icons and
  illustrations are symbol-only or purely graphical. Culture-specific imagery
  (money symbols, hands, color meanings) must have a localized or neutral
  alternative.
- **Common AI failure**: an image asset with an English label baked into the
  graphic, a screenshot-derived button image containing text.
- **red-flag**: an `Image("asset-name")` in a context where the asset visually
  contains readable text; a design spec image used directly as a UI label.

## Guard checklist

For any SwiftUI view or string resource touched by AI or quickly pasted in:

- [ ] All `Text(…)` views use `String(localized:)` or `LocalizedStringKey`, never a raw literal.
- [ ] Plurals use `.stringsdict` or String Catalog plural variants, not a ternary.
- [ ] Sentence-like strings use a single keyed format string with placeholders, not concatenation.
- [ ] Date/time formatting uses `Date.formatted(…)` or `DateFormatter` with `dateStyle`/`timeStyle` and `locale = .current`.
- [ ] Numbers and currency use `value.formatted(…)` or `NumberFormatter` with `locale = .current`; no literal `$`/`€`.
- [ ] Layout uses SwiftUI logical alignment; no `environment(\.layoutDirection, .leftToRight)`.
- [ ] Formatters and calendars use `Locale.current`; no `Locale(identifier: "en_US")`.
- [ ] Every `String(localized:)` key exists in the base `.xcstrings` / `Localizable.strings`.
- [ ] No user-readable text is baked into image assets.
- [ ] Accessible labels (`.accessibilityLabel`) are also localized — see [ios-accessibility](../ios-accessibility/SKILL.md).

## Halt conditions

Halt and report (per [skill-protocol.md]({{TEAM_AI_WORKFLOW_DIR}}/skills/_shared/skill-protocol.md)) when:

- A guard rule violation is detected and the correct fix is not determinable
  from the surrounding context (e.g., the correct string key is unknown).
- The `.xcstrings` / `.strings` / `.stringsdict` resource files are not
  accessible and the guard cannot verify key existence.

Output on halt:

```
## i18n Guard — Halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. …
```

Do NOT propose automatic fixes on halt. Output the halt reason only.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code pairs (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [ios-architecture](../ios-architecture/SKILL.md)
- Adjacent (a11y labels also need localization): [ios-accessibility](../ios-accessibility/SKILL.md)
- Apple — String Catalogs: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Apple — Internationalization (SwiftUI): https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- Apple — Formatters: https://developer.apple.com/documentation/foundation/formatter
- Apple — stringsdict: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/StringsdictFileFormat/StringsdictFileFormat.html
- Apple — Supporting Right-to-Left: https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions

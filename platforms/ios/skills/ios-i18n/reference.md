# ios-i18n — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Swift/SwiftUI code
pairs per failure mode. Decision criteria and the guard checklist live in
[SKILL.md](./SKILL.md).

## Why this guard exists

AI-generated SwiftUI defaults to English: it writes `Text("Submit")`, builds
sentences by concatenation, pluralizes with `count == 1 ? "s" : ""`, and
hard-formats dates as `"MM/dd/yyyy"`. These patterns compile without warning,
ship to a global audience, and are expensive to retrofit. The iOS i18n stack —
String Catalogs (`.xcstrings`), `String(localized:)`, `.stringsdict` plurals,
`Locale`-aware formatters, and SwiftUI's logical layout — catches all of them
at write time.

---

## 1. Hardcoded user-facing string

```swift
// ❌ Raw English literal — untranslatable
Text("Submit")
Button("Continue") { submit() }
Text("Welcome, \(user.name)!")

// ✅ Key from String Catalog / Localizable.strings via LocalizedStringKey
// (SwiftUI Text init with a string literal is implicitly LocalizedStringKey —
//  but the key must exist in the catalog.)
Text("submit_button_title")         // key looked up from .xcstrings
Button(String(localized: "continue_button_title")) { submit() }

// For interpolated strings, use String(localized:) with a format key:
// Localizable.strings entry:  "welcome_message" = "Welcome, %@!";
Text(String(localized: "welcome_message \(user.name)"))
// or with String Catalog (Xcode 15+): the catalog carries the format string;
// String(localized:) picks it up automatically.
```

Key with comment (gives translators context):
```swift
let title = String(
    localized: "profile_edit_title",
    comment: "Navigation bar title for the profile editing screen"
)
```

---

## 2. Sentence concatenation

```swift
// ❌ Concatenated fragments — word order breaks in German, Japanese, Arabic
let msg = NSLocalizedString("You have", comment: "") + " \(count) " +
          NSLocalizedString("items in your cart", comment: "")
Text(msg)

// ✅ Single format key — translator controls word order via placeholder position
// Localizable.strings:  "cart_item_count" = "You have %lld items in your cart";
// Arabic translator:    "cart_item_count" = "لديك %lld عنصرًا في سلة التسوق";
Text(String(format: NSLocalizedString("cart_item_count", comment: "Cart item count"), count))

// Xcode 15+ String Catalog (preferred):
// Key "cart_item_count" = "You have \(count) items in your cart"
// The catalog stores the format; String(localized:) resolves it.
Text(String(localized: "cart_item_count \(count)"))
```

---

## 3. Manual pluralization

```swift
// ❌ English-only plural — breaks in Russian (many forms), Arabic (6 forms)
Text("\(count) item\(count == 1 ? "" : "s")")
Text(count == 1 ? String(localized: "one_item") : String(localized: "many_items"))

// ✅ .stringsdict plural rule (pre-Xcode 15 / Localizable.stringsdict)
// Key "items_count" in .stringsdict with NSStringPluralRuleType:
//   one  → "%lld item"
//   other → "%lld items"
let fmt = NSLocalizedString("items_count", comment: "Number of items")
Text(String(format: fmt, count))

// ✅ String Catalog plural (Xcode 15+, .xcstrings) — preferred
// Add key "items_count" with plural variants in the catalog editor.
// Xcode auto-generates the plural table; translators fill all forms.
Text(String(localized: "items_count \(count)"))
```

Example `.stringsdict` entry:
```xml
<key>items_count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@items@</string>
    <key>items</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>  <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key> <string>lld</string>
        <key>one</key>   <string>%lld item</string>
        <key>other</key> <string>%lld items</string>
    </dict>
</dict>
```

---

## 4. Hardcoded date/time format

```swift
// ❌ Fixed pattern — shows MM/DD/YYYY to users who expect DD.MM.YYYY or YYYY年MM月DD日
let formatter = DateFormatter()
formatter.dateFormat = "MM/dd/yyyy"
Text(formatter.string(from: date))

// ✅ DateFormatter with locale-aware style (no dateFormat)
let formatter = DateFormatter()
formatter.dateStyle = .medium   // "Aug 26, 2026" in en-US, "26. Aug. 2026" in de
formatter.timeStyle = .none
formatter.locale = .current     // always bind to the user's locale
Text(formatter.string(from: date))

// ✅ Preferred: Date.formatted (iOS 15+) — no formatter object needed
Text(date.formatted(date: .abbreviated, time: .omitted))
// or with FormatStyle options:
Text(date.formatted(.dateTime.month(.wide).day().year()))
```

---

## 5. Hardcoded number/currency format

```swift
// ❌ Literal currency symbol and hand-rolled decimal
Text("$\(String(format: "%.2f", price))")
Text("\(Int(amount)) USD")

// ✅ Currency formatter bound to current locale
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.locale = .current          // locale determines symbol, decimal, grouping
formatter.currencyCode = "USD"       // explicit code; symbol derived from locale
if let s = formatter.string(from: NSNumber(value: price)) { Text(s) }

// ✅ Preferred: FormatStyle (iOS 15+)
Text(price.formatted(.currency(code: "USD")))
// plain number (locale-aware thousands separator, decimal):
Text(count.formatted(.number))
// percent:
Text(ratio.formatted(.percent.precision(.fractionLength(1))))
```

---

## 6. Non-RTL-safe layout

```swift
// ❌ Explicit left-to-right direction locks Arabic/Hebrew users into mirrored layout
SomeView()
    .environment(\.layoutDirection, .leftToRight)  // force-overrides locale

// ❌ Padding only on the leading-by-eye side
HStack {
    icon
    Spacer()     // "right-aligns" content — wrong meaning in RTL
}
.padding(.leading, 16)   // hardcoded side; won't flip

// ✅ SwiftUI's HStack/VStack alignment is logical by default — no change needed
HStack(alignment: .center, spacing: 12) {
    icon
    Text(String(localized: "label_key"))
    Spacer()
}
.padding(.horizontal, 16)   // horizontal applies to both sides symmetrically

// ✅ Directional asset that must mirror (arrow, chevron)
Image(systemName: "arrow.right")
    .flipsForRightToLeftLayoutDirection(true)

// ✅ Reading layout direction from the environment (custom layout logic only)
@Environment(\.layoutDirection) private var layoutDirection
var body: some View {
    // use layoutDirection only when a truly direction-specific calculation is needed
}
```

---

## 7. Missing placeholders

```swift
// ❌ Runtime value appended outside the format key — translator cannot reorder
let greeting = String(localized: "hello_prefix") + " " + user.name
Text(greeting)

// ❌ Key has no placeholder; user.name is invisible to the translator
// Localizable.strings: "hello_prefix" = "Hello";
// Translator sees only "Hello" — cannot write "Hola, {name}" with correct grammar

// ✅ Single key with named/positional placeholder
// Localizable.strings: "greeting" = "Hello, %@!";
// Spanish:             "greeting" = "¡Hola, %@!";
// Japanese:            "greeting" = "こんにちは、%@！";
Text(String(format: NSLocalizedString("greeting", comment: "Greeting with user name"), user.name))

// ✅ String Catalog (Xcode 15+) with interpolation
// Key "greeting" = "Hello, \(name)!"  — Xcode records the placeholder type
Text(String(localized: "greeting \(user.name)"))

// Multiple placeholders — positional specifiers let translators reorder:
// "transfer_notice" = "%1$@ sent %2$lld files to %3$@";
// German might reorder: "%2$lld Dateien wurden von %1$@ an %3$@ gesendet";
let msg = String(format: NSLocalizedString("transfer_notice", comment: ""),
                 sender, fileCount, recipient)
```

---

## 8. Hardcoded locale

```swift
// ❌ Forces US English formatting regardless of user's device locale
let formatter = NumberFormatter()
formatter.locale = Locale(identifier: "en_US")   // hardcoded
formatter.numberStyle = .decimal

// ❌ Gregorian calendar without respecting user locale
var cal = Calendar(identifier: .gregorian)
// (misses locale — uses en_US_POSIX defaults)

// ✅ Always use Locale.current (or omit — it's the default)
let formatter = NumberFormatter()
formatter.locale = .current   // user's active locale
formatter.numberStyle = .decimal

// ✅ Calendar bound to current locale
var cal = Calendar.current           // respects device locale and calendar system
// or explicitly:
var cal = Calendar(identifier: .gregorian)
cal.locale = .current

// ✅ DateFormatter (same pattern)
let df = DateFormatter()
df.locale = .current
df.dateStyle = .long
```

---

## 9. Missing translations / no fallback

```swift
// ❌ Key used in code but absent from the base .xcstrings / Localizable.strings
// In view:
Text(String(localized: "onboarding_step3_title"))   // displays raw key or blank if missing

// ❌ Key deleted from catalog but call site not updated
// (Xcode won't warn at build time by default)

// ✅ Workflow: always add the key to the base locale first
// In Localizable.strings (en base):
//   "onboarding_step3_title" = "Set up your profile";
// OR in .xcstrings (Xcode 15+, preferred):
//   Xcode auto-registers keys found in String(localized:) calls;
//   run Product → Export Localizations to surface any that are missing.

// ✅ Verify with a build phase script or CI check:
// xcrun extractLocStrings, or use the built-in Xcode localization export,
// and fail the build if any key in code is absent from the base catalog.

// ✅ Set CFBundleDevelopmentRegion in Info.plist to your base language (e.g. "en")
// so the OS falls back to the base catalog when a localization is incomplete.
```

Info.plist fallback:
```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
```

---

## 10. Text baked into images

```swift
// ❌ Image asset has English text rendered into the graphic — untranslatable
Image("onboarding_welcome_en")   // PNG with "Get Started" baked in

// ❌ Screenshot-derived button used directly
Image("screenshot_submit_button")

// ✅ Pure graphical asset + separate Text layer
ZStack {
    Image("onboarding_illustration")          // text-free illustration
    Text(String(localized: "get_started_title"))
        .font(.headline)
        .foregroundStyle(.white)
}

// ✅ SF Symbols for directional/semantic icons — no text, locale-neutral
Image(systemName: "arrow.right.circle.fill")
    .flipsForRightToLeftLayoutDirection(true)

// ✅ When a locale-specific asset is truly required, use the asset catalog's
//    localization slot (Xcode → asset → Localize) to supply per-locale images.
```

---

## Do — full examples

### Keyed string with ICU plural + named placeholder (String Catalog, Xcode 15+)

```swift
// .xcstrings entry (auto-managed by Xcode):
// Key: "files_uploaded \(count)"
// en plural variants:
//   one:   "%lld file uploaded"
//   other: "%lld files uploaded"

// In view — one call resolves the right plural form:
Text(String(localized: "files_uploaded \(uploadCount)"))
```

### Locale-aware date and currency

```swift
struct ReceiptRow: View {
    let date: Date
    let amount: Decimal
    let currencyCode: String

    var body: some View {
        HStack {
            Text(date.formatted(date: .abbreviated, time: .omitted))
            Spacer()
            Text(amount.formatted(.currency(code: currencyCode)))
        }
    }
}
// Produces "Aug 26, 2026  $14.99" in en-US
//          "26. Aug. 2026  14,99 $" in fr-FR   (currency position flips by locale)
//          "2026年8月26日  US$14.99" in ja-JP
```

### RTL-safe layout

```swift
struct MessageRow: View {
    let avatar: String      // system image name
    let senderName: String
    let preview: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: avatar)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "sender_name \(senderName)"))
                    .font(.headline)
                Text(String(localized: "message_preview \(preview)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        // HStack leading/trailing + .horizontal padding are logical — RTL flips automatically.
        // No .environment(\.layoutDirection, …) needed.
    }
}
```

### Accessible label — also localized (cross-link to ios-accessibility)

```swift
// accessibilityLabel strings are user-facing and must go through the catalog.
// See ios-accessibility for the full a11y rule set.
Button {
    deleteItem()
} label: {
    Image(systemName: "trash")
}
.accessibilityLabel(String(localized: "delete_item_button_label",
                           comment: "Accessibility label for the delete button"))
```

---

## Official references

- Apple — String Catalogs: https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog
- Apple — Preparing Views for Localization (SwiftUI): https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- Apple — stringsdict File Format: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/StringsdictFileFormat/StringsdictFileFormat.html
- Apple — Formatters: https://developer.apple.com/documentation/foundation/formatter
- Apple — FormatStyle: https://developer.apple.com/documentation/foundation/formatstyle
- Apple — Supporting Right-to-Left Languages: https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions
- Apple — NSLocalizedString: https://developer.apple.com/documentation/foundation/nslocalizedstring(_:tablename:bundle:value:comment:)
- Team baseline: [../../guidance.md](../../guidance.md)
- Guard rules: [SKILL.md](./SKILL.md)
- Accessible labels (also localize): [ios-accessibility/SKILL.md](../ios-accessibility/SKILL.md)

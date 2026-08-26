---
name: android-i18n
description: Android internationalization guard — translation keys in res/values*/strings.xml and plurals.xml,
  positional %1$s placeholders, locale-aware date/number/currency formatting via NumberFormat/DateFormat/android.icu,
  start/end + supportsRtl layout, and locale-qualified resources. Detects and blocks the i18n anti-patterns AI
  ships (hardcoded user-facing strings, sentence concatenation, manual pluralization, hardcoded date/number/currency
  formats, hardcoded left/right layout, missing placeholders, hardcoded locale, missing translations, text baked
  into images). Auto-loads when writing or reviewing user-facing UI text.
when_to_use: When adding or reviewing user-facing text, formatting dates/numbers/currency, handling plurals,
  or laying out UI, or on requests like "is this localizable", "add i18n", "does this support RTL".
paths: "**/res/values*/strings.xml, **/res/values*/plurals.xml, **/*.kt, **/*.xml"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android i18n — internationalization guard

AI-generated Android UI is **English-hardcoded**: it writes literal user-facing strings
instead of resource keys, concatenates translated fragments (breaking word order across
languages), hand-rolls pluralization with `count > 1 ? "items" : "item"`, hardcodes
`MM/dd/yyyy` and `$` formats, and lays out with fixed `marginLeft`/`marginRight` so RTL
languages break. Retrofitting i18n after launch is expensive and error-prone. This skill
is a **guard** that catches all of that at write time, plus the guidance needed to do it
right the first time.

The rules here are **safety rules** and must not be weakened or relaxed. Deeper material
(bad → good code pairs for all 10 rules, formatter examples, RTL layout XML) lives in
[reference.md](./reference.md).

## Scope

- In scope: `res/values*/strings.xml`, `res/values*/plurals.xml`, Kotlin Compose sources
  (`stringResource()`, `pluralStringResource()`), XML layouts, `NumberFormat` /
  `DateFormat` / `android.icu` usage, `supportsRtl`, `start`/`end` layout attributes.
- Also in scope: locale-qualified resource directories (`values-fr/`, `values-ar/`, etc.),
  hardcoded `Locale` instances, and text embedded in image assets.
- Delegates to [android-accessibility](../android-accessibility/SKILL.md) — a11y labels
  (`contentDescription`) also need translation; an untranslated label is both an i18n and
  an a11y failure.
- Delegates to [android-design-system](../android-design-system/SKILL.md) — typography
  choices for CJK and RTL scripts (line height, font selection).
- Delegates to [android-architecture](../android-architecture/SKILL.md) — how locale
  state propagates through ViewModels and the navigation graph.

## Core guidance (Do)

- **Externalize every user-facing string.** All UI text lives in
  `res/values/strings.xml` (and locale-qualified overrides). In Compose use
  `stringResource(R.string.key)`; in XML use `@string/key`. Never render a literal
  string in UI code.
- **Use `plurals.xml` for count-dependent text.** Define a `<pluralString>` resource
  with the standard quantity selectors (`zero`, `one`, `two`, `few`, `many`, `other`).
  In Compose use `pluralStringResource(R.plurals.key, count, count)`; the resource
  system picks the correct form for the active locale.
- **Use positional placeholders; never concatenate.** Use `%1$s`, `%2$d`, etc. in the
  string resource so translators can reorder arguments. In Compose call
  `stringResource(R.string.key, arg1, arg2)`. Never build a sentence by joining
  translated fragments at runtime.
- **Format numbers, dates, and currency with locale-aware APIs.** Use
  `NumberFormat.getCurrencyInstance(locale)`, `NumberFormat.getNumberInstance(locale)`,
  `DateFormat.getDateInstance(DateFormat.MEDIUM, locale)`, or `android.icu.text.*` for
  richer CLDR support. The locale comes from `Locale.getDefault()` or the user's
  `LocaleList`, never from a hardcoded constant.
- **Use `start`/`end` layout attributes everywhere; add `supportsRtl="true"`.** In XML
  use `android:paddingStart`, `android:layout_marginEnd`,
  `android:gravity="start"`. In Compose use `Alignment.Start`/`Alignment.End` and
  `Arrangement.Start`/`Arrangement.End`. Declare
  `android:supportsRtl="true"` in `<application>` and test in a forced-RTL emulator.
- **Provide a fallback locale.** Keep a complete `res/values/strings.xml` (no qualifier)
  as the authoritative English fallback. Every key present in a locale-qualified
  directory must also exist in `values/`.
- **Never embed user-facing text in image assets.** Text in drawables, bitmaps, or
  WebP files cannot be translated. Render text in the UI layer over a plain image if a
  design requires overlaid copy.

## Guard rules (Mode B)

Work through these 10 rules in order for any code or XML under review. Each rule uses
the **rule → common AI failure → red-flag** triad. On a hit, halt and report; do not
silently continue.

---

### Rule 1 — Hardcoded user-facing string

**What AI does:** writes literal UI text directly in Compose or XML instead of a
`strings.xml` key.

**Red-flags:**
- `Text("Submit")`, `Text("Welcome, $name!")` in Compose
- `android:text="Continue"` in a layout XML
- Any non-empty string literal passed to a UI-rendering call

---

### Rule 2 — Sentence concatenation

**What AI does:** builds a displayable sentence by concatenating separately translated
fragments or mixing runtime values between `stringResource()` calls.

**Red-flags:**
- `stringResource(R.string.you_have) + " $count " + stringResource(R.string.items)`
- Multiple `stringResource()` calls joined with `+` to form one sentence
- A string like `"Dear " + userName + ","` passed to `Text()`

---

### Rule 3 — Manual pluralization

**What AI does:** uses a ternary or `if`/`else` to append `"s"` or pick between
singular/plural strings instead of a `pluralString` resource.

**Red-flags:**
- `if (count == 1) "item" else "items"`
- `"$count item" + if (count != 1) "s" else ""`
- Calling two separate `stringResource()` values based on a count comparison

---

### Rule 4 — Hardcoded date/time format

**What AI does:** passes a fixed pattern string to `SimpleDateFormat` or
`DateTimeFormatter` instead of a locale-aware factory.

**Red-flags:**
- `SimpleDateFormat("MM/dd/yyyy")`
- `DateTimeFormatter.ofPattern("dd-MM-yyyy")`
- Any literal date or time pattern string in UI-bound code

---

### Rule 5 — Hardcoded number/currency

**What AI does:** prepends a literal currency symbol or manually formats grouping
separators and decimal points.

**Red-flags:**
- `"$${price}"`, `"€ $amount"` in UI strings
- Manual comma insertion: `"${"%,.2f".format(price)}"`
- `String.format("%.2f", value)` used directly in a UI-facing string without a locale

---

### Rule 6 — Non-RTL-safe layout

**What AI does:** uses physical `left`/`right` attributes or `Alignment.CenterHorizontally`
paired with hardcoded start assumptions instead of logical `start`/`end` equivalents.

**Red-flags:**
- `android:layout_marginLeft`, `android:paddingRight` in XML
- `Alignment.CenterStart` used assuming LTR without `supportsRtl="true"` in manifest
- `Modifier.padding(start = 16.dp, end = 0.dp)` mixed with `Arrangement.End` — check
  the intent; flag if the surrounding structure uses physical directions
- `android:supportsRtl` absent or `false` in `<application>`

---

### Rule 7 — Missing placeholders

**What AI does:** concatenates runtime values into a string at the call site rather than
using `%1$s`/`%2$d` placeholders in the resource, preventing translators from reordering.

**Red-flags:**
- A string resource like `<string name="greeting">Hello </string>` with the name
  appended at the call site: `stringResource(R.string.greeting) + user.name`
- `getString(R.string.items_count) + count` instead of `getString(R.string.items_count, count)`
- A string resource containing no `%` placeholder for a value that clearly varies

---

### Rule 8 — Hardcoded locale

**What AI does:** explicitly constructs `Locale("en")` or `Locale.US` and passes it to
a formatter or sets it as the app locale, overriding the user's system locale.

**Red-flags:**
- `Locale("en")`, `Locale.US`, `Locale.ENGLISH` passed to `NumberFormat`, `DateFormat`,
  or `SimpleDateFormat`
- `context.resources.configuration.setLocale(Locale("en"))` called at runtime
- `AppCompatDelegate.setApplicationLocales(LocaleList.forLanguageTags("en"))` called
  without user action

---

### Rule 9 — Missing translations / no fallback

**What AI does:** adds a string key to a locale-qualified `values-XX/strings.xml` but
not to the base `values/strings.xml`, or ships keys with no locale-qualified file at all
and no fallback strategy.

**Red-flags:**
- A key in `values-fr/strings.xml` not present in `values/strings.xml`
- A `stringResource()` call for a key that does not exist in `values/strings.xml`
- An app targeting multiple locales with no locale-qualified `values-*/` directories at all
  (relying entirely on the base file, which is fine, but flag if a translation is expected)

---

### Rule 10 — Text baked into images

**What AI does:** includes user-facing copy inside a drawable, bitmap, or WebP asset, or
uses a culture-specific icon with no localized alternative.

**Red-flags:**
- A `drawable*/` resource file whose name or content description implies it contains
  English text (e.g., `button_submit.png`, `banner_sale_en.webp`)
- An `Image()` or `<ImageView>` rendering an asset where the design shows text overlaid
  in the asset rather than as a separate `Text()` composable
- A single non-locale-qualified image asset used for content that varies by culture
  (currency symbols, directional arrows baked into illustrations)

---

## Halt conditions

Halt immediately and report when any of the 10 guard rules fires. Do not silently pass
code that contains a hardcoded string, manual plural, non-RTL layout, hardcoded locale,
or text-in-image. Output the rule number, the offending code snippet, and the correction
pattern. Do not propose workarounds that leave the underlying violation in place.

### Output on halt

```
## i18n guard — halt

Rule [N] — [Rule name]

Offending code:
  [snippet]

Why this breaks i18n:
  [one sentence]

Correction pattern:
  [minimal fix — resource key / pluralStringResource / start-end / formatter call]

See: platforms/android/skills/android-i18n/reference.md — Rule [N]
```

## References

- Android string resources: https://developer.android.com/guide/topics/resources/string-resource
- Plurals: https://developer.android.com/guide/topics/resources/string-resource#Plurals
- RTL support: https://developer.android.com/training/basics/supporting-devices/languages#FormatTextFields
- Locale-aware formatting: https://developer.android.com/reference/java/text/NumberFormat
- android.icu: https://developer.android.com/reference/android/icu/text/package-summary
- Team baseline: [`../../guidance.md`](../../guidance.md)
- A11y labels also need translation: [`../android-accessibility/SKILL.md`](../android-accessibility/SKILL.md)
- Code samples, bad → good pairs for all 10 rules: [`reference.md`](reference.md)

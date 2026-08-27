---
name: kmp-i18n
description: KMP Compose Multiplatform internationalization guard — translation keys, ICU pluralization, named placeholders, locale-aware date/number/currency formatting via kotlinx-datetime + expect/actual formatters, and RTL-safe layout via Compose layout direction, plus detect/block the i18n anti-patterns AI ships (hardcoded user-facing strings, sentence concatenation, manual pluralization, hardcoded date/number/currency formats, hardcoded start/end layout, missing placeholders, hardcoded locale, missing translations, text baked into images). Auto-loads when writing or reviewing user-facing UI text.
when_to_use: When adding/reviewing user-facing text, formatting dates/numbers/currency, handling plurals, or laying out UI, or on requests like "is this localizable", "add i18n", "does this support RTL".
paths: "**/commonMain/**/*.kt, **/composeResources/**/*.xml, **/composeResources/values*/*.xml, **/ui/**/*.kt, **/*Screen.kt"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-i18n — localization guard

AI-generated Compose Multiplatform UI is **English-hardcoded**: it writes `Text("Submit")` instead
of a resource key, builds sentences from concatenated fragments (which breaks in languages with
different word order), hand-rolls pluralization with `if (count > 1) "s" else ""`, hard-codes
`"MM/dd/yyyy"` and `"$"`, and lays out with fixed start/end so Arabic and Hebrew break.
Retrofitting i18n after the fact is expensive and error-prone; this skill is a **write-time
guard** that catches every failure mode before it ships, and gives the correct KMP i18n
pattern for each one.

These rules are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the i18n floor is never lowered.

## Scope

- In scope: user-facing strings via `compose.components.resources` (`stringResource`) or
  moko-resources (`MR.strings`), ICU plurals in XML/resource files, named placeholders,
  locale-aware formatting via `kotlinx-datetime` + `expect`/`actual` formatters and
  `java.text.NumberFormat` / `NSNumberFormatter` behind `expect`/`actual`,
  RTL-safe layout via `LayoutDirection` and `Arrangement.Start`/`End`.
- Delegate to adjacent skills: accessible labels (which also need translation) →
  [kmp-accessibility](../kmp-accessibility/SKILL.md); CJK/RTL typography scaling →
  [kmp-design-system](../kmp-design-system/SKILL.md); composable decomposition →
  [kmp-architecture](../kmp-architecture/SKILL.md).
- Reality: every string that reaches a user must be translatable at write time. A string
  hardcoded today becomes a regression to chase in every future locale.

## Core Guidance (Do)

- **Externalize all user-facing strings to resource files.** With `compose.components.resources`
  (Compose Resources), add an entry to `composeResources/values/strings.xml` and reference it
  as `stringResource(Res.string.my_key)`. With moko-resources, reference `MR.strings.my_key`.
  Never render a string literal where a user can see it.
- **Use ICU plural syntax in string resources.** With moko-resources, write ICU plural messages
  (`{count, plural, =0{No items} =1{One item} other{{count} items}}`). With Compose Resources,
  use `pluralStringResource(Res.plurals.item_count, count, count)` backed by quantity strings
  in the resource XML. Never write a Kotlin ternary for plurals.
- **Use named placeholders for interpolated values.** The resource entry holds `"Hello, %s!"`
  (Compose Resources) or an ICU pattern `"Hello, {name}!"` (moko) and Kotlin passes the value
  via `stringResource(Res.string.greeting, user.name)` or `MR.strings.greeting.format(name)`.
  This lets translators reorder the placeholder to match their language's grammar.
- **Format dates and numbers with locale-aware `expect`/`actual` formatters.**
  In `commonMain`, declare an `expect fun formatDate(instant: Instant, locale: AppLocale): String`.
  In `androidMain`, implement with `java.text.SimpleDateFormat`; in `iosMain`, implement with
  `NSDateFormatter`. Never build a date or currency string by hand.
- **Use `LayoutDirection`-aware Compose APIs.** Prefer `PaddingValues` from
  `WindowInsets.asPaddingValues()`, `Arrangement.Start`/`End` instead of `Start`/`End` hard-coded
  to LTR direction, `Alignment.Start`/`End` instead of `Alignment.Left`/`Right`, and
  `TextAlign.Start`/`End` instead of `TextAlign.Left`/`Right`. The Compose layout system
  automatically mirrors `Start`/`End` in RTL.
- **Declare a fallback locale.** Configure `supportedLocales` and a fallback in your
  `MaterialApp` / root composable entry point. Never let a missing translation surface a
  blank or key string.

## Guard Rules (Mode B) — the 10 i18n failure modes

Each item: **rule → the failure AI commonly produces → red-flag**. Bad/good code pairs in
[reference.md](./reference.md).

### 1. Hardcoded user-facing string

- **Rule**: every string a user reads must come from a resource key (`stringResource`,
  `MR.strings`). There are no literal strings in `Text(…)`, `SnackbarDuration`,
  button labels, hint text, tooltip text, or `contentDescription`.
- **Common AI failure**: `Text("Submit")`, `placeholder = { Text("Enter email") }`,
  `label = { Text("Password") }` — the whole app in English with no resource entries.
- **red-flag**: a string literal passed to `Text`, `placeholder`, `label`, `supportingText`,
  `contentDescription`, `Snackbar`, or any composable that renders text to the user.

### 2. Sentence concatenation

- **Rule**: never build a translated sentence from multiple `stringResource` calls joined
  with `+` or string templates. The concatenated order is correct in English but wrong
  in many other languages. Use a single keyed string with named placeholders.
- **Common AI failure**: `stringResource(Res.string.youHave) + " $count " + stringResource(Res.string.items)`,
  or `"${stringResource(Res.string.hello)} ${user.name}"` where word order differs per language.
- **red-flag**: two or more `stringResource`/`MR.strings` calls joined by `+` or `${}` in the
  same expression, producing a sentence from parts.

### 3. Manual pluralization

- **Rule**: plural forms must use ICU `plural` syntax in the resource file (moko) or
  `pluralStringResource` backed by `<plurals>` XML (Compose Resources). Never write
  `if (count == 1) "item" else "items"` or `"$count item${ if (count != 1) "s" else "" }"`.
- **Common AI failure**: `Text("$count ${if (count == 1) "message" else "messages"}")`,
  `+ "s"` pluralization anywhere in Kotlin composable code.
- **red-flag**: an `if`/`when` expression choosing between singular and plural forms in
  Kotlin UI code, rather than delegating to a resource plural key.

### 4. Hardcoded date/time format

- **Rule**: never write a format pattern like `"MM/dd/yyyy"` or `"HH:mm"` directly in
  `commonMain` UI code. Use a `kotlinx-datetime` `Instant`/`LocalDate` with an
  `expect`/`actual` formatter that delegates to `SimpleDateFormat(locale)` on Android
  and `NSDateFormatter` on iOS.
- **Common AI failure**: `SimpleDateFormat("MM/dd/yyyy").format(date)` called directly in
  `commonMain` (won't compile) or in `androidMain` without a locale,
  `"${date.month}/${date.dayOfMonth}/${date.year}"` hand-built in a composable.
- **red-flag**: a literal date format pattern string in composable/UI code, or manual
  `date.month`/`date.dayOfMonth`/`date.year` concatenation for display.

### 5. Hardcoded number/currency

- **Rule**: never prefix `"$"` or hard-code decimal/grouping separators. Use an
  `expect`/`actual` formatter backed by `NumberFormat.getCurrencyInstance(locale)` on
  Android and `NSNumberFormatter` on iOS. The locale determines grouping, decimal
  point, and currency symbol position.
- **Common AI failure**: `"$$price"`, `"${price.toString()}"` in a `Text` composable,
  hand-formatted thousands separators.
- **red-flag**: a literal currency symbol (`$`, `€`, `£`, `¥`) concatenated with a number
  in Kotlin UI code, or `.toString()` / `String.format("%.2f", …)` used directly for
  user-facing display.

### 6. Non-RTL-safe layout

- **Rule**: use `LayoutDirection`-aware Compose APIs so the UI mirrors correctly in RTL
  locales (Arabic, Hebrew, Farsi). Use `Arrangement.Start`/`End`, `Alignment.Start`/`End`,
  `TextAlign.Start`/`End`, and `PaddingValues` with logical sides. Wrap subtrees that load
  locale asynchronously in `CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl)`.
- **Common AI failure**: `Arrangement.Start` used correctly but `Modifier.padding(start = 16.dp,
  end = 0.dp)` used — these are logical, correct. The failure is `Alignment.CenterHorizontally`
  replaced with hard `Alignment.Left`/`Alignment.Right`.
- **red-flag**: `Alignment.Left` / `Alignment.Right` for logical alignment,
  `TextAlign.Left` / `TextAlign.Right` in text that may be RTL.

### 7. Missing placeholders

- **Rule**: any string that interpolates a value (name, count, date, entity) must declare
  that value as a placeholder in the resource entry so translators can reorder it. Never
  concatenate a dynamic value into a resource key call after the fact.
- **Common AI failure**: resource entry `"greeting"` = `"Hello!"` used as
  `"${stringResource(Res.string.greeting)} $name"` — the placeholder is invisible to
  translators; they cannot reorder it.
- **red-flag**: a dynamic value appended to or prepended to a `stringResource`/`MR.strings`
  call outside of the resource key, bypassing the placeholder mechanism.

### 8. Hardcoded locale

- **Rule**: never pass a hardcoded `Locale("en")` or `"en_US"` to a formatter or to the
  root composable's locale resolution when you mean "use the user's system locale". Use
  the device locale from `Locale.getDefault()` (Android) or `NSLocale.currentLocale`
  (iOS) via an `expect`/`actual` provider.
- **Common AI failure**: `SimpleDateFormat("yMMMd", Locale.US)` always formatting in US
  English in `androidMain`, `NumberFormat.getCurrencyInstance(Locale.US)` regardless of
  user locale.
- **red-flag**: a string literal like `"en"`, `"en_US"` or `Locale.US` / `Locale.ENGLISH`
  passed to a formatter in platform source sets where the user/system locale should be used.

### 9. Missing translations / no fallback

- **Rule**: every resource key defined in `values/strings.xml` (base locale) must exist in
  all other `values-*/strings.xml` locale files, or the app must declare a fallback locale
  strategy. A missing key surfaces as a crash or blank string — both are bugs.
- **Common AI failure**: adding a new key to `values/strings.xml` but not to `values-ar/strings.xml`,
  `values-es/strings.xml`, etc.; no fallback locale configured.
- **red-flag**: a key present in the base strings.xml but absent in one or more other locale
  files; no fallback locale strategy in the app's root composable configuration.

### 10. Text baked into images

- **Rule**: user-facing text must never be rasterized inside an image asset. Images with
  embedded text cannot be translated and are invisible to screen readers. Use Compose `Text`
  composables overlaid on images, or provide per-locale image variants as a last resort.
- **Common AI failure**: a PNG banner with "Welcome!" baked in, a button with text drawn
  inside an SVG, culture-specific icons (e.g., a US-flag icon for "English") with no
  localized alternative.
- **red-flag**: image asset filenames that include text (e.g., `welcome_banner_en.png`)
  used without locale variants, or a `Canvas.drawText`/`TextPainter`-equivalent in
  `DrawScope` without a parallel `Text` composable for a11y and i18n.

## i18n review checklist

For Compose Multiplatform UI code that AI generated or was pasted in quickly, before merge:

- [ ] All `Text(…)` / `placeholder` / `label` / `contentDescription` values come from `stringResource`/`MR.strings`.
- [ ] No sentence built by joining multiple resource calls with `+` or `${}`.
- [ ] Plural forms use ICU/`<plurals>` XML — no `if`/ternary pluralization in Kotlin.
- [ ] Dates formatted via `expect`/`actual` formatter using device locale — no literal patterns.
- [ ] Currency/numbers formatted via `expect`/`actual` formatter — no `"$"` concatenation.
- [ ] Layout uses `Arrangement.Start`/`End`, `Alignment.Start`/`End`, `TextAlign.Start`/`End` — no hard Left/Right.
- [ ] Dynamic values declared as placeholders in resource entries — not appended after the key call.
- [ ] No hardcoded `Locale("en")` / `Locale.US` where device locale should be used.
- [ ] New resource keys added to all locale files; fallback locale declared.
- [ ] No user-facing text baked into image assets; `DrawScope.drawText` paired with a `Text` composable.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Bad/good Kotlin samples per rule: [reference.md](./reference.md)
- Adjacent (a11y labels also need translation): [kmp-accessibility](../kmp-accessibility/SKILL.md)
- Umbrella: [kmp-architecture](../kmp-architecture/SKILL.md)
- Compose Resources (multiplatform): https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-multiplatform-resources-usage.html
- moko-resources: https://github.com/icerockdev/moko-resources
- kotlinx-datetime: https://github.com/Kotlin/kotlinx-datetime
- ICU message format: https://unicode-org.github.io/icu/userguide/format_parse/messages/
- CLDR plural rules: https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html

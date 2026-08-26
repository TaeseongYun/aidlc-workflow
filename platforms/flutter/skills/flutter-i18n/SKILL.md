---
name: flutter-i18n
description: Flutter internationalization guard — translation keys, ICU pluralization, named
  placeholders, locale-aware date/number/currency formatting, and RTL-safe layout, plus
  detect/block the i18n anti-patterns AI ships (hardcoded user-facing strings, sentence
  concatenation, manual pluralization, hardcoded date/number/currency formats, hardcoded
  left/right layout, missing placeholders, hardcoded locale, missing translations, text
  baked into images). Auto-loads when writing or reviewing user-facing UI text.
when_to_use: When adding/reviewing user-facing text, formatting dates/numbers/currency,
  handling plurals, or laying out UI, or on requests like "is this localizable", "add i18n",
  "does this support RTL".
paths: "**/lib/**/*.dart, **/l10n/**,  **/*.arb, **/l10n.yaml"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-i18n — localization guard

AI-generated Flutter UI is **English-hardcoded**: it writes `Text("Submit")` instead of
a translation key, builds sentences from concatenated fragments (which breaks in languages
with different word order), hand-rolls pluralization with `count > 1 ? "s" : ""`, hard-codes
`MM/dd/yyyy` and `"\$"`, and lays out with fixed left/right so Arabic and Hebrew break.
Retrofitting i18n after the fact is expensive and error-prone; this skill is a **write-time
guard** that catches every failure mode before it ships, and gives the correct Flutter i18n
pattern for each one.

These rules are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the i18n floor is never lowered.

## Scope

- In scope: user-facing strings, ARB/`gen_l10n` key discipline, ICU plurals and placeholders,
  locale-aware `NumberFormat`/`DateFormat` and `Intl`, RTL-safe layout with `Directionality`
  and `TextDirection`, fallback locale configuration.
- Delegate to adjacent skills: accessible labels (which also need translation) →
  [flutter-accessibility](../flutter-accessibility/SKILL.md); CJK/RTL typography scaling →
  [flutter-design-system]; widget decomposition → [flutter-architecture].
- Reality: every string that reaches a user must be translatable at write time. A string
  hardcoded today becomes a regression to chase in every future locale.

## Core Guidance (Do)

- **Externalize all user-facing strings to ARB keys.** Add an entry to
  `lib/l10n/app_en.arb` and reference it as `AppLocalizations.of(context)!.myKey`.
  Never render a string literal where a user can see it.
- **Use ICU plural syntax in ARB.** Write `{count, plural, =0{No items} =1{One item} other{{count} items}}`
  inside the ARB file rather than any Dart ternary.
- **Use named placeholders for interpolated values.** The ARB entry holds
  `"Hello, {name}!"` and Dart passes `appLocalizations.hello(name: user.name)`.
  This lets translators reorder the placeholder to match their language's grammar.
- **Format dates and numbers with locale-aware formatters.** Use `DateFormat` and
  `NumberFormat` from the `intl` package, initialized from the current locale
  (`Localizations.localeOf(context).toString()`). Never build a date or currency string by
  hand.
- **Use `Directionality` and logical layout.** Prefer `EdgeInsetsDirectional.only(start: …)`
  over `EdgeInsets.only(left: …)`, `Alignment.centerRight` → `AlignmentDirectional.centerEnd`,
  `CrossAxisAlignment.start` (already direction-aware in `Row`). Wrap subtrees that load
  locale asynchronously in `Directionality(textDirection: …)`.
- **Declare a fallback locale.** Pass `supportedLocales` and `localizationsDelegates` in
  `MaterialApp`, and set `locale` to a fallback (`const Locale('en')`) when the system locale
  is unsupported — never let a missing translation surface a blank or key string.

## Guard Rules (Mode B) — the 10 i18n failure modes

Each item: **rule → the failure AI commonly produces → red-flag**. Bad/good code pairs in
[reference.md](./reference.md).

### 1. Hardcoded user-facing string

- **Rule**: every string a user reads must come from `AppLocalizations`. There are no
  literal strings in `Text(...)`, `SnackBar(content: Text(...))`, button labels, hint text,
  tooltip text, or `semanticsLabel`.
- **Common AI failure**: `Text("Submit")`, `hintText: "Enter email"`, `label: "Password"` —
  the whole app in English with no ARB entries.
- **red-flag**: a string literal passed to `Text`, `hintText`, `labelText`, `tooltip`,
  `semanticsLabel`, `SnackBar`, or any widget that renders text to the user.

### 2. Sentence concatenation

- **Rule**: never build a translated sentence from multiple `AppLocalizations` calls joined
  with `+` or string interpolation. The concatenated order is correct in English but wrong
  in many other languages. Use a single keyed string with named placeholders.
- **Common AI failure**: `appL.youHave + " $count " + appL.items`, or
  `Text("${appL.hello} ${user.name}")` where word order differs per language.
- **red-flag**: two or more `AppLocalizations` calls joined by `+` or `${}` in the same
  expression, producing a sentence from parts.

### 3. Manual pluralization

- **Rule**: plural forms must use ICU `plural` syntax inside the ARB file, generated via
  `gen_l10n`. Never write `count == 1 ? "item" : "items"` or `"$count item${ count != 1 ? 's' : '' }"`.
- **Common AI failure**: `Text("$count ${count == 1 ? 'message' : 'messages'}")`,
  `"+ 's'"` pluralization anywhere in Dart code.
- **red-flag**: a ternary expression or `+ 's'` in a Dart string that is choosing between
  singular and plural forms, rather than delegating to an ARB plural key.

### 4. Hardcoded date/time format

- **Rule**: never write a format string like `"MM/dd/yyyy"` or `"HH:mm"` directly in Dart
  UI code. Use `DateFormat` from the `intl` package initialized with the current locale, or
  use a `DateFormat` named constructor (`DateFormat.yMMMd(locale)`) that selects the
  locale-correct format automatically.
- **Common AI failure**: `DateFormat("MM/dd/yyyy").format(date)` with no locale,
  `"${date.month}/${date.day}/${date.year}"` hand-built in a widget.
- **red-flag**: a literal date format pattern string in Dart UI code, or manual
  `date.month`/`date.day`/`date.year` concatenation for display.

### 5. Hardcoded number/currency

- **Rule**: never prefix `"$"` or hard-code decimal/grouping separators. Use
  `NumberFormat.currency(locale: locale, symbol: ...)` or `NumberFormat.compact(locale)`
  from the `intl` package. The locale determines grouping, decimal point, and currency symbol
  position.
- **Common AI failure**: `"\$$price"`, `"${price.toStringAsFixed(2)}"` in a `Text` widget,
  hand-formatted thousands separators.
- **red-flag**: a literal currency symbol (`$`, `€`, `£`, `¥`) concatenated with a number
  in Dart UI code, or `toStringAsFixed` used directly for user-facing display.

### 6. Non-RTL-safe layout

- **Rule**: use directional layout APIs so the UI mirrors correctly in RTL locales (Arabic,
  Hebrew, Farsi). Use `EdgeInsetsDirectional` instead of `EdgeInsets.only(left/right)`,
  `AlignmentDirectional` instead of `Alignment.centerLeft`/`centerRight`,
  `TextAlign.start`/`end` instead of `left`/`right`, and `Directionality` to wrap subtrees
  that need an explicit direction.
- **Common AI failure**: `padding: EdgeInsets.only(left: 16)`, `alignment: Alignment.centerLeft`,
  `TextAlign.left` — all hard-wired to LTR, breaking Arabic/Hebrew layouts.
- **red-flag**: `EdgeInsets.only(left:...)` or `EdgeInsets.only(right:...)` for logical
  spacing, `Alignment.centerLeft`/`centerRight` for logical alignment, `TextAlign.left`/
  `TextAlign.right` in text that may be RTL.

### 7. Missing placeholders

- **Rule**: any string that interpolates a value (name, count, date, entity) must declare
  that value as a named placeholder in the ARB entry so translators can reorder it. Never
  concatenate a dynamic value into a keyed string after the fact.
- **Common AI failure**: ARB entry `"greeting": "Hello!"` used as `"${appL.greeting} $name"`
  — the placeholder is invisible to translators; they cannot reorder it.
- **red-flag**: a dynamic value appended to or prepended to an `AppLocalizations` call
  outside of the ARB key, bypassing the placeholder mechanism.

### 8. Hardcoded locale

- **Rule**: never pass a hardcoded `Locale("en")` or `"en_US"` to a formatter or to
  `MaterialApp`'s `locale:` property when you mean "use the user's system locale". Use
  `Localizations.localeOf(context)` or let Flutter resolve the locale from
  `supportedLocales`.
- **Common AI failure**: `DateFormat("yMMMd", "en_US")` always formatting in US English,
  `NumberFormat.currency(locale: "en_US")` regardless of user locale,
  `locale: const Locale("en")` hard-wired in `MaterialApp`.
- **red-flag**: a string literal like `"en"`, `"en_US"` passed to a formatter constructor
  or to `MaterialApp(locale: ...)` where the user/system locale should be used instead.

### 9. Missing translations / no fallback

- **Rule**: every ARB key defined in `app_en.arb` must exist in all other language ARB files,
  or the app must declare a fallback locale (`MaterialApp(localeResolutionCallback: ...)`
  or rely on Flutter's built-in fallback). A missing key surfaces as an exception at runtime
  or a blank string — both are bugs.
- **Common AI failure**: adding a new key to `app_en.arb` but not to `app_es.arb`,
  `app_ar.arb`, etc.; no `localeResolutionCallback`; no `supportedLocales` list that
  triggers Flutter's fallback to `app_en.arb`.
- **red-flag**: a key present in the base ARB file but absent in one or more other ARB
  files, or `MaterialApp` with no `supportedLocales` / no fallback locale strategy.

### 10. Text baked into images

- **Rule**: user-facing text must never be rasterized inside an image asset. Images with
  embedded text cannot be translated and are invisible to screen readers. Use Flutter `Text`
  widgets overlaid on images, or provide per-locale image variants as a last resort.
- **Common AI failure**: a PNG banner with "Welcome!" baked in, a button with text drawn
  inside an SVG, culture-specific icons (e.g., a US-flag icon for "English") with no
  localized alternative.
- **red-flag**: image asset filenames that include text (e.g., `welcome_banner_en.png`
  used without locale variants), or a `CustomPainter` that draws a user-readable string
  via `canvas.drawText` / `TextPainter` without a parallel `Text` widget for a11y and i18n.

## i18n review checklist

For Flutter UI code that AI generated or was pasted in quickly, before merge:

- [ ] All `Text(...)` / `hintText` / `labelText` / `tooltip` values come from `AppLocalizations`.
- [ ] No sentence built by joining multiple `AppLocalizations` calls with `+` or `${}`.
- [ ] Plural forms use ICU `{count, plural, …}` in ARB — no ternary pluralization in Dart.
- [ ] Dates formatted with `DateFormat(locale)` or a locale-named constructor — no literal patterns.
- [ ] Currency/numbers formatted with `NumberFormat.currency(locale: …)` — no `"$"` concatenation.
- [ ] Layout uses `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end` — no hard left/right.
- [ ] Dynamic values declared as named placeholders in ARB — not appended after the key call.
- [ ] No hardcoded `Locale("en")` / `"en_US"` where user locale should be used.
- [ ] New ARB keys added to all locale files; fallback locale declared in `MaterialApp`.
- [ ] No user-facing text baked into image assets; `CustomPainter` text paired with a `Text` widget.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Bad/good Dart samples per rule: [reference.md](./reference.md)
- Adjacent (a11y labels also need translation): [flutter-accessibility](../flutter-accessibility/SKILL.md)
- Umbrella: [flutter-architecture](../flutter-architecture/SKILL.md)
- Flutter i18n guide: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- `intl` package: https://pub.dev/packages/intl
- ARB file format: https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification
- `gen_l10n` reference: https://api.flutter.dev/flutter/flutter_localizations/GlobalMaterialLocalizations-class.html
- ICU message format: https://unicode-org.github.io/icu/userguide/format_parse/messages/

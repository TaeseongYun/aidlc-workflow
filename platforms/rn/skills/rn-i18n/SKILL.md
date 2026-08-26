---
name: rn-i18n
description: React Native internationalization guard — translation keys, ICU pluralization, named placeholders,
  locale-aware date/number/currency formatting, and RTL-safe layout, plus detect/block the i18n anti-patterns
  AI ships (hardcoded user-facing strings, sentence concatenation, manual pluralization, hardcoded date/number/
  currency formats, hardcoded left/right layout, missing placeholders, hardcoded locale, missing translations,
  text baked into images). Auto-loads when writing or reviewing user-facing UI text.
when_to_use: When adding/reviewing user-facing text, formatting dates/numbers/currency, handling plurals,
  or laying out UI, or on requests like "is this localizable", "add i18n", "does this support RTL".
paths: **/*.tsx, **/*.ts, **/locales/**, **/*.json
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-i18n — i18n guard

AI-generated React Native UI is **English-hardcoded**: it writes literal user-facing
strings instead of translation keys, concatenates translated fragments (which breaks
in languages with different word order), hand-rolls pluralization with
`count > 1 ? "s" : ""`, hardcodes `MM/DD/YYYY` and `$` formats, and lays out with
fixed `left`/`right` so RTL languages break. Retrofitting i18n after the fact is
expensive — this skill is the **guard** that catches it at write time, plus
**guidance** on resource keys, ICU plurals, named placeholders, locale-aware
formatters, and RTL-safe layout.

These are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the i18n floor is never lowered.

## Scope

- In scope: externalizing user-facing strings to translation keys, ICU pluralization,
  named placeholders, locale-aware date/number/currency formatting, RTL-safe layout
  with `I18nManager` + logical (`start`/`end`) styles, fallback locale config.
- Covers: RN source (TS/TSX), catalog files (`locales/**/*.json`).
- Delegate: accessible labels on controls also need translation →
  [rn-accessibility](../rn-accessibility/SKILL.md); CJK/RTL typography metrics →
  [rn-design-system]; component and navigation architecture → [rn-architecture].
- Reality: **a11y labels are translatable strings** — `accessibilityLabel` values
  must use translation keys, not hardcoded English. Coordinate with rn-accessibility.

## Core guidance (Do)

- **Externalize all user-facing strings.** Every string visible to users lives in a
  keyed catalog (`locales/en.json`, etc.) and is accessed via `t('key')` (i18next /
  react-i18next) or `intl.formatMessage({ id: 'key' })` (react-intl). Never pass a
  string literal directly to `<Text>`, `accessibilityLabel`, `placeholder`, `title`, etc.
- **Use ICU plural rules.** Count-dependent text uses the `count` interpolation with
  ICU plural syntax: `"items": "{{count}} item"` / `"items_other": "{{count}} items"`
  (i18next) or `"{count, plural, one {# item} other {# items}}"` (react-intl). Never
  hand-roll `count === 1 ? 'item' : 'items'`.
- **Named placeholders only.** Dynamic values in translations use named placeholders
  so translators can reorder: `"greeting": "Hello, {{name}}!"` — not string
  concatenation.
- **Locale-aware formatters.** Dates, times, numbers, and currency go through `Intl`
  (or a polyfill for Hermes/JSC): `Intl.DateTimeFormat`, `Intl.NumberFormat`. Never
  construct `"$" + price.toFixed(2)` or `MM/DD/YYYY` patterns by hand.
- **RTL-safe layout.** Use `flexDirection: 'row'` (flex already flips for RTL) and
  logical margin/padding props: `marginStart`/`marginEnd`, `paddingStart`/`paddingEnd`.
  Check `I18nManager.isRTL` for conditional icon/arrow mirroring. Never use
  `marginLeft`/`marginRight` or absolute `left`/`right` in layout-direction-sensitive
  positions.
- **Provide a fallback locale.** Configure a `fallbackLng` (i18next) or
  `defaultLocale` (react-intl) so missing keys degrade gracefully to a known language,
  never silently blank or key-leaking.

## Guard rules — 10 i18n failure modes (must not be relaxed)

Each item: **rule → common AI failure → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded user-facing string

- **Rule**: every string the user reads lives in a keyed catalog and is rendered via
  the translation function. No literal UI text in JSX or prop values.
- **Common AI failure**: `<Text>Submit</Text>`, `placeholder="Search…"`,
  `accessibilityLabel="Close"` hardcoded in English.
- **red-flag**: a string literal inside `<Text>`, `placeholder=`, `title=`,
  `accessibilityLabel=`, `Toast.show(`, or any other user-visible prop.

### 2. Sentence concatenation

- **Rule**: translated strings are atomic — never split a sentence across multiple
  `t()` calls and concatenate the fragments. Word order differs across languages.
- **Common AI failure**: `t('you_have') + ' ' + count + ' ' + t('items')`.
- **red-flag**: `t(…) + …` or template literals mixing `t()` calls with raw text or
  variables; multiple `t()` calls glued together to form one sentence.

### 3. Manual pluralization

- **Rule**: count-dependent text uses ICU plural categories (`one`/`other`/`few`/etc.)
  via the i18n library's plural support. The library handles language-specific rules.
- **Common AI failure**: `count === 1 ? t('item') : t('items')`, `t('item') + 's'`.
- **red-flag**: a ternary or `+ 's'` on a translated string for count-driven text;
  `count > 1` branching to pick between two translation keys.

### 4. Hardcoded date/time format

- **Rule**: dates and times are formatted with `Intl.DateTimeFormat` (or the
  react-intl `FormattedDate`/`FormattedTime` components), never with a manually
  constructed pattern string.
- **Common AI failure**: `format(date, 'MM/dd/yyyy')` (hand-rolled or from a util),
  `` `${date.getMonth()+1}/${date.getDate()}/${date.getFullYear()}` ``.
- **red-flag**: any manual date-format string (`'MM/dd/yyyy'`, `'DD-MM-YYYY'`,
  template-literal date assembly) in a UI context.

### 5. Hardcoded number/currency

- **Rule**: currency amounts, large numbers, and percentages use
  `Intl.NumberFormat` (or `FormattedNumber`/`FormattedCurrency` from react-intl).
  The formatter picks the correct decimal separator, grouping, and currency symbol
  for the user's locale.
- **Common AI failure**: `` `$${price.toFixed(2)}` ``, `(price / 100).toFixed(2) + ' USD'`.
- **red-flag**: a literal currency symbol (`$`, `€`, `¥`) in a string, `.toFixed()`
  on a displayed price, hand-formatted thousands separators.

### 6. Non-RTL-safe layout

- **Rule**: layout must be direction-agnostic. Use `marginStart`/`marginEnd`,
  `paddingStart`/`paddingEnd`, and `alignSelf: 'flex-start'`/`'flex-end'`. For
  conditional directional logic (icons, arrows), gate on `I18nManager.isRTL`.
- **Common AI failure**: `marginLeft: 8`, `paddingRight: 16`, `left: 0` in a
  container style; an arrow icon that always points right.
- **red-flag**: `marginLeft`, `marginRight`, `paddingLeft`, `paddingRight`, or an
  absolute `left:`/`right:` value in a layout-direction-sensitive style; no
  `I18nManager.isRTL` check for icons/arrows that must mirror.

### 7. Missing placeholders

- **Rule**: any dynamic value inside a translated string must be a named placeholder
  in the catalog entry so translators can reorder it. No fragment concatenation.
- **Common AI failure**: splitting a string into key + variable + key, e.g.
  `t('sent') + ' ' + name + ' ' + t('a_message')`.
- **red-flag**: a variable concatenated onto a `t()` result; a catalog entry with a
  blank gap where a dynamic value will be inserted via concatenation rather than
  `{{placeholder}}`.

### 8. Hardcoded locale

- **Rule**: the active locale comes from the device/user preference. Never pass a
  hardcoded `'en'` or `'en-US'` to a formatter or to the i18n library's init config
  as the sole locale.
- **Common AI failure**: `new Intl.DateTimeFormat('en-US', …).format(date)`,
  `i18next.init({ lng: 'en' })` with no device-locale detection.
- **red-flag**: a string locale literal (`'en'`, `'en-US'`, `'ja-JP'`) passed to
  `Intl.*`, a formatter, or the i18n library init instead of a resolved device locale.

### 9. Missing translations / no fallback

- **Rule**: every key used in code must exist in every supported locale's catalog,
  or a fallback locale must be configured (`fallbackLng` / `defaultLocale`) so
  missing keys degrade to a known language rather than showing the key string or blank.
- **Common AI failure**: adding a new `t('new_key')` call without adding the entry to
  all locale files; no `fallbackLng` configured in i18next init.
- **red-flag**: a `t('key')` call whose key is absent from one or more locale JSON
  files; an i18next/react-intl init with no fallback locale.

### 10. Text baked into images

- **Rule**: user-facing text is never rendered inside image assets. All readable
  content is composed as RN `<Text>` elements over or alongside the image so it can
  be translated, scaled, and read by screen readers.
- **Common AI failure**: a banner or button image with the label text drawn into the
  PNG/SVG; a culture-specific icon (thumbs up, hand gesture) used as the sole signal
  with no localized alternative.
- **red-flag**: a `<Image>` whose source contains visible text (filename hints like
  `banner_en.png`, `submit_button.png`); a static asset serving as a label with no
  accompanying translatable `<Text>` or `accessibilityLabel`.

## i18n review checklist

For UI code that AI generated or was pasted in quickly, before merge:

- [ ] No literal user-facing strings in JSX or props — all go through `t()` / `intl.formatMessage`.
- [ ] No sentence concatenation from multiple `t()` calls — use named placeholders.
- [ ] Count-dependent text uses ICU plurals, not ternary/`+` pluralization.
- [ ] Dates/times formatted with `Intl.DateTimeFormat` or react-intl components, not manual patterns.
- [ ] Numbers/currency formatted with `Intl.NumberFormat` or react-intl, not literal `$` + `.toFixed()`.
- [ ] Layout uses `marginStart`/`marginEnd`/`paddingStart`/`paddingEnd`; directional icons gated on `I18nManager.isRTL`.
- [ ] Dynamic values in catalog entries use `{{named}}` placeholders, not concatenation.
- [ ] Active locale resolved from device; no hardcoded `'en'`/`'en-US'` in formatters or init.
- [ ] All new `t('keys')` exist in every locale catalog; `fallbackLng` / `defaultLocale` configured.
- [ ] No text baked into image assets; all user-readable content is `<Text>` or `accessibilityLabel`.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Bad→good code samples (all 10 rules): [reference.md](./reference.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- Adjacent — a11y labels also need translation: [rn-accessibility](../rn-accessibility/SKILL.md)
- React Native I18nManager (RTL): https://reactnative.dev/docs/i18nmanager
- i18next / react-i18next: https://www.i18next.com/
- react-intl (FormatJS): https://formatjs.io/docs/react-intl/
- Intl on Hermes (RN): https://hermesengine.dev/docs/intl/
- Unicode CLDR plural rules: https://cldr.unicode.org/index/cldr-spec/plural-rules

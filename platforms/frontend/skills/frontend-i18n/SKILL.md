---
name: frontend-i18n
description: Frontend (web) internationalization guard — translation keys, ICU pluralization,
  named placeholders, locale-aware date/number/currency formatting, and RTL-safe layout,
  plus detect/block the i18n anti-patterns AI ships (hardcoded user-facing strings, sentence
  concatenation, manual pluralization, hardcoded date/number/currency formats, hardcoded
  left/right layout, missing placeholders, hardcoded locale, missing translations, text
  baked into images). Auto-loads when writing or reviewing user-facing UI text.
when_to_use: When adding/reviewing user-facing text, formatting dates/numbers/currency,
  handling plurals, or laying out UI, or on requests like "is this localizable", "add i18n",
  "does this support RTL".
paths: "**/*.tsx, **/*.ts, **/locales/**, **/*.json, **/messages/**"
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-i18n — i18n safety guard

AI-generated web UI is **English-hardcoded by default**: it writes literal
user-facing strings instead of translation keys, concatenates translated
fragments that break in other word orders, hand-rolls `count > 1 ? "s" : ""`
pluralization, pastes `MM/DD/YYYY` and `$` everywhere, and lays out with fixed
`left`/`right` so RTL languages break. Retrofitting i18n after the fact is
expensive — this skill is the **guard** that catches all ten failure modes at
write time, plus prescriptive guidance on the right patterns. The rules here are
**safety rules** and must not be relaxed.

## Scope

- In scope: user-facing text externalization, ICU pluralization, named
  placeholders, locale-aware date/number/currency formatting, RTL-safe layout
  (logical CSS, `dir` attribute).
- Stack: `react-i18next` / `next-intl` / FormatJS ICU messages,
  `Intl.DateTimeFormat` / `Intl.NumberFormat`, `dir="rtl"` + logical CSS
  (`margin-inline-start`, `text-align: start`).
- Delegate: accessible names and labels also need translation →
  [frontend-accessibility](../frontend-accessibility/SKILL.md). Typography
  for CJK/RTL scripts → [frontend-design-system]. Overall architecture →
  [frontend-architecture].
- Read-only: this skill reviews and guards. It does not write application code.

## Core guidance (Do)

- **Externalize all user-facing strings.** Every string a user reads belongs in
  a translation catalog (`locales/en/common.json`, `messages/en.json`, or an
  ICU message file). Reference it with a translation key: `t('submit.button')`,
  `useTranslations('common')('submit')`.
- **Use ICU message format for plurals.** Pass count as a variable inside an
  ICU `{count, plural, one {# item} other {# items}}` message. Never hand-roll
  ternary plurals in component code.
- **Use named placeholders.** Give translators context and word-order freedom:
  `"{name} sent {count} messages"` not concatenated fragments.
- **Use locale-aware formatters.** `Intl.DateTimeFormat(locale)`,
  `Intl.NumberFormat(locale, { style: 'currency', currency })` — never a
  hardcoded date pattern or currency symbol.
- **Use logical CSS for layout.** `margin-inline-start` / `margin-inline-end`,
  `padding-inline-*`, `text-align: start` / `end`, `inset-inline-*`. Avoid
  `left`/`right` in layout-affecting CSS. Set `dir="rtl"` at the `<html>` level
  from the user locale; icon/directional assets mirror with `[dir="rtl"]`.
- **Provide a fallback locale.** Configure `fallbackLng` / `defaultLocale` so a
  missing translation shows the fallback string, not a raw key or blank.

## Guard rules — 10 i18n failure modes (must not be relaxed)

Each item: **rule → common AI failure → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hardcoded user-facing string

- **Rule**: every string a user reads must come from a translation catalog via a
  key. No literal UI text in JSX or template expressions.
- **Common AI failure**: `<button>Submit</button>`, `<p>Welcome back, {name}!</p>`,
  `toast("Saved successfully")` — all rendered as English literals with no
  catalog entry.
- **red-flag**: a string literal inside JSX (`"Submit"`, `'Welcome'`,
  `` `Error: ${msg}` ``) that is user-visible but not wrapped in `t(...)` or
  equivalent.

### 2. Sentence concatenation

- **Rule**: never build a translated sentence by joining translated fragments
  with `+` or template literals. Languages have different word order; fragments
  combine incorrectly.
- **Common AI failure**: `t('youHave') + count + t('items')`,
  `` `${t('hello')}, ${name}` `` — produces ungrammatical output in many
  languages.
- **red-flag**: `t(...)` calls joined with `+` or template-literal interpolation
  where the pieces form a complete sentence.

### 3. Manual pluralization

- **Rule**: pluralization rules vary widely across languages (Arabic has six
  plural forms). Always use ICU plural syntax in the message catalog, or the
  framework's plural API. Never ternary- or suffix-pluralize in component code.
- **Common AI failure**: `count === 1 ? 'item' : 'items'`, `count + ' message' + (count > 1 ? 's' : '')`.
- **red-flag**: a ternary or string concatenation with `"s"` that produces a
  plural, anywhere in component or utility code.

### 4. Hardcoded date/time format

- **Rule**: use `Intl.DateTimeFormat(locale, options)` or a locale-forwarding
  wrapper. Never pass a fixed format string (`"MM/dd/yyyy"`, `"dd-MM-yyyy"`,
  `"YYYY年MM月DD日"`) to a formatter.
- **Common AI failure**: `format(date, 'MM/dd/yyyy')`, `dayjs(d).format('D MMM YYYY')` with a hardcoded pattern and no locale thread-through.
- **red-flag**: a hardcoded date/time format string in a component or utility
  that is not parameterized by locale.

### 5. Hardcoded number/currency

- **Rule**: use `Intl.NumberFormat(locale, { style: 'currency', currency })`.
  Never prepend `"$"`, hardcode thousands separators, or fix decimal places
  without a locale-aware formatter.
- **Common AI failure**: `` `$${price.toFixed(2)}` ``, `'$' + amount`,
  `price.toLocaleString()` (no locale or currency argument).
- **red-flag**: a literal currency symbol in JSX or a `toFixed`/number format
  call with no locale/currency option.

### 6. Non-RTL-safe layout

- **Rule**: use logical CSS properties (`margin-inline-start`, `padding-inline-*`,
  `text-align: start`, `border-inline-start`) and never hardcode `left`/`right`
  in layout-affecting properties. Set `dir` on `<html>` from the active locale.
  Directional icons mirror with `[dir="rtl"] .icon { transform: scaleX(-1) }`.
- **Common AI failure**: `marginLeft: 8`, `style={{ left: 0 }}`,
  `className="text-left pl-4"` — all produce mirrored-wrong layouts in RTL.
- **red-flag**: `marginLeft` / `marginRight`, `paddingLeft` / `paddingRight`,
  `left:` / `right:` in layout (not `position` anchoring), `text-align: left`
  in component styles.

### 7. Missing placeholders

- **Rule**: when a translated string contains dynamic values (names, counts,
  dates), express them as named placeholders inside the message so translators
  can reorder. `t('greeting', { name })` with message `"Hello, {name}!"` — not
  concatenation.
- **Common AI failure**: building a string from pieces rather than putting the
  variable inside the message: `` `${t('hello')} ${name}` ``.
- **red-flag**: a `t(...)` call whose result is immediately concatenated with a
  dynamic value, or a translation key whose message contains no `{placeholder}`
  for a value that varies.

### 8. Hardcoded locale

- **Rule**: derive the locale from the user or system context (Next.js `locale`
  param, `i18next` detected language, `navigator.language`) and thread it through
  to formatters. Never pass a fixed locale string to `Intl.*` or a library
  initializer.
- **Common AI failure**: `new Intl.DateTimeFormat('en-US')`,
  `i18n.changeLanguage('en')` in app bootstrap, `dayjs.locale('en')` hardcoded.
- **red-flag**: a string literal locale (`'en'`, `'en-US'`, `'ko-KR'`) inside a
  formatter call or i18n initializer that should be dynamic.

### 9. Missing translations / no fallback

- **Rule**: every key added to the default catalog must be added to all active
  locale catalogs (or rely on a configured `fallbackLng`). Configure a fallback
  locale so missing keys show readable text, not a raw key string or blank.
- **Common AI failure**: adding a new `t('newFeature.title')` key to
  `en.json` only, leaving `fr.json` / `ja.json` with no entry; no fallback
  configured → blank or key leak in production.
- **red-flag**: a new `t('...')` call whose key appears in only one locale
  catalog; or an i18n init with no `fallbackLng` / `defaultLocale`.

### 10. Text baked into images

- **Rule**: user-facing text must never be rasterized into image assets or SVG
  with `<text>` elements that are not externalized. Culture-specific iconography
  (e.g., a hand gesture or directional arrow) needs a localized or neutral
  alternative.
- **Common AI failure**: a banner image with English text baked in, an SVG
  chart label drawn as a `<text>` node with a hardcoded English string, a
  flag emoji as the only locale indicator.
- **red-flag**: `<img>` or `<svg>` with visible text that is not provided as a
  separate translatable string layered on top; a `<text>` SVG node with a
  hardcoded string.

## i18n review checklist

For any UI code that is new or AI-generated, before merge:

- [ ] All user-visible strings go through `t('key')` / `useTranslations` — no
      literals in JSX.
- [ ] Plurals use ICU `{count, plural, ...}` or equivalent — no ternary/`+"s"`.
- [ ] Dynamic values use named placeholders inside the message — no
      fragment concatenation.
- [ ] Dates/times formatted via `Intl.DateTimeFormat(locale)` — no hardcoded pattern.
- [ ] Numbers/currency formatted via `Intl.NumberFormat(locale, { style, currency })` —
      no `"$"` prefix or `toFixed` without locale.
- [ ] Layout uses logical CSS (`margin-inline-*`, `text-align: start`) — no
      `left`/`right` in layout properties; `dir` set from locale.
- [ ] Locale derived from user/system context — no hardcoded `'en-US'` in formatters.
- [ ] All new keys exist in every active locale catalog (or fallback configured).
- [ ] No user-facing text rasterized into images or SVG text nodes.
- [ ] a11y labels (`aria-label`, `alt`, `placeholder`) also go through `t('key')`
      → [frontend-accessibility](../frontend-accessibility/SKILL.md).

## Halt conditions

Halt (stop and report) if:

- The codebase has no i18n library configured and no translation catalogs — the
  scope of the fix is architectural; escalate rather than patch in place.
- The request is to "skip i18n for now" for user-facing production UI — these
  are safety rules; do not relax.

**Output on halt**:

```
## i18n guard — halted

Halt reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Code examples (bad → good per rule): [reference.md](./reference.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent: [frontend-accessibility](../frontend-accessibility/SKILL.md) — a11y labels also need translation
- react-i18next docs: https://react.i18next.com/
- next-intl docs: https://next-intl-docs.vercel.app/
- FormatJS / ICU message syntax: https://formatjs.io/docs/core-concepts/icu-syntax/
- MDN Intl.DateTimeFormat: https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
- MDN Intl.NumberFormat: https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
- MDN logical properties: https://developer.mozilla.org/docs/Web/CSS/CSS_logical_properties_and_values
- WCAG 1.4.8 (text presentation): https://www.w3.org/WAI/WCAG22/quickref/#visual-presentation

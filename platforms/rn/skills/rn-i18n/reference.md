# rn-i18n — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per
failure mode. TypeScript + React Native, using i18next/react-i18next and
react-intl. Decision criteria and the full guard checklist live in `SKILL.md`.

## Stack assumed

- Translation: `i18next` + `react-i18next` (primary examples) or `react-intl`
  (FormatJS) — both shown where they differ.
- RTL: `I18nManager` from `react-native`.
- Formatting: `Intl.DateTimeFormat` / `Intl.NumberFormat` (available on Hermes
  via the built-in Intl; add `@formatjs/intl-*` polyfills for older JSC targets).
- Catalogs: keyed JSON at `locales/en.json`, `locales/ar.json`, etc.

---

## 1. Hardcoded user-facing string

```tsx
// ❌ Literal English text in JSX and props — untranslatable
<Text>Submit</Text>
<TextInput placeholder="Search…" />
<Pressable accessibilityLabel="Close" onPress={onClose}>
  <Icon name="x" />
</Pressable>

// ✅ All visible text goes through the translation function
import { useTranslation } from 'react-i18next';

function SubmitButton() {
  const { t } = useTranslation();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={t('common.close')}
      onPress={onClose}
    >
      <Icon name="x" />
    </Pressable>
  );
}

<Text>{t('actions.submit')}</Text>
<TextInput placeholder={t('search.placeholder')} />
```

`locales/en.json`:
```json
{
  "actions": { "submit": "Submit" },
  "search": { "placeholder": "Search…" },
  "common": { "close": "Close" }
}
```

---

## 2. Sentence concatenation

```ts
// ❌ Concatenated fragments — word order breaks in non-English languages
const msg = t('cart.you_have') + ' ' + count + ' ' + t('cart.items_in_cart');
// Arabic / German re-orders subject, verb, object differently → garbled output

// ✅ One atomic key with a named placeholder; the translator owns the full sentence
// locales/en.json: { "cart": { "summary": "You have {{count}} items in your cart" } }
const msg = t('cart.summary', { count });
```

react-intl equivalent:
```tsx
// ✅
<FormattedMessage id="cart.summary" values={{ count }} />
// messages/en.json: { "cart.summary": "You have {count} items in your cart" }
```

---

## 3. Manual pluralization

```ts
// ❌ Hand-rolled plural — wrong for Polish, Arabic, Russian, etc.
const label = count === 1 ? t('items.one') : t('items.other');
const label2 = t('item') + (count !== 1 ? 's' : '');

// ✅ i18next ICU plurals — library applies CLDR rules per language
// locales/en.json:
// { "items": { "count_one": "{{count}} item", "count_other": "{{count}} items" } }
// locales/ar.json: six plural forms handled automatically
const label = t('items.count', { count });
```

react-intl:
```tsx
// ✅ ICU message syntax — CLDR plural categories built in
// { "items.count": "{count, plural, one {# item} other {# items}}" }
<FormattedMessage id="items.count" values={{ count }} />
```

---

## 4. Hardcoded date/time format

```ts
// ❌ Manual date pattern — US-centric, ignores locale
const dateStr = `${date.getMonth() + 1}/${date.getDate()}/${date.getFullYear()}`;
// or: format(date, 'MM/dd/yyyy')   ← date-fns with a hardcoded pattern

// ✅ Intl.DateTimeFormat resolves the user's locale automatically
import { getLocales } from 'react-native-localize'; // or RN's NativeModules

const locale = getLocales()[0].languageTag; // e.g. 'ar-SA', 'de-DE'
const dateStr = new Intl.DateTimeFormat(locale, {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
}).format(date);
// → "August 26, 2026" (en-US) / "٢٦ أغسطس ٢٠٢٦" (ar-SA)
```

react-intl:
```tsx
// ✅ FormattedDate picks up the IntlProvider locale automatically
<FormattedDate value={date} year="numeric" month="long" day="numeric" />
```

---

## 5. Hardcoded number/currency

```ts
// ❌ Literal symbol + fixed decimals — wrong grouping and symbol for most locales
const price = `$${(amount / 100).toFixed(2)}`;   // "$1,234.56" only for en-US
const pct   = `${(ratio * 100).toFixed(1)}%`;

// ✅ Intl.NumberFormat — correct symbol, grouping, and decimal per locale
const locale = getLocales()[0].languageTag;

const price = new Intl.NumberFormat(locale, {
  style: 'currency',
  currency: currencyCode, // e.g. 'USD', 'EUR', 'JPY' — from your backend/config
}).format(amount / 100);

const pct = new Intl.NumberFormat(locale, {
  style: 'percent',
  maximumFractionDigits: 1,
}).format(ratio);
```

react-intl:
```tsx
// ✅
<FormattedNumber value={amount / 100} style="currency" currency={currencyCode} />
```

---

## 6. Non-RTL-safe layout

```tsx
// ❌ Hardcoded left/right — layout breaks for Arabic, Hebrew, Persian, Urdu
<View style={{ marginLeft: 8, paddingRight: 16 }}>
  <Icon name="arrow-right" />
  <Text style={{ left: 0 }}>{label}</Text>
</View>

// ✅ Logical margin/padding + I18nManager.isRTL for directional icons
import { I18nManager } from 'react-native';

<View style={{ marginStart: 8, paddingEnd: 16 }}>
  {/* Arrow mirrors for RTL: → becomes ← */}
  <Icon name={I18nManager.isRTL ? 'arrow-left' : 'arrow-right'} />
  <Text>{label}</Text>
</View>
```

RTL layout notes:
- `marginStart` / `marginEnd` map to left/right automatically per layout direction.
- `paddingStart` / `paddingEnd` same.
- `flexDirection: 'row'` already flips item order in RTL — no manual reversal needed.
- `alignSelf: 'flex-start'` / `'flex-end'` are direction-agnostic.
- Absolute-positioned overlays that must anchor to the "near" edge: use
  `I18nManager.isRTL ? { right: 0 } : { left: 0 }`.

---

## 7. Missing placeholders

```ts
// ❌ Fragment concatenation — translators cannot reorder
// locales/en.json: { "sent": "sent", "a_message": "a message" }
const notice = name + ' ' + t('sent') + ' ' + t('a_message');
// In Japanese: "a message was sent by name" — order is inverted, concatenation fails

// ✅ One key with all dynamic values as named placeholders
// locales/en.json: { "notifications.sent_message": "{{sender}} sent you a message" }
// locales/ja.json: { "notifications.sent_message": "{{sender}}からメッセージが届きました" }
const notice = t('notifications.sent_message', { sender: name });
```

Multiple placeholders:
```ts
// locales/en.json:
// { "order.shipped": "Your order #{{orderId}} ships on {{date}}" }
const msg = t('order.shipped', { orderId, date: formattedDate });
```

---

## 8. Hardcoded locale

```ts
// ❌ Forces US English regardless of device settings
const fmt = new Intl.DateTimeFormat('en-US', { dateStyle: 'short' });
i18next.init({ lng: 'en', resources });  // hardcoded, ignores device

// ✅ Resolve locale from device at runtime
import { getLocales } from 'react-native-localize';

const [{ languageTag }] = getLocales(); // 'ar-SA', 'zh-Hans-CN', etc.
const fmt = new Intl.DateTimeFormat(languageTag, { dateStyle: 'short' });

// i18next: detect from device + fall back gracefully
import { initReactI18next } from 'react-i18next';
import * as RNLocalize from 'react-native-localize';

const languageDetector = {
  type: 'languageDetector' as const,
  async: true,
  detect: (cb: (lng: string) => void) => cb(RNLocalize.getLocales()[0].languageTag),
  init: () => {},
  cacheUserLanguage: () => {},
};

i18next
  .use(languageDetector)
  .use(initReactI18next)
  .init({ fallbackLng: 'en', resources });
```

---

## 9. Missing translations / no fallback

```ts
// ❌ New key added in code but missing from non-English catalogs; no fallback
i18next.init({ lng: 'en', resources });   // no fallbackLng
// t('profile.bio_placeholder') → "profile.bio_placeholder" shown to Arabic users

// ✅ fallbackLng ensures unknown keys degrade gracefully, not blank/key-leaked
i18next.init({
  fallbackLng: 'en',      // always have an English entry as safety net
  resources,
  interpolation: { escapeValue: false },
});

// Catalog discipline: add every new key to ALL locale files at the same time.
// locales/en.json:  { "profile": { "bio_placeholder": "Tell us about yourself" } }
// locales/ar.json:  { "profile": { "bio_placeholder": "أخبرنا عن نفسك" } }
// locales/de.json:  { "profile": { "bio_placeholder": "Erzähl uns von dir" } }
```

react-intl:
```tsx
// ✅ defaultLocale provides the fallback message source
<IntlProvider locale={userLocale} defaultLocale="en" messages={messages[userLocale]}>
  <App />
</IntlProvider>
```

---

## 10. Text baked into images

```tsx
// ❌ Button/banner image with text drawn in — untranslatable, unscalable, invisible
//    to screen readers
<Image source={require('./assets/submit_button_en.png')} />
<Image source={require('./assets/sale_banner.png')} />  // "SALE 50% OFF" in the PNG

// ✅ Use RN Text elements for all readable content; images are purely decorative
function SubmitButton() {
  const { t } = useTranslation();
  return (
    <Pressable
      style={styles.button}
      accessibilityRole="button"
      accessibilityLabel={t('actions.submit')}
      onPress={onSubmit}
    >
      <Text style={styles.label}>{t('actions.submit')}</Text>
    </Pressable>
  );
}

// Banner: overlay translatable Text over the decorative image
<View>
  <Image
    source={require('./assets/sale_background.png')}
    accessibilityElementsHidden   // decorative — screen reader skips it
    importantForAccessibility="no"
  />
  <Text style={styles.bannerText}>{t('promo.sale_label', { pct: 50 })}</Text>
</View>
```

- Culture-specific images (gestures, symbols): provide a locale-aware alternative
  or omit the culture-specific element; check `I18nManager.isRTL` for directional
  illustrations.

---

## Do examples — keyed catalog with ICU plural + named placeholder

`locales/en.json`:
```json
{
  "inbox": {
    "unread": "{{count}} unread message",
    "unread_other": "{{count}} unread messages",
    "from": "From: {{sender}}",
    "received": "{{sender}} sent you {{count}} file",
    "received_other": "{{sender}} sent you {{count}} files"
  }
}
```

```ts
// Single plural key — library picks _one vs _other per CLDR
t('inbox.unread', { count: 1 });   // "1 unread message"
t('inbox.unread', { count: 5 });   // "5 unread messages"

// Named placeholder — translator owns word order
t('inbox.from', { sender: 'Alice' });   // "From: Alice"

// Combined: plural + named placeholder
t('inbox.received', { sender: 'Bob', count: 3 });  // "Bob sent you 3 files"
```

## Do examples — locale-aware date and currency

```ts
import { getLocales } from 'react-native-localize';

const locale = getLocales()[0].languageTag;

// Date
const date = new Date('2026-08-26');
new Intl.DateTimeFormat(locale, { dateStyle: 'long' }).format(date);
// 'en-US' → "August 26, 2026"
// 'de-DE' → "26. August 2026"
// 'ja-JP' → "2026年8月26日"

// Currency
new Intl.NumberFormat(locale, { style: 'currency', currency: 'EUR' }).format(12.5);
// 'en-US' → "€12.50"
// 'de-DE' → "12,50 €"
// 'ar-SA' → "١٢٫٥٠ €"
```

## Do example — RTL-safe layout

```tsx
import { I18nManager, StyleSheet, View, Text } from 'react-native';

function ListItem({ label, onPress }: { label: string; onPress: () => void }) {
  const { t } = useTranslation();
  return (
    <Pressable
      style={styles.row}
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={label}
    >
      <Text style={styles.label}>{label}</Text>
      {/* Chevron mirrors for RTL automatically */}
      <Icon name={I18nManager.isRTL ? 'chevron-left' : 'chevron-right'} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',   // ← flex row already flips order in RTL
    alignItems: 'center',
    paddingStart: 16,       // ← logical, not paddingLeft
    paddingEnd: 12,
    marginBottom: 8,
  },
  label: {
    flex: 1,
    // No textAlign: 'left' — let the system resolve per locale
  },
});
```

---

## Official references

- React Native I18nManager (RTL): https://reactnative.dev/docs/i18nmanager
- i18next / react-i18next: https://www.i18next.com/
- react-intl (FormatJS): https://formatjs.io/docs/react-intl/
- Intl support on Hermes: https://hermesengine.dev/docs/intl/
- react-native-localize (device locale): https://github.com/zoontek/react-native-localize
- Unicode CLDR plural rules: https://cldr.unicode.org/index/cldr-spec/plural-rules
- Team baseline: [../../guidance.md](../../guidance.md)

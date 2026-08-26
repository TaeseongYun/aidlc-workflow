# frontend-i18n — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code pairs per
failure mode. TypeScript + React (react-i18next / next-intl / FormatJS ICU).
Decision criteria live in `SKILL.md`.

---

## 1. Hardcoded user-facing string

```tsx
// ❌ English literal baked into JSX — untranslatable
export function SaveButton() {
  return <button type="button">Save changes</button>;
}

// ❌ Toast message hardcoded
toast.success("Profile saved successfully");
```

```tsx
// ✅ react-i18next
import { useTranslation } from 'react-i18next';

export function SaveButton() {
  const { t } = useTranslation('common');
  return <button type="button">{t('saveChanges')}</button>;
}

toast.success(t('profile.savedSuccessfully'));
```

```tsx
// ✅ next-intl
import { useTranslations } from 'next-intl';

export function SaveButton() {
  const t = useTranslations('Common');
  return <button type="button">{t('saveChanges')}</button>;
}
```

Catalog entry (`locales/en/common.json`):

```json
{
  "saveChanges": "Save changes",
  "profile": {
    "savedSuccessfully": "Profile saved successfully"
  }
}
```

---

## 2. Sentence concatenation

```tsx
// ❌ Fragments concatenated — word order breaks in Japanese, Arabic, German
const msg = t('youHave') + ' ' + count + ' ' + t('newMessages');
// ❌ Template literal splice
const label = `${t('hello')}, ${name}!`;
```

```tsx
// ✅ Single key with named placeholder — translator controls full sentence
// Message: "You have {count} new {count, plural, one {message} other {messages}}"
const msg = t('inbox.summary', { count });

// ✅ Greeting with placeholder
// Message: "Hello, {name}!"
const label = t('greeting', { name });
```

Catalog (`locales/en/common.json`):

```json
{
  "inbox": {
    "summary": "You have {{count}} new {{count, plural, one {message} other {messages}}}"
  },
  "greeting": "Hello, {{name}}!"
}
```

---

## 3. Manual pluralization

```tsx
// ❌ Hand-rolled plural — wrong for any language with non-binary plural forms
const label = `${count} item${count === 1 ? '' : 's'}`;

// ❌ Ternary in JSX
<p>{count === 1 ? 'One result' : `${count} results`}</p>
```

```tsx
// ✅ react-i18next with ICU — works for Arabic (6 forms), Russian (3), etc.
// Message (ICU): "{count, plural, one {# item} other {# items}}"
const label = t('cart.itemCount', { count });

// ✅ next-intl (uses ICU natively)
const t = useTranslations('Cart');
<p>{t('itemCount', { count })}</p>
```

Catalog (`locales/en/common.json`, react-i18next):

```json
{
  "cart": {
    "itemCount": "{{count}} item",
    "itemCount_other": "{{count}} items"
  }
}
```

FormatJS / next-intl ICU (`messages/en.json`):

```json
{
  "Cart": {
    "itemCount": "{count, plural, one {# item} other {# items}}"
  }
}
```

---

## 4. Hardcoded date/time format

```tsx
// ❌ Hardcoded pattern — wrong order, separators, and calendar for most locales
import { format } from 'date-fns';
const display = format(date, 'MM/dd/yyyy');       // US-only

// ❌ dayjs with literal format, no locale
const display = dayjs(date).format('D MMM YYYY');
```

```tsx
// ✅ Intl.DateTimeFormat — locale-aware, no pattern string needed
function formatDate(date: Date, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date);
}

// In a Next.js app router component:
import { useLocale } from 'next-intl';

export function PostDate({ date }: { date: Date }) {
  const locale = useLocale();
  return <time dateTime={date.toISOString()}>{formatDate(date, locale)}</time>;
}
```

```tsx
// ✅ next-intl useFormatter (wraps Intl internally)
import { useFormatter } from 'next-intl';

export function PostDate({ date }: { date: Date }) {
  const format = useFormatter();
  return (
    <time dateTime={date.toISOString()}>
      {format.dateTime(date, { year: 'numeric', month: 'long', day: 'numeric' })}
    </time>
  );
}
```

---

## 5. Hardcoded number/currency

```tsx
// ❌ Dollar symbol hardcoded — wrong symbol, wrong decimal/grouping for other locales
const price = `$${amount.toFixed(2)}`;

// ❌ toLocaleString with no locale or currency — uses browser default, inconsistent
const display = amount.toLocaleString();
```

```tsx
// ✅ Intl.NumberFormat with locale + currency
function formatCurrency(amount: number, locale: string, currency: string): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  }).format(amount);
}

// Usage: formatCurrency(9.99, 'de-DE', 'EUR') → "9,99 €"
//        formatCurrency(9.99, 'en-US', 'USD') → "$9.99"
//        formatCurrency(9.99, 'ja-JP', 'JPY') → ¥10

// ✅ next-intl useFormatter
import { useFormatter, useLocale } from 'next-intl';

export function Price({ amount, currency }: { amount: number; currency: string }) {
  const format = useFormatter();
  return <span>{format.number(amount, { style: 'currency', currency })}</span>;
}
```

---

## 6. Non-RTL-safe layout

```tsx
// ❌ Physical left/right — mirror-breaks in Arabic, Hebrew, Persian
<div style={{ marginLeft: 16, paddingLeft: 12, textAlign: 'left' }}>
  <span style={{ left: 0 }}>{label}</span>
</div>

// ❌ Tailwind physical utilities
<div className="ml-4 pl-3 text-left">...</div>
```

```tsx
// ✅ Logical CSS properties — automatically mirror in RTL
<div style={{ marginInlineStart: 16, paddingInlineStart: 12, textAlign: 'start' }}>
  {label}
</div>

// ✅ Tailwind logical utilities (Tailwind v3.3+)
<div className="ms-4 ps-3 text-start">...</div>
```

Set `dir` on `<html>` from the active locale (Next.js app router):

```tsx
// app/[locale]/layout.tsx
import { getLocale } from 'next-intl/server';

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  const dir = ['ar', 'he', 'fa', 'ur'].includes(locale) ? 'rtl' : 'ltr';
  return (
    <html lang={locale} dir={dir}>
      <body>{children}</body>
    </html>
  );
}
```

Mirror directional icons in CSS:

```css
/* ponytail: scaleX(-1) is the standard RTL icon-mirror idiom */
[dir="rtl"] .icon-directional {
  transform: scaleX(-1);
}
```

---

## 7. Missing placeholders

```tsx
// ❌ Value appended outside the message — translator cannot reorder
const notice = t('sentBy') + ' ' + senderName;

// ❌ Template literal after t() — same problem
const notice = `${t('newComment')} ${postTitle}`;
```

```tsx
// ✅ Named placeholder inside the message — full sentence in catalog
// Message: "{sender} left a comment on "{title}""
const notice = t('notifications.newComment', { sender: senderName, title: postTitle });
```

```json
{
  "notifications": {
    "newComment": "{{sender}} left a comment on \"{{title}}\""
  }
}
```

Translators can now reorder freely — e.g., German: `"Auf \"{{title}}\" hat {{sender}} kommentiert"`.

---

## 8. Hardcoded locale

```tsx
// ❌ Locale hardcoded in formatter — ignores user preference
const formatted = new Intl.DateTimeFormat('en-US').format(date);

// ❌ i18n init that forces English regardless of detection
i18n.init({ lng: 'en', ... });

// ❌ dayjs locale hardcoded
import 'dayjs/locale/en';
dayjs.locale('en');
```

```tsx
// ✅ Derive locale from user/system context
// react-i18next: use i18n.language (set by detection plugin)
import i18n from './i18n'; // configured with LanguageDetector
const formatted = new Intl.DateTimeFormat(i18n.language, { dateStyle: 'long' }).format(date);

// ✅ Next.js app router: locale from routing
// app/[locale]/page.tsx
import { useLocale } from 'next-intl';

export default function Page() {
  const locale = useLocale();
  const formatted = new Intl.DateTimeFormat(locale, { dateStyle: 'long' }).format(new Date());
  return <p>{formatted}</p>;
}
```

react-i18next init with detection (no hardcoded `lng`):

```ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

i18n
  .use(LanguageDetector)       // reads browser/cookie/querystring
  .use(initReactI18next)
  .init({
    fallbackLng: 'en',         // safe fallback — no hardcoded primary
    resources: { ... },
  });
```

---

## 9. Missing translations / no fallback

```tsx
// ❌ Key added to en.json only — fr.json has no entry → shows raw key "dashboard.newWidget.title"
// en.json:  { "dashboard": { "newWidget": { "title": "Quick actions" } } }
// fr.json:  { "dashboard": { } }   ← missing entry

// ❌ i18n initialized with no fallbackLng — missing key renders blank
i18n.init({ resources: { ... } });   // no fallbackLng
```

```tsx
// ✅ Add key to every active locale catalog on the same PR
// en.json: { "dashboard": { "newWidget": { "title": "Quick actions" } } }
// fr.json: { "dashboard": { "newWidget": { "title": "Actions rapides" } } }
// ja.json: { "dashboard": { "newWidget": { "title": "クイックアクション" } } }

// ✅ Configure fallbackLng so an untranslated key shows English, not a raw key
i18n.init({
  fallbackLng: 'en',
  resources: { ... },
});
```

next-intl equivalent (`next-intl.config.ts`):

```ts
export default {
  defaultLocale: 'en',   // fallback locale
  locales: ['en', 'fr', 'ja', 'ar'],
};
```

---

## 10. Text baked into images

```tsx
// ❌ Banner image with English text rasterized in — cannot be translated
<img src="/banners/welcome-en.png" alt="Welcome to Acme" />

// ❌ SVG with hardcoded text node
<svg viewBox="0 0 200 40">
  <text x="10" y="30" fontSize="20">Total Sales</text>
</svg>
```

```tsx
// ✅ Overlay translatable text on a text-free image
const { t } = useTranslation('home');
<div className="relative">
  <img src="/banners/welcome-bg.png" alt="" aria-hidden="true" />
  <p className="absolute inset-0 flex items-center justify-center text-2xl font-bold">
    {t('hero.welcomeHeadline')}
  </p>
</div>

// ✅ SVG chart label via React — translatable, selectable, searchable
<svg viewBox="0 0 200 40">
  <text x="10" y="30" fontSize="20">{t('chart.totalSales')}</text>
  {/* ponytail: for complex charts consider foreignObject + HTML text instead */}
</svg>

// ✅ Or replace with a <span> positioned over the SVG and remove the <text> node
```

---

## Do examples — positive patterns

### ICU plural + named placeholder in one message (react-i18next)

```json
// locales/en/inbox.json
{
  "summary": "{{name}} sent you {{count}} message",
  "summary_other": "{{name}} sent you {{count}} messages"
}
```

```tsx
// Component
const { t } = useTranslation('inbox');
<p>{t('summary', { name: sender.displayName, count: messageCount })}</p>
// en: "Alice sent you 1 message" / "Alice sent you 3 messages"
// de (catalog): "{{name}} hat Ihnen {{count}} Nachricht(en) geschickt" — name reordered freely
```

### Locale-aware date + currency (Intl, no external lib)

```tsx
function formatRelease(date: Date, price: number, locale: string, currency: string) {
  const dateStr = new Intl.DateTimeFormat(locale, {
    year: 'numeric', month: 'short', day: 'numeric',
  }).format(date);

  const priceStr = new Intl.NumberFormat(locale, {
    style: 'currency', currency, minimumFractionDigits: 2,
  }).format(price);

  return { dateStr, priceStr };
}
// ('ja-JP', 'JPY') → { dateStr: '2026年1月15日', priceStr: '¥1,980' }
// ('de-DE', 'EUR') → { dateStr: '15. Jan. 2026',  priceStr: '19,80 €' }
```

### RTL-safe card layout (logical CSS)

```tsx
// ✅ Card renders correctly in LTR and RTL without any RTL override rules
export function UserCard({ avatar, name, badge }: UserCardProps) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <img src={avatar} alt="" aria-hidden="true" style={{ borderRadius: '50%' }} />
      <div style={{ flex: 1, marginInlineStart: 4 }}>
        <p style={{ textAlign: 'start', fontWeight: 600 }}>{name}</p>
        <span style={{ paddingInline: 6, borderInlineStart: '2px solid currentColor' }}>
          {badge}
        </span>
      </div>
    </div>
  );
}
```

---

## Official references

- react-i18next: https://react.i18next.com/
- next-intl: https://next-intl-docs.vercel.app/
- FormatJS ICU syntax: https://formatjs.io/docs/core-concepts/icu-syntax/
- MDN Intl.DateTimeFormat: https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
- MDN Intl.NumberFormat: https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
- MDN CSS logical properties: https://developer.mozilla.org/docs/Web/CSS/CSS_logical_properties_and_values
- Team baseline: [../../guidance.md](../../guidance.md)
- SKILL.md (decision criteria): [SKILL.md](./SKILL.md)

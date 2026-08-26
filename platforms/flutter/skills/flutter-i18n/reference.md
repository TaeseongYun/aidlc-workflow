# flutter-i18n — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Dart code samples per
failure mode. Decision criteria and the full checklist live in `SKILL.md`.

## Setup baseline — ARB + gen_l10n

Every project using this skill should have:

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

flutter:
  generate: true   # enables gen_l10n
```

```yaml
# l10n.yaml (project root)
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

```json
// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "submitButton": "Submit",
  "@submitButton": { "description": "Primary action button label" },
  "greeting": "Hello, {name}!",
  "@greeting": {
    "description": "Greeting with user name",
    "placeholders": { "name": { "type": "String" } }
  },
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "description": "Item count with ICU plural",
    "placeholders": { "count": { "type": "int" } }
  }
}
```

```dart
// MaterialApp wiring
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ponytail: localeResolutionCallback falls back to 'en' when the system
  // locale is unsupported — prevents blank-string regressions.
  localeResolutionCallback: (locale, supported) =>
      supported.contains(locale) ? locale : const Locale('en'),
  home: const HomeScreen(),
);
```

---

## 1. Hardcoded user-facing string

```dart
// ❌ Literal string rendered directly — untranslatable
Text("Submit")
TextField(decoration: InputDecoration(hintText: "Enter your email"))
IconButton(icon: Icon(Icons.close), tooltip: "Close")
```

```dart
// ✅ Every user-visible string comes from AppLocalizations
final l10n = AppLocalizations.of(context)!;
Text(l10n.submitButton)
TextField(decoration: InputDecoration(hintText: l10n.emailHint))
IconButton(icon: Icon(Icons.close), tooltip: l10n.closeDialog)
```

> A11y note: `semanticsLabel` and `Semantics(label: ...)` are user-facing — they also
> require ARB keys. See [flutter-accessibility](../flutter-accessibility/SKILL.md).

---

## 2. Sentence concatenation

```dart
// ❌ Concatenation — word order breaks in Arabic, Japanese, German, etc.
final l10n = AppLocalizations.of(context)!;
Text(l10n.youHave + " ${cart.count} " + l10n.items)
Text("${l10n.hello} ${user.name}")   // looks fine in English; wrong in many others
```

```dart
// ✅ One ARB key with named placeholders — translators reorder freely
// ARB: "cartSummary": "You have {count} {itemLabel} in your cart."
// ARB: "greeting": "Hello, {name}!"
Text(l10n.cartSummary(count: cart.count, itemLabel: l10n.itemLabel))
Text(l10n.greeting(name: user.name))
```

---

## 3. Manual pluralization

```dart
// ❌ Hand-rolled plural — wrong for languages with 3+ plural categories (Arabic, Russian…)
Text("$count ${count == 1 ? 'message' : 'messages'}")
Text("$count item${ count != 1 ? 's' : '' }")
```

```dart
// ✅ ICU plural in ARB — gen_l10n generates the correct per-locale plural selector
// ARB: "messageCount": "{count, plural, =0{No messages} =1{One message} other{{count} messages}}"
Text(l10n.messageCount(count: count))

// More complex: =2, few, many categories for Slavic languages — same pattern, ARB handles it
// ARB: "dayCount": "{count, plural, =1{1 day} few{{count} days} other{{count} days}}"
Text(l10n.dayCount(count: days))
```

---

## 4. Hardcoded date/time format

```dart
// ❌ Fixed pattern — US date order, wrong for most of the world
Text(DateFormat("MM/dd/yyyy").format(order.createdAt))          // no locale
Text("${date.month}/${date.day}/${date.year}")                   // hand-built
Text(DateFormat("HH:mm", "en_US").format(event.startTime))     // hardcoded locale
```

```dart
// ✅ Named constructor picks the locale-correct pattern automatically
final locale = Localizations.localeOf(context).toString();
Text(DateFormat.yMMMd(locale).format(order.createdAt))   // e.g. "Aug 15, 2025" / "15 août 2025"
Text(DateFormat.jm(locale).format(event.startTime))       // e.g. "2:30 PM" / "14:30"

// When you need a specific skeleton, still pass the locale:
Text(DateFormat("yMMMMEEEEd", locale).format(meeting.date))
```

---

## 5. Hardcoded number/currency

```dart
// ❌ Dollar sign hardcoded; toStringAsFixed ignores locale separators
Text("\$${price.toStringAsFixed(2)}")
Text("Total: \$${total}")
Text("${amount.toStringAsFixed(0)} users")   // 1000 vs 1.000 vs 1,000 per locale
```

```dart
// ✅ NumberFormat from intl — locale-aware separators, symbol, position
final locale = Localizations.localeOf(context).toString();

// Currency
Text(NumberFormat.currency(locale: locale, symbol: 'USD').format(price))
// Or with the locale's own currency symbol:
Text(NumberFormat.simpleCurrency(locale: locale).format(price))

// Plain number with grouping
Text(NumberFormat.decimalPattern(locale).format(amount))

// Compact notation
Text(NumberFormat.compact(locale: locale).format(followers))   // "1.2M" / "1,2 Mio."
```

---

## 6. Non-RTL-safe layout

```dart
// ❌ Hard-wired to LTR — breaks Arabic, Hebrew, Farsi
Padding(padding: EdgeInsets.only(left: 16, right: 8), child: label)
Align(alignment: Alignment.centerLeft, child: content)
Text(data, textAlign: TextAlign.left)
Row(children: [Icon(Icons.arrow_forward), text])   // arrow points wrong in RTL
```

```dart
// ✅ Directional APIs mirror automatically in RTL locales
Padding(
  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
  child: label,
)
Align(alignment: AlignmentDirectional.centerStart, child: content)
Text(data, textAlign: TextAlign.start)

// For an arrow that should flip in RTL, use Directionality-aware icon:
Icon(Icons.arrow_forward)  // flips automatically inside a Directionality widget

// Wrap a subtree that loads its locale asynchronously:
Directionality(
  textDirection: ui.TextDirection.rtl,
  child: arabicSubtree,
)
```

---

## 7. Missing placeholders

```dart
// ❌ Dynamic value concatenated AFTER the key — translators cannot see or reorder it
// ARB has: "greeting": "Hello!"
// Dart appends the name invisibly:
Text("${l10n.greeting} ${user.name}")   // "Hello! Alice" — but Arabic needs "Alice! مرحبا"
```

```dart
// ✅ Placeholder declared in ARB so translators can reorder
// ARB: "greeting": "Hello, {name}!",
//      "@greeting": { "placeholders": { "name": { "type": "String" } } }
Text(l10n.greeting(name: user.name))

// Multiple placeholders — translator in German can write "{actor} hat {count} Nachrichten"
// ARB: "actorMessage": "{actor} sent {count} messages",
//      "@actorMessage": { "placeholders": { "actor": {…}, "count": {…} } }
Text(l10n.actorMessage(actor: sender.name, count: messages.length))
```

---

## 8. Hardcoded locale

```dart
// ❌ Always US English, regardless of user's device locale
DateFormat("yMMMd", "en_US").format(date)
NumberFormat.currency(locale: "en_US", symbol: "\$").format(amount)
// Or in MaterialApp — prevents Flutter from using the device locale:
MaterialApp(locale: const Locale("en"), ...)
```

```dart
// ✅ Resolve locale from context at point of use
final locale = Localizations.localeOf(context).toString();
DateFormat.yMMMd(locale).format(date)
NumberFormat.simpleCurrency(locale: locale).format(amount)

// In MaterialApp — let Flutter resolve from supportedLocales; add a fallback only:
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeResolutionCallback: (locale, supported) =>
      supported.contains(locale) ? locale : const Locale('en'),
)
```

---

## 9. Missing translations / no fallback

```json
// ❌ lib/l10n/app_en.arb has "checkoutButton" — app_ar.arb does not
// Runtime: blank string or MissingLocalizationException in Arabic builds
{ "@@locale": "en", "checkoutButton": "Checkout" }
// app_ar.arb is missing "checkoutButton" entirely
```

```json
// ✅ Key present in every locale file
// lib/l10n/app_en.arb
{ "@@locale": "en", "checkoutButton": "Checkout" }
// lib/l10n/app_ar.arb
{ "@@locale": "ar", "checkoutButton": "الدفع" }
```

```dart
// ✅ MaterialApp declares supportedLocales and a resolution callback as a safety net
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: const [Locale('en'), Locale('ar'), Locale('es')],
  localeResolutionCallback: (locale, supported) =>
      supported.firstWhere(
        (s) => s.languageCode == locale?.languageCode,
        orElse: () => const Locale('en'),
      ),
)
```

> CI guard: add `flutter gen-l10n` to your CI pipeline and fail the build on
> missing keys — prevents this class of bug from reaching production.

---

## 10. Text baked into images

```dart
// ❌ PNG asset has "Welcome!" burned in — untranslatable, invisible to VoiceOver/TalkBack
Image.asset('assets/images/welcome_banner_en.png')

// ❌ CustomPainter draws user-readable text directly — no i18n, no a11y
class ChartLabel extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(text: TextSpan(text: "Revenue"), ...);
    tp.layout(); tp.paint(canvas, Offset.zero);
  }
}
```

```dart
// ✅ Flutter Text widget overlaid on the image — translatable + accessible
Stack(
  alignment: AlignmentDirectional.bottomStart,
  children: [
    Image.asset('assets/images/welcome_banner.png', excludeFromSemantics: true),
    Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Text(l10n.welcomeBanner, style: theme.textTheme.headlineMedium),
    ),
  ],
)

// ✅ CustomPainter with a parallel Text widget for a11y + i18n
Semantics(
  label: l10n.revenueChartLabel,
  child: CustomPaint(painter: ChartLabelPainter()),
)
```

---

## Do examples (positive patterns)

### Full ARB entry with ICU plural and named placeholder

```json
// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "unreadNotifications": "{count, plural, =0{No unread notifications} =1{1 unread notification} other{{count} unread notifications}}",
  "@unreadNotifications": {
    "description": "Notification badge label",
    "placeholders": {
      "count": { "type": "int", "format": "decimalPattern" }
    }
  },
  "lastSyncedAt": "Last synced {date}",
  "@lastSyncedAt": {
    "description": "Timestamp shown in the footer",
    "placeholders": {
      "date": { "type": "DateTime", "format": "yMMMd" }
    }
  }
}
```

```dart
// Usage in widget
final l10n = AppLocalizations.of(context)!;
Text(l10n.unreadNotifications(count: badge.count))
Text(l10n.lastSyncedAt(date: syncState.lastSynced))
```

### Locale-aware currency + date in a receipt row

```dart
Widget _buildReceiptRow(BuildContext context, Order order) {
  final locale = Localizations.localeOf(context).toString();
  final price = NumberFormat.simpleCurrency(locale: locale).format(order.total);
  final date  = DateFormat.yMMMd(locale).format(order.placedAt);
  return ListTile(
    title: Text(AppLocalizations.of(context)!.orderSummary(date: date)),
    trailing: Text(price),
  );
}
```

### RTL-safe card layout

```dart
Card(
  child: Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l10n.productName,
            textAlign: TextAlign.start,   // start, not left
          ),
        ),
        // Icon that should flip in RTL (back arrow, chevron, etc.)
        const Icon(Icons.chevron_right),  // Flutter flips automatically in RTL
      ],
    ),
  ),
)
```

---

## Official references

- Flutter i18n guide: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- `intl` package: https://pub.dev/packages/intl
- `gen_l10n` tool: https://api.flutter.dev/flutter/flutter_localizations/
- ARB file format: https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification
- ICU message format / plural rules: https://unicode-org.github.io/icu/userguide/format_parse/messages/
- CLDR plural rules (per language): https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
- `Directionality` widget: https://api.flutter.dev/flutter/widgets/Directionality-class.html
- `EdgeInsetsDirectional`: https://api.flutter.dev/flutter/painting/EdgeInsetsDirectional-class.html
- Team baseline: [../../guidance.md](../../guidance.md)
- SKILL.md (guard rules + checklist): [SKILL.md](./SKILL.md)

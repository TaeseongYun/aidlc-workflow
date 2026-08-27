# kmp-i18n — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** Kotlin code samples per
failure mode. Decision criteria and the full checklist live in `SKILL.md`.

## Setup baseline — Compose Resources + expect/actual formatters

Every KMP project using this skill should have one of these two i18n approaches:

### Option A — Compose Resources (JetBrains multiplatform)

```kotlin
// build.gradle.kts (shared module)
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(compose.components.resources)
        }
    }
}
```

```xml
<!-- shared/src/commonMain/composeResources/values/strings.xml -->
<resources>
    <string name="submit_button">Submit</string>
    <string name="greeting">Hello, %1$s!</string>
    <plurals name="item_count">
        <item quantity="zero">No items</item>
        <item quantity="one">One item</item>
        <item quantity="other">%1$d items</item>
    </plurals>
</resources>
```

```kotlin
// Usage in composable (commonMain)
Text(stringResource(Res.string.submit_button))
Text(stringResource(Res.string.greeting, user.name))
Text(pluralStringResource(Res.plurals.item_count, count, count))
```

### Option B — moko-resources

```kotlin
// build.gradle.kts
commonMain.dependencies {
    api("dev.icerock.moko:resources-compose:0.24.0")
}
```

```kotlin
// MR.strings.submit_button → defined in MR object via annotation processor
Text(stringResource(MR.strings.submit_button))
Text(MR.strings.greeting.format(user.name)) // ICU placeholder
```

### expect/actual date + number formatters

```kotlin
// commonMain — the contract
expect fun formatDate(epochMillis: Long, locale: AppLocale): String
expect fun formatCurrency(amount: Double, currencyCode: String, locale: AppLocale): String

// androidMain — implementation
actual fun formatDate(epochMillis: Long, locale: AppLocale): String {
    val javaLocale = java.util.Locale(locale.language, locale.region)
    return java.text.SimpleDateFormat.getDateInstance(
        java.text.DateFormat.MEDIUM, javaLocale
    ).format(java.util.Date(epochMillis))
}

actual fun formatCurrency(amount: Double, currencyCode: String, locale: AppLocale): String {
    val javaLocale = java.util.Locale(locale.language, locale.region)
    return java.text.NumberFormat.getCurrencyInstance(javaLocale).apply {
        currency = java.util.Currency.getInstance(currencyCode)
    }.format(amount)
}

// iosMain — implementation
actual fun formatDate(epochMillis: Long, locale: AppLocale): String {
    val formatter = platform.Foundation.NSDateFormatter()
    formatter.dateStyle = platform.Foundation.NSDateFormatterMediumStyle
    formatter.locale = platform.Foundation.NSLocale(localeIdentifier = locale.toNsLocaleId())
    val date = platform.Foundation.NSDate.dateWithTimeIntervalSince1970(epochMillis / 1000.0)
    return formatter.stringFromDate(date)
}
```

---

## 1. Hardcoded user-facing string

```kotlin
// ❌ Literal string rendered directly — untranslatable
Text("Submit")
TextField(
    value = email,
    onValueChange = {},
    placeholder = { Text("Enter your email") },
)
IconButton(onClick = onClose) {
    Icon(Icons.Default.Close, contentDescription = "Close")
}
```

```kotlin
// ✅ Every user-visible string comes from stringResource / MR.strings
Text(stringResource(Res.string.submit_button))
TextField(
    value = email,
    onValueChange = {},
    placeholder = { Text(stringResource(Res.string.email_placeholder)) },
)
IconButton(onClick = onClose) {
    Icon(Icons.Default.Close, contentDescription = stringResource(Res.string.close_dialog))
}
```

> A11y note: `contentDescription` and `Modifier.semantics { contentDescription }` are
> user-facing — they also require resource keys. See [kmp-accessibility](../kmp-accessibility/SKILL.md).

---

## 2. Sentence concatenation

```kotlin
// ❌ Concatenation — word order breaks in Arabic, Japanese, German, etc.
Text(stringResource(Res.string.you_have) + " ${cart.count} " + stringResource(Res.string.items))
Text("${stringResource(Res.string.hello)} ${user.name}")   // looks fine in English; wrong in many others
```

```kotlin
// ✅ One resource key with named placeholder — translators reorder freely
// strings.xml: <string name="cart_summary">You have %1$d %2$s in your cart.</string>
// strings.xml: <string name="greeting">Hello, %1$s!</string>
Text(stringResource(Res.string.cart_summary, cart.count, stringResource(Res.string.item_label)))
Text(stringResource(Res.string.greeting, user.name))
```

---

## 3. Manual pluralization

```kotlin
// ❌ Hand-rolled plural — wrong for languages with 3+ plural categories (Arabic, Russian…)
Text("$count ${if (count == 1) "message" else "messages"}")
Text("$count item${ if (count != 1) "s" else "" }")
```

```kotlin
// ✅ pluralStringResource backed by <plurals> XML — correct per-locale plural selector
// strings.xml:
// <plurals name="message_count">
//   <item quantity="zero">No messages</item>
//   <item quantity="one">One message</item>
//   <item quantity="other">%1$d messages</item>
// </plurals>
Text(pluralStringResource(Res.plurals.message_count, count, count))

// moko-resources with ICU plurals:
// MR.plurals.dayCount: "{count, plural, =1{1 day} few{{count} days} other{{count} days}}"
Text(pluralStringResource(MR.plurals.dayCount, days, days))
```

---

## 4. Hardcoded date/time format

```kotlin
// ❌ Fixed pattern — US date order, wrong for most of the world
//   (This would also fail to compile in commonMain — SimpleDateFormat is Android-only)
Text(SimpleDateFormat("MM/dd/yyyy").format(Date(order.createdAtMillis)))  // not in commonMain

// ❌ Hand-built date string in a composable
Text("${date.monthNumber}/${date.dayOfMonth}/${date.year}")   // kotlinx-datetime LocalDate
```

```kotlin
// ✅ expect/actual formatter using device locale (see Setup baseline above)
val locale = LocalAppLocale.current  // CompositionLocal providing device locale
Text(formatDate(order.createdAtMillis, locale))

// In the composable — locale resolved at point of use
@Composable
fun OrderDate(epochMillis: Long) {
    val locale = LocalAppLocale.current
    Text(remember(epochMillis, locale) { formatDate(epochMillis, locale) })
}
```

---

## 5. Hardcoded number/currency

```kotlin
// ❌ Dollar sign hardcoded; toString ignores locale separators
Text("$$price")
Text("Total: $$total")
Text("${amount.toLong()} users")   // 1000 vs 1.000 vs 1,000 per locale
```

```kotlin
// ✅ expect/actual currency formatter — locale-aware separators, symbol, position
val locale = LocalAppLocale.current

// Currency
Text(remember(price, locale) { formatCurrency(price, "USD", locale) })

// Plain number with grouping
Text(remember(amount, locale) { formatNumber(amount, locale) })

// Compact notation (implement via expect/actual similarly)
Text(remember(followers, locale) { formatCompact(followers.toDouble(), locale) })
```

---

## 6. Non-RTL-safe layout

```kotlin
// ❌ Hard-wired to LTR — breaks Arabic, Hebrew, Farsi
Row(modifier = Modifier.padding(start = 16.dp, end = 8.dp)) { /* … */ }
Box(contentAlignment = Alignment.CenterStart) { /* … */ }  // correct — Start/End ARE directional
// The failure is:
Box(contentAlignment = Alignment.CenterLeft) { content() }  // Left is absolute, breaks RTL
Text(data, textAlign = TextAlign.Left)
```

```kotlin
// ✅ Directional APIs mirror automatically in RTL locales
// Column/Row Arrangement.Start and Alignment.Start are already RTL-aware in Compose
Row(
    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.Start),
    modifier = Modifier.padding(start = 16.dp, end = 8.dp), // start/end = logical, correct
) { /* … */ }

// Alignment: use CenterStart/CenterEnd not CenterLeft/CenterRight
Box(contentAlignment = Alignment.CenterStart) { content() }

Text(data, textAlign = TextAlign.Start)  // Start, not Left

// For an arrow that should flip in RTL:
val layoutDirection = LocalLayoutDirection.current
Icon(
    imageVector = if (layoutDirection == LayoutDirection.Rtl)
        Icons.Default.ArrowBack else Icons.Default.ArrowForward,
    contentDescription = null,
)

// Or wrap a subtree that needs explicit RTL direction:
CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
    arabicSubtree()
}
```

---

## 7. Missing placeholders

```kotlin
// ❌ Dynamic value concatenated AFTER the key — translators cannot see or reorder it
// strings.xml has: <string name="greeting">Hello!</string>
// Kotlin appends the name invisibly:
Text("${stringResource(Res.string.greeting)} ${user.name}")
// Arabic needs "Alice! مرحبا" — reordering impossible with concatenation
```

```kotlin
// ✅ Placeholder declared in resource so translators can reorder
// strings.xml: <string name="greeting">Hello, %1$s!</string>
Text(stringResource(Res.string.greeting, user.name))

// Multiple placeholders — translator in German can write "{actor} hat {count} Nachrichten"
// strings.xml: <string name="actor_message">%1$s sent %2$d messages</string>
Text(stringResource(Res.string.actor_message, sender.name, messages.size))
```

---

## 8. Hardcoded locale

```kotlin
// ❌ Always US English, regardless of user's device locale
// androidMain — not in commonMain, but still wrong when hardcoded:
SimpleDateFormat("yMMMd", java.util.Locale.US).format(date)
NumberFormat.getCurrencyInstance(java.util.Locale.US).format(amount)
```

```kotlin
// ✅ Resolve locale from device at point of use via expect/actual provider
// commonMain
expect fun getDeviceLocale(): AppLocale

// androidMain
actual fun getDeviceLocale(): AppLocale =
    AppLocale(
        language = java.util.Locale.getDefault().language,
        region = java.util.Locale.getDefault().country,
    )

// iosMain
actual fun getDeviceLocale(): AppLocale =
    AppLocale(
        language = platform.Foundation.NSLocale.currentLocale.languageCode ?: "en",
        region = platform.Foundation.NSLocale.currentLocale.countryCode ?: "",
    )

// CompositionLocal wired at the root composable so all children can read it
val LocalAppLocale = staticCompositionLocalOf { AppLocale("en", "US") }

@Composable
fun AppRoot() {
    val locale = remember { getDeviceLocale() }
    CompositionLocalProvider(LocalAppLocale provides locale) {
        AppTheme { /* content */ }
    }
}
```

---

## 9. Missing translations / no fallback

```xml
<!-- ❌ values/strings.xml has "checkout_button" — values-ar/strings.xml does not -->
<!-- values/strings.xml -->
<string name="checkout_button">Checkout</string>
<!-- values-ar/strings.xml is missing "checkout_button" entirely -->
<!-- Runtime: MissingResourceException or blank string in Arabic builds -->
```

```xml
<!-- ✅ Key present in every locale file -->
<!-- values/strings.xml -->
<string name="checkout_button">Checkout</string>
<!-- values-ar/strings.xml -->
<string name="checkout_button">الدفع</string>
<!-- values-es/strings.xml -->
<string name="checkout_button">Finalizar compra</string>
```

```kotlin
// ✅ CI guard: add string resource validation to your CI pipeline
// e.g. in a Gradle task or lint rule:
// - Parse all values-*/strings.xml
// - Assert every key in values/strings.xml exists in every other locale file
// Fail the build on missing keys — prevents this class of bug from reaching production.
```

---

## 10. Text baked into images

```kotlin
// ❌ Image asset has "Welcome!" burned in — untranslatable, invisible to TalkBack/VoiceOver
Image(
    painter = painterResource(Res.drawable.welcome_banner_en),
    contentDescription = null,
)

// ❌ DrawScope draws user-readable text directly — no i18n, no a11y
Canvas(modifier = Modifier.fillMaxSize()) {
    val paint = Paint().apply { color = Color.Black }
    drawContext.canvas.nativeCanvas.drawText("Revenue", 0f, 0f, android.graphics.Paint())
}
```

```kotlin
// ✅ Compose Text overlaid on the image — translatable + accessible
Box {
    Image(
        painter = painterResource(Res.drawable.welcome_banner),
        contentDescription = null, // decorative; text below provides the label
    )
    Text(
        text = stringResource(Res.string.welcome_banner),
        style = MaterialTheme.typography.headlineMedium,
        modifier = Modifier
            .align(Alignment.BottomStart)
            .padding(LocalSpacing.current.md),
    )
}

// ✅ Canvas drawing with a parallel Text composable for a11y + i18n
Box(
    modifier = Modifier.semantics {
        contentDescription = stringResource(Res.string.revenue_chart_label)
    },
) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        // draw the chart visualization — no text drawn in DrawScope
    }
}
```

---

## Do examples (positive patterns)

### Full resource entry with plural and named placeholder

```xml
<!-- values/strings.xml -->
<plurals name="unread_notifications">
    <item quantity="zero">No unread notifications</item>
    <item quantity="one">1 unread notification</item>
    <item quantity="other">%1$d unread notifications</item>
</plurals>

<string name="last_synced_at">Last synced %1$s</string>
```

```kotlin
// Usage in composable
Text(pluralStringResource(Res.plurals.unread_notifications, badge.count, badge.count))

val locale = LocalAppLocale.current
val syncDate = remember(syncState.lastSyncedMillis, locale) {
    formatDate(syncState.lastSyncedMillis, locale)
}
Text(stringResource(Res.string.last_synced_at, syncDate))
```

### Locale-aware currency + date in a receipt row

```kotlin
@Composable
fun ReceiptRow(order: Order) {
    val locale = LocalAppLocale.current
    val price = remember(order.total, locale) { formatCurrency(order.total, "USD", locale) }
    val date  = remember(order.placedAtMillis, locale) { formatDate(order.placedAtMillis, locale) }

    ListTile(
        headlineContent = {
            Text(stringResource(Res.string.order_summary, date))
        },
        trailingContent = { Text(price) },
    )
}
```

### RTL-safe card layout

```kotlin
Card {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = LocalSpacing.current.md, vertical = LocalSpacing.current.sm),
    ) {
        Text(
            stringResource(Res.string.product_name),
            textAlign = TextAlign.Start,   // Start, not Left
            modifier = Modifier.weight(1f),
        )
        // Chevron that flips in RTL automatically
        Icon(
            imageVector = Icons.AutoMirrored.Default.ChevronRight,
            contentDescription = null,
        )
    }
}
```

---

## Official references

- Compose Resources (multiplatform): https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-multiplatform-resources-usage.html
- moko-resources: https://github.com/icerockdev/moko-resources
- kotlinx-datetime: https://github.com/Kotlin/kotlinx-datetime
- ICU message format / plural rules: https://unicode-org.github.io/icu/userguide/format_parse/messages/
- CLDR plural rules (per language): https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
- `LocalLayoutDirection`: https://developer.android.com/reference/kotlin/androidx/compose/ui/platform/package-summary#LocalLayoutDirection()
- `AutoMirrored` icons (RTL-flipping): https://developer.android.com/develop/ui/compose/graphics/images/material-icons#auto-mirrored
- Team baseline: [../../guidance.md](../../guidance.md)
- SKILL.md (guard rules + checklist): [SKILL.md](./SKILL.md)

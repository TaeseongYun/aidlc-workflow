# Android i18n — Reference

Deep-dive material for `SKILL.md`: bad → good code pairs for all 10 guard rules,
formatter examples, and RTL layout XML. For the rule summary and halt conditions,
see `SKILL.md`.

---

## Rule 1 — Hardcoded user-facing string

### Bad

```kotlin
// Compose — literal string rendered directly
Text("Submit")
Text("Welcome, $userName!")

// XML layout — hardcoded android:text
<Button android:text="Continue" ... />
```

### Good

```xml
<!-- res/values/strings.xml -->
<string name="btn_submit">Submit</string>
<string name="welcome_user">Welcome, %1$s!</string>
<string name="btn_continue">Continue</string>
```

```kotlin
// Compose
Text(stringResource(R.string.btn_submit))
Text(stringResource(R.string.welcome_user, userName))
```

```xml
<!-- XML layout -->
<Button android:text="@string/btn_continue" ... />
```

---

## Rule 2 — Sentence concatenation

### Bad

```kotlin
// Fragments joined at the call site — word order breaks in many languages
val message = stringResource(R.string.you_have) + " $count " + stringResource(R.string.items)
Text(message)

// Even worse: mixing translated and raw strings
Text("Dear " + userName + ", " + stringResource(R.string.thank_you))
```

### Good

```xml
<!-- res/values/strings.xml — the full sentence is one resource with placeholders -->
<string name="you_have_n_items">You have %1$d items.</string>
<string name="dear_user_thank_you">Dear %1$s, thank you.</string>
```

```kotlin
// Compose — one stringResource call; translators can reorder %1$d and surrounding text
Text(stringResource(R.string.you_have_n_items, count))
Text(stringResource(R.string.dear_user_thank_you, userName))
```

---

## Rule 3 — Manual pluralization

### Bad

```kotlin
// Ternary — English-only; most languages have more plural forms
val label = if (count == 1) "item" else "items"
Text("$count $label")

// Appending "s"
val label = "$count item" + if (count != 1) "s" else ""
```

### Good

```xml
<!-- res/values/plurals.xml -->
<resources>
    <plurals name="item_count">
        <item quantity="one">%1$d item</item>
        <item quantity="other">%1$d items</item>
    </plurals>
</resources>

<!-- locale-qualified: res/values-pl/plurals.xml (Polish needs few/many) -->
<resources>
    <plurals name="item_count">
        <item quantity="one">%1$d element</item>
        <item quantity="few">%1$d elementy</item>
        <item quantity="many">%1$d elementów</item>
        <item quantity="other">%1$d elementu</item>
    </plurals>
</resources>
```

```kotlin
// Compose
Text(pluralStringResource(R.plurals.item_count, count, count))

// Non-Compose (e.g., ViewModel building a display string)
val label = context.resources.getQuantityString(R.plurals.item_count, count, count)
```

---

## Rule 4 — Hardcoded date/time format

### Bad

```kotlin
// Fixed pattern — wrong in many locales (day/month order, separators)
val sdf = SimpleDateFormat("MM/dd/yyyy")
val formatted = sdf.format(date)

// java.time with a hardcoded pattern
val formatter = DateTimeFormatter.ofPattern("dd-MM-yyyy")
```

### Good

```kotlin
import java.text.DateFormat
import java.util.Locale

// Locale-aware — picks the right pattern for the user's locale
val df = DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault())
val formatted = df.format(date)

// android.icu for richer CLDR support (API 24+)
import android.icu.text.DateFormat as IcuDateFormat
val icuDf = IcuDateFormat.getDateInstance(IcuDateFormat.MEDIUM, Locale.getDefault())
val formatted = icuDf.format(date)

// java.time interop with the system locale
import java.time.format.FormatStyle
import java.time.format.DateTimeFormatter
val formatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
    .withLocale(Locale.getDefault())
val formatted = localDate.format(formatter)
```

---

## Rule 5 — Hardcoded number/currency

### Bad

```kotlin
// Literal currency symbol — wrong symbol and decimal/grouping separators in most locales
Text("$${price}")
Text("€ $amount")

// Manual formatting
val formatted = "%,.2f".format(price)
```

### Good

```kotlin
import java.text.NumberFormat
import java.util.Locale

// Currency — uses the locale's symbol, decimal separator, and grouping
val currencyFmt = NumberFormat.getCurrencyInstance(Locale.getDefault())
val formatted = currencyFmt.format(price)         // e.g. "$1,234.56" in en-US, "1.234,56 €" in de-DE

// Plain number with correct grouping separators
val numberFmt = NumberFormat.getNumberInstance(Locale.getDefault())
numberFmt.maximumFractionDigits = 2
val formatted = numberFmt.format(value)

// android.icu alternative (API 24+)
import android.icu.text.NumberFormat as IcuNumberFormat
val icuFmt = IcuNumberFormat.getCurrencyInstance(Locale.getDefault())
val formatted = icuFmt.format(price)
```

---

## Rule 6 — Non-RTL-safe layout

### Bad

```xml
<!-- XML — physical left/right -->
<TextView
    android:layout_marginLeft="16dp"
    android:paddingRight="8dp"
    android:gravity="left" />
```

```kotlin
// Compose — assuming LTR; no supportsRtl in manifest
Row(horizontalArrangement = Arrangement.End) {
    // icon pinned to the right — mirrors correctly only if Arrangement.End is used,
    // BUT if the code elsewhere uses Modifier.padding(start = x, end = 0.dp) mixed
    // with hardcoded Alignment.CenterStart, it breaks
}
```

```xml
<!-- AndroidManifest.xml — RTL support missing -->
<application android:label="@string/app_name" ...>
```

### Good

```xml
<!-- XML — logical start/end -->
<TextView
    android:layout_marginStart="16dp"
    android:paddingEnd="8dp"
    android:gravity="start" />
```

```kotlin
// Compose — Alignment.Start/End and Arrangement.Start/End mirror automatically
Row(horizontalArrangement = Arrangement.End) {
    Icon(...)
    Spacer(Modifier.width(8.dp))
    Text(stringResource(R.string.action_label))
}

// Padding: start/end, not left/right
Modifier.padding(start = 16.dp, end = 8.dp)
```

```xml
<!-- AndroidManifest.xml — declare RTL support -->
<application
    android:label="@string/app_name"
    android:supportsRtl="true"
    ...>
```

---

## Rule 7 — Missing placeholders

### Bad

```xml
<!-- String resource has no placeholder; name is concatenated at the call site -->
<string name="greeting">Hello </string>
```

```kotlin
// Call site concatenation prevents translators from reordering
Text(stringResource(R.string.greeting) + userName)

// Quantity string without count placeholder
val msg = getString(R.string.items_loaded) + count
```

### Good

```xml
<!-- Placeholder in the resource — translators can move %1$s anywhere -->
<string name="greeting">Hello, %1$s!</string>
<string name="items_loaded">%1$d items loaded</string>
```

```kotlin
// Compose
Text(stringResource(R.string.greeting, userName))

// Non-Compose
val msg = getString(R.string.items_loaded, count)
```

Multiple arguments use `%1$s`, `%2$s`, `%3$d`, etc. so each can be independently
positioned in any target language.

---

## Rule 8 — Hardcoded locale

### Bad

```kotlin
// Forces US locale regardless of user setting
val fmt = NumberFormat.getCurrencyInstance(Locale.US)
val df = SimpleDateFormat("MM/dd/yyyy", Locale("en"))

// Overrides app locale without user action
AppCompatDelegate.setApplicationLocales(LocaleList.forLanguageTags("en"))
```

### Good

```kotlin
// Respect the user's system locale
val fmt = NumberFormat.getCurrencyInstance(Locale.getDefault())
val df = DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault())

// Locale list from context (honors per-app locale set by the user in Settings)
val localeList = LocaleListCompat.getDefault()
val primaryLocale = localeList[0] ?: Locale.getDefault()
val fmt = NumberFormat.getCurrencyInstance(primaryLocale)
```

Per-app language preferences (API 33+ / AppCompat `setApplicationLocales`) are
set only in response to explicit user action in Settings or your own locale picker,
never forced in application code.

---

## Rule 9 — Missing translations / no fallback

### Bad

```
res/
  values-fr/
    strings.xml          ← has "btn_checkout" in French
  values/
    strings.xml          ← missing "btn_checkout" → crash on non-French devices
```

```xml
<!-- values-fr/strings.xml -->
<string name="btn_checkout">Passer la commande</string>

<!-- values/strings.xml — key absent; ResourceNotFoundException at runtime -->
```

### Good

```
res/
  values/
    strings.xml          ← authoritative English fallback; ALL keys present here
  values-fr/
    strings.xml          ← French overrides; any missing key falls back to values/
  values-ar/
    strings.xml          ← Arabic overrides; supportsRtl="true" required in manifest
```

```xml
<!-- values/strings.xml — base file is the fallback; every key must live here -->
<string name="btn_checkout">Checkout</string>

<!-- values-fr/strings.xml — override only what differs -->
<string name="btn_checkout">Passer la commande</string>
```

During CI, use Android Lint rule `MissingTranslation` (enabled by default) to catch
keys present in locale-qualified files but missing from the base `values/` file.

---

## Rule 10 — Text baked into images

### Bad

```
res/drawable/
  button_submit_en.png    ← "Submit" text rendered inside the PNG
  banner_sale.webp        ← "SALE 50% OFF" baked into the image
```

```kotlin
// The Image composable renders all text from the asset — untranslatable
Image(
    painter = painterResource(R.drawable.banner_sale),
    contentDescription = stringResource(R.string.banner_sale_desc)
)
```

### Good

```kotlin
// Separate the background image from the text layer
Box {
    Image(
        painter = painterResource(R.drawable.banner_background),
        contentDescription = null   // decorative; text is in the Text composable below
    )
    Text(
        text = stringResource(R.string.banner_sale_label),  // translatable
        modifier = Modifier.align(Alignment.Center),
        style = MaterialTheme.typography.headlineMedium
    )
}
```

For culture-specific icons (directional arrows embedded in illustrations, currency
symbols baked into badges), provide locale-qualified drawable directories or use
vector drawables with no embedded text.

---

## Do examples — full i18n-correct patterns

### Keyed string with a named placeholder and locale-aware currency

```xml
<!-- res/values/strings.xml -->
<string name="order_total">Order total: %1$s</string>
```

```kotlin
val locale = Locale.getDefault()
val currencyFmt = NumberFormat.getCurrencyInstance(locale)
val formattedTotal = currencyFmt.format(orderTotal)              // e.g. "$42.99" or "42,99 €"

Text(stringResource(R.string.order_total, formattedTotal))
```

### Plural + placeholder

```xml
<!-- res/values/plurals.xml -->
<plurals name="unread_messages">
    <item quantity="one">%1$d unread message</item>
    <item quantity="other">%1$d unread messages</item>
</plurals>
```

```kotlin
Text(pluralStringResource(R.plurals.unread_messages, count, count))
```

### RTL-safe Compose layout

```kotlin
@Composable
fun PriceRow(label: String, price: BigDecimal) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween   // mirrors in RTL
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Start                    // logical, not Left
        )
        val fmt = NumberFormat.getCurrencyInstance(Locale.getDefault())
        Text(text = fmt.format(price))
    }
}
```

### RTL-safe XML layout

```xml
<LinearLayout
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:paddingStart="16dp"
    android:paddingEnd="16dp">

    <ImageView
        android:layout_width="24dp"
        android:layout_height="24dp"
        android:layout_marginEnd="8dp"
        android:src="@drawable/ic_info" />

    <TextView
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:gravity="start"
        android:text="@string/info_label" />
</LinearLayout>
```

---

## Review checklist

- [ ] All `Text()` / `android:text` values use `stringResource()` / `@string/` keys — no literals.
- [ ] No sentence built by joining multiple `stringResource()` calls with `+`.
- [ ] All count-dependent strings use `pluralStringResource()` / `getQuantityString()` with a `plurals.xml` resource.
- [ ] No `SimpleDateFormat("pattern")` or `DateTimeFormatter.ofPattern("pattern")` in UI-bound code.
- [ ] Currency and numbers formatted with `NumberFormat.getCurrencyInstance(Locale.getDefault())` or equivalent.
- [ ] No literal `$`, `€`, `¥`, or hand-rolled grouping separators in UI strings.
- [ ] All string resources with runtime values use `%1$s`/`%2$d` positional placeholders.
- [ ] `android:supportsRtl="true"` in `<application>`.
- [ ] XML layouts use `Start`/`End` variants; no `Left`/`Right` attributes.
- [ ] Compose uses `Alignment.Start`/`End`, `Arrangement.Start`/`End`, `Modifier.padding(start=…, end=…)`.
- [ ] No `Locale("en")`, `Locale.US`, or `Locale.ENGLISH` passed to formatters.
- [ ] Every key in locale-qualified `values-*/strings.xml` also exists in `values/strings.xml`.
- [ ] Android Lint `MissingTranslation` check is enabled (not suppressed).
- [ ] No drawable assets with user-facing text embedded; text layer is a separate `Text()` composable.
- [ ] Culture-specific icons have locale-qualified drawable alternatives or use text instead.

## Official references

- String resources: https://developer.android.com/guide/topics/resources/string-resource
- Plurals: https://developer.android.com/guide/topics/resources/string-resource#Plurals
- App localization guide: https://developer.android.com/guide/topics/resources/localization
- Per-app language: https://developer.android.com/guide/topics/resources/app-languages
- RTL support: https://developer.android.com/training/basics/supporting-devices/languages#FormatTextFields
- NumberFormat: https://developer.android.com/reference/java/text/NumberFormat
- android.icu: https://developer.android.com/reference/android/icu/text/package-summary
- A11y labels also need translation: [`../android-accessibility/SKILL.md`](../android-accessibility/SKILL.md)
- Guard rules and halt conditions: [`SKILL.md`](SKILL.md)

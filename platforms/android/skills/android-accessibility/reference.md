# android-accessibility — Reference

Deep-dive for `SKILL.md`. Focus management, TalkBack testing, semantics
merging, font scale, and bad→good Kotlin/Compose snippets for the trickiest
rules. Decision criteria live in `SKILL.md`.

## 1. Role exposure — tappable containers

```kotlin
// ❌ Generic container: TalkBack says nothing useful; no role, no double-tap affordance
Box(
    modifier = Modifier.clickable { onAddToCart() }
) {
    Icon(Icons.Default.ShoppingCart, contentDescription = null)
    Text("Add to cart")
}

// ✅ Role declared: TalkBack announces "Add to cart, button — double-tap to activate"
Box(
    modifier = Modifier
        .clickable(onClickLabel = "Add to cart") { onAddToCart() }
        .semantics { role = Role.Button }
) {
    Icon(Icons.Default.ShoppingCart, contentDescription = null)
    Text("Add to cart")
}

// ✅ Better: use the platform Button — role + semantics provided automatically
Button(onClick = { onAddToCart() }) {
    Icon(Icons.Default.ShoppingCart, contentDescription = null)
    Text("Add to cart")
}
```

## 2. Accessible names — icon-only buttons and images

```kotlin
// ❌ No accessible name: TalkBack reads nothing meaningful for the icon
IconButton(onClick = { onClose() }) {
    Icon(Icons.Default.Close, contentDescription = null)
}

// ✅ contentDescription on the Icon supplies the button's accessible name
IconButton(onClick = { onClose() }) {
    Icon(Icons.Default.Close, contentDescription = "Close")
}

// ❌ Decorative divider announced as "Image" (default fallback)
Image(
    painter = painterResource(R.drawable.divider),
    contentDescription = "Divider image"
)

// ✅ Decorative: null suppresses TalkBack announcement entirely
Image(
    painter = painterResource(R.drawable.divider),
    contentDescription = null
)

// ✅ Meaningful image: describe the content, not the element type
Image(
    painter = rememberAsyncImagePainter(user.avatarUrl),
    contentDescription = "${user.name} profile photo"
)
```

## 3. State exposure — custom controls

Native `Checkbox`, `Switch`, and `RadioButton` expose their state
automatically. For custom controls, add state flags in `Modifier.semantics`.

```kotlin
// ❌ State conveyed by color only — invisible to TalkBack
val selected by remember { mutableStateOf(false) }
Box(
    modifier = Modifier
        .background(if (selected) Color.Blue else Color.Gray)
        .clickable { selected = !selected }
)

// ✅ State in semantics: TalkBack announces "Item, selected" or "Item, not selected"
Box(
    modifier = Modifier
        .background(if (selected) Color.Blue else Color.Gray)
        .clickable { selected = !selected }
        .semantics {
            role = Role.Button
            selected = selected           // boolean flag
            stateDescription = if (selected) "Selected" else "Not selected"
        }
)

// ✅ Expanded/collapsed toggle — role + expanded flag
Row(
    modifier = Modifier
        .clickable(onClickLabel = if (expanded) "Collapse" else "Expand") {
            expanded = !expanded
        }
        .semantics {
            role = Role.Button
            this.expanded = expanded      // sets the expanded semantic property
        }
) {
    Text("Details")
    Icon(
        if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
        contentDescription = null         // parent semantics provides the label
    )
}
```

## 4. Focus management — dialogs and bottom sheets

`AlertDialog` (Material 3) moves TalkBack focus automatically. Hand-rolled
dialogs and `ModalBottomSheet` require explicit management.

```kotlin
// ✅ Hand-rolled bottom sheet — move focus in on open, restore on dismiss
@Composable
fun AccessibleBottomSheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    content: @Composable () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }

    if (visible) {
        // Move TalkBack focus to the sheet container when it becomes visible
        LaunchedEffect(Unit) {
            focusRequester.requestFocus()
        }
        Box(
            modifier = Modifier
                .focusRequester(focusRequester)
                .focusable()
        ) {
            content()
        }
    }
    // On dismiss the caller's trigger (e.g. a Button) regains focus automatically
    // because it held focus before the sheet opened.
}
```

- For route / screen transitions in Compose Navigation, place a
  `FocusRequester` on the screen's first meaningful element and call
  `requestFocus()` in a `LaunchedEffect` so TalkBack lands at the top of the
  new screen instead of the previous screen's last position.

## 5. Semantics merging — grouping card content

TalkBack stops on every focusable node by default. A list card with an icon,
title, subtitle, and trailing button creates four stops. Merge the descriptive
parts into one and keep independent actions separate.

```kotlin
// ❌ Four TalkBack stops: icon + title + subtitle + button
Row {
    Icon(Icons.Default.Mail, contentDescription = "Email")
    Column {
        Text("Order #1042")
        Text("Delivered 24 Aug")
    }
    IconButton(onClick = { onViewDetails() }) {
        Icon(Icons.Default.ChevronRight, contentDescription = "View details")
    }
}

// ✅ Card body merged into one stop; action button stays independent
Row {
    Row(
        modifier = Modifier.semantics(mergeDescendants = true) { }
            .weight(1f)
    ) {
        Icon(Icons.Default.Mail, contentDescription = null) // decorative within merged group
        Column {
            Text("Order #1042")
            Text("Delivered 24 Aug")
        }
    }
    // Action stays outside the merge so it is reachable as a separate target
    IconButton(onClick = { onViewDetails() }) {
        Icon(Icons.Default.ChevronRight, contentDescription = "View details")
    }
}

// ✅ clearAndSetSemantics: replace auto-merged children with one crafted description
Row(
    modifier = Modifier
        .clickable { onViewDetails() }
        .clearAndSetSemantics {
            contentDescription = "Order 1042, delivered 24 August. View details."
            role = Role.Button
        }
) {
    Icon(Icons.Default.Mail, contentDescription = null)
    Column {
        Text("Order #1042")
        Text("Delivered 24 Aug")
    }
    Icon(Icons.Default.ChevronRight, contentDescription = null)
}
```

`clearAndSetSemantics` is the strongest tool — it hides all descendant
semantics and replaces them with exactly what is provided. Use it when the
auto-merged text would be awkward or redundant.

## 6. Font scale — sp units and layout resilience

```kotlin
// ❌ dp unit for font size: ignores the user's font-size preference
Text(
    text = "Order total",
    fontSize = 16.dp.value.sp  // wrong — dp does not scale
)

// ✅ sp unit respects system font scale
Text(
    text = "Order total",
    fontSize = 16.sp
)

// ✅ Access current font scale for dynamic layout decisions
val fontScale = LocalDensity.current.fontScale
// e.g. switch to a vertical layout when fontScale >= 1.5f
```

Verify composables at 200% font scale (device Settings → Accessibility → Font
size). Text must not be clipped or overflow fixed-height containers. Use
`wrapContentHeight()` rather than hard-coded `height` on text containers.

```kotlin
// ❌ Fixed height clips text at 200% scale
Box(modifier = Modifier.height(48.dp)) {
    Text("Shipping address", fontSize = 16.sp)
}

// ✅ Height expands with content
Box(modifier = Modifier.wrapContentHeight()) {
    Text("Shipping address", fontSize = 16.sp)
}
```

## 7. Live regions — async status announcements

```kotlin
// ❌ Status text updates silently; TalkBack users miss "Saved" confirmation
var status by remember { mutableStateOf("") }
Text(text = status)

// ✅ LiveRegionMode.Polite: TalkBack reads the update after finishing current speech
Text(
    text = status,
    modifier = Modifier.semantics {
        liveRegion = LiveRegionMode.Polite
    }
)

// Use LiveRegionMode.Assertive only for urgent errors that must interrupt;
// Polite is correct for saves, loads, and success messages.
```

## 8. Touch target size

Material 3 `IconButton` is 48dp × 48dp by default. For custom clickables
whose visible size is smaller, expand the hit area:

```kotlin
// ❌ 24dp icon with no expanded target — hard to tap and fails the 48dp minimum
Icon(
    Icons.Default.Favorite,
    contentDescription = "Favorite",
    modifier = Modifier
        .size(24.dp)
        .clickable { onFavorite() }
)

// ✅ Expand the minimum clickable area around the small visual
Box(
    modifier = Modifier
        .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
        .clickable(onClickLabel = "Favorite") { onFavorite() }
        .semantics { role = Role.Button },
    contentAlignment = Alignment.Center
) {
    Icon(Icons.Default.Favorite, contentDescription = null) // name on the parent
}
```

## 9. TalkBack testing — how to run

1. **Enable TalkBack**: Settings → Accessibility → TalkBack → toggle on.
   Or use the shortcut (volume-up + volume-down hold on most devices).
2. **Navigate**: swipe right to move to the next element, swipe left for
   previous. Double-tap to activate the focused element.
3. **Check on every screen**:
   - Every actionable element is reachable by swipe and announced with a
     useful name and role.
   - Icon-only buttons are named (not silent or "Button").
   - Decorative images are skipped.
   - State (checked, selected, expanded) is announced.
   - Dialogs/bottom sheets trap focus inside — swiping does not escape to
     background content.
   - Text at 200% font scale (verify before TalkBack session via Settings).
4. **Android Studio layout inspector**: use the Accessibility Scanner app
   (from Google on the Play Store) to surface contrast and target-size issues
   without manual TalkBack navigation.
5. **Emulator shortcut**: `adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService`

## 10. A11y review checklist

- [ ] Every `.clickable {}` composable has `role = Role.Button` (or equivalent) in semantics, or uses a native `Button`.
- [ ] Every `IconButton` / icon-only control has a `contentDescription` on its inner `Icon`.
- [ ] All decorative `Image`s have `contentDescription = null`.
- [ ] All `Text` composables use `sp` units for `fontSize`.
- [ ] All touch targets are at least 48dp × 48dp (or wrapped in a min-size clickable).
- [ ] Custom state (selected/checked/expanded/disabled) is exposed in `Modifier.semantics`, not by color alone.
- [ ] Dialogs and bottom sheets move TalkBack focus in on open and restore it on close.
- [ ] Async status regions use `liveRegion = LiveRegionMode.Polite`.
- [ ] Card/list rows use `mergeDescendants = true` or `clearAndSetSemantics` to prevent fragmented TalkBack stops.
- [ ] Color/contrast meets WCAG AA; errors and required fields carry a text/icon signal beyond color.

## Official references

- Compose accessibility: https://developer.android.com/jetpack/compose/accessibility
- Semantics in Compose: https://developer.android.com/jetpack/compose/semantics
- Material 3 accessibility: https://m3.material.io/foundations/overview/principles
- TalkBack help: https://support.google.com/accessibility/android/answer/6006598
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [../../guidance.md](../../guidance.md)

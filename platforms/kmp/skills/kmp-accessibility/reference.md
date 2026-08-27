# kmp-accessibility — Reference

Deep-dive for `SKILL.md`. Semantics patterns, focus management, screen-reader
testing, grouping/merging, SP text scaling, and bad→good Kotlin snippets for the
trickiest rules. Decision criteria live in `SKILL.md`.

## 1. Role exposure — button/image/invisible

The most common a11y omission in Compose is a `Modifier.clickable` with no
Semantics: the screen reader sees a focusable area with no name and no role.

```kotlin
// ❌ Invisible to TalkBack/VoiceOver — no role, no label
Box(
    modifier = Modifier
        .padding(12.dp)
        .clickable { onSave() },
) {
    Icon(Icons.Default.Save, contentDescription = null)
}

// ✅ Use a native button — role + focus + keyboard for free
Button(onClick = onSave) {
    Text("Save")
}

// ✅ Icon-only: IconButton carries the button role; contentDescription provides the label
IconButton(onClick = onSave) {
    Icon(Icons.Default.Save, contentDescription = "Save")
}

// ✅ Custom tappable must declare role and label via Modifier.semantics
Box(
    modifier = Modifier
        .semantics {
            role = Role.Button
            contentDescription = "Save document"
        }
        .clickable { onSave() }
        .padding(12.dp),
) {
    Icon(Icons.Default.Save, contentDescription = null) // null: described by parent semantics
}
```

Image roles:

```kotlin
// ✅ Meaningful image — describe the content
Image(
    painter = painterResource(Res.drawable.logo),
    contentDescription = "Acme Inc. company logo",
)

// ✅ Decorative image — exclude from a11y tree entirely
Image(
    painter = painterResource(Res.drawable.background_wave),
    contentDescription = null, // null = decorative; omitted from a11y tree
)

// ✅ Or mark an arbitrary subtree invisible to the a11y tree
Box(modifier = Modifier.semantics { invisibleToUser() }) {
    // decorative divider content
}
```

## 2. Accessible names — labels and icon-only buttons

```kotlin
// ❌ Icon-only tappable with no accessible name
IconButton(onClick = onClose) {
    Icon(Icons.Default.Close, contentDescription = null)
    // TalkBack announces "button" with no name
}

// ✅ contentDescription on Icon contributes the accessible name
IconButton(onClick = onClose) {
    Icon(Icons.Default.Close, contentDescription = "Close dialog")
}

// ✅ TextField — always provide a visible or semantic label
TextField(
    value = email,
    onValueChange = onEmailChange,
    label = { Text("Email address") }, // visible label, tied automatically
)

// ✅ When no visible label is possible, use Modifier.semantics
TextField(
    value = query,
    onValueChange = onQueryChange,
    placeholder = { Text("Search…") }, // placeholder alone is not an accessible name
    modifier = Modifier.semantics { contentDescription = "Search" },
)
```

## 3. State exposure — checked / selected / disabled / expanded

Material3 built-in controls (`Checkbox`, `Switch`, `RadioButton`, `ElevatedCard`)
propagate their state to the a11y tree automatically. Custom controls must do it
explicitly.

```kotlin
// ❌ State shown only by color — screen reader hears nothing
Box(
    modifier = Modifier
        .background(if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface)
        .clickable { onToggle() },
) {
    Text("Option A")
}

// ✅ State exposed via Modifier.semantics
Box(
    modifier = Modifier
        .semantics {
            selected = isSelected
            role = Role.Button
            contentDescription = "Option A"
        }
        .background(if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface)
        .clickable { onToggle() },
) {
    Text("Option A", color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
}

// ✅ Disabled state
Box(
    modifier = Modifier.semantics {
        disabled()
        contentDescription = "Submit"
        role = Role.Button
    },
) {
    Text("Submit", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f))
}

// ✅ Expanded/collapsed (custom accordion header)
Row(
    modifier = Modifier
        .semantics {
            expanded = isExpanded
            role = Role.Button
            contentDescription = "Section details"
        }
        .clickable { onToggleExpanded() },
) {
    Text("Section details")
    Icon(
        if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
        contentDescription = null,
    )
}
```

## 4. Touch target sizing

48dp is the Material Design and Android minimum. iOS HIG recommends 44pt.
Use `minimumInteractiveComponentSize()` from Material3 or explicit `sizeIn`.

```kotlin
// ❌ 24dp icon — too small to tap reliably, fails target-size check
Icon(Icons.Default.Info, contentDescription = "Info", modifier = Modifier.size(24.dp))

// ✅ Expand hit area without changing the visual
Box(
    modifier = Modifier
        .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
        .semantics { role = Role.Button; contentDescription = "Info" }
        .clickable { onInfo() },
    contentAlignment = Alignment.Center,
) {
    Icon(Icons.Default.Info, contentDescription = null, modifier = Modifier.size(24.dp))
}

// ✅ IconButton already enforces the 48dp minimum by default
IconButton(onClick = onInfo) {
    Icon(Icons.Default.Info, contentDescription = "Info")
}

// ✅ Material3 minimumInteractiveComponentSize() modifier
Box(
    modifier = Modifier
        .minimumInteractiveComponentSize()
        .clickable { onTap() },
) {
    PillChip()
}
```

## 5. Focus management — dialogs, sheets, and overlays

Material3 `AlertDialog` and `ModalBottomSheet` manage focus automatically.
Hand-rolled overlays and custom route pages must manage focus explicitly.

```kotlin
// Pattern: move focus into an overlay, restore on close
@Composable
fun AccessibleCustomDialog(onDismiss: () -> Unit) {
    val focusRequester = remember { FocusRequester() }

    // Move focus after the first composition
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.5f))
            .semantics { isDialog = true },
    ) {
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .background(MaterialTheme.colorScheme.surface)
                .padding(LocalSpacing.current.md)
                .focusRequester(focusRequester)
                .focusable(),
        ) {
            Text("Details", style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(LocalSpacing.current.sm))
            // dialog body
            TextButton(onClick = onDismiss) { Text("Close") }
        }
    }
}
```

Caller pattern — restore focus on close:

```kotlin
val triggerFocusRequester = remember { FocusRequester() }
var showDialog by remember { mutableStateOf(false) }

Button(
    onClick = { showDialog = true },
    modifier = Modifier.focusRequester(triggerFocusRequester),
) {
    Text("Open details")
}

if (showDialog) {
    AccessibleCustomDialog(
        onDismiss = {
            showDialog = false
            // Restore focus after dialog closes
            triggerFocusRequester.requestFocus()
        }
    )
}
```

## 6. Announcing async / live changes

Compose Multiplatform exposes live-region support via `Modifier.semantics`.
Use it for status messages that appear asynchronously.

```kotlin
// ✅ Announce a save confirmation after async operation
var saveStatus by remember { mutableStateOf("") }

LaunchedEffect(isSaved) {
    if (isSaved) saveStatus = "Document saved"
}

// Live region: TalkBack/VoiceOver will announce when saveStatus changes
Text(
    text = saveStatus,
    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
)

// ✅ Progress indicator with live region
Text(
    text = "Upload progress: $percent%",
    modifier = Modifier.semantics {
        liveRegion = LiveRegionMode.Polite
        progressBarRangeInfo = ProgressBarRangeInfo(
            current = percent / 100f,
            range = 0f..1f,
        )
    },
)
```

## 7. Grouping and merging with mergeDescendants / clearAndSetSemantics

`Modifier.semantics(mergeDescendants = true)` collapses a subtree into one a11y
node so TalkBack/VoiceOver reads it as a unit. Use it for card-style rows where
the icon + title + subtitle should read together. Over-merging removes individual
focus stops for actions inside.

```kotlin
// ❌ Three separate focus stops: icon, title, subtitle — fragmented reading
Row {
    Icon(Icons.Default.Email, contentDescription = null)
    Spacer(Modifier.width(8.dp))
    Column {
        Text(contact.name)
        Text(contact.email, style = MaterialTheme.typography.bodySmall)
    }
}

// ✅ One focus stop: "John Smith, john@example.com"
Row(modifier = Modifier.semantics(mergeDescendants = true) { }) {
    Icon(
        Icons.Default.Email,
        contentDescription = null,
        modifier = Modifier.clearAndSetSemantics { }, // icon redundant after merge
    )
    Spacer(Modifier.width(8.dp))
    Column {
        Text(contact.name)
        Text(contact.email, style = MaterialTheme.typography.bodySmall)
    }
}

// ❌ Over-merge: card contains a Delete button — now unreachable separately
Card(modifier = Modifier.semantics(mergeDescendants = true) { }) {
    Row {
        Text(item.title)
        IconButton(onClick = onDelete) {
            Icon(Icons.Default.Delete, contentDescription = "Delete")
        }
    }
}

// ✅ Merge the label area only; leave the action button as its own node
Row {
    Text(
        item.title,
        modifier = Modifier
            .weight(1f)
            .semantics(mergeDescendants = true) { },
    )
    IconButton(onClick = onDelete) {
        Icon(Icons.Default.Delete, contentDescription = "Delete ${item.title}")
    }
}
```

## 8. Font scaling with SP units

```kotlin
// ❌ dp for text — suppresses OS font-size preference
Text(
    "Hello",
    style = TextStyle(fontSize = 16.dp.value.sp), // wrong: dp ≠ sp
)

// ❌ Custom LocalDensity that clamps font scale
CompositionLocalProvider(
    LocalDensity provides Density(density = LocalDensity.current.density, fontScale = 1f)
) {
    // All text in this subtree ignores user font-size preference
}
// Only acceptable when layout genuinely cannot reflow — document with:
// ponytail: font scale clamped to 1f to prevent overflow in fixed-height banner;
// revisit if banner becomes scrollable.

// ✅ Default Text with sp units already scales — nothing extra needed
Text("Hello", style = MaterialTheme.typography.bodyMedium)  // bodyMedium uses sp

// ✅ Read font scale only when sizing a non-text element proportionally
val fontScale = LocalDensity.current.fontScale
Box(modifier = Modifier.height((24 * fontScale).dp)) { /* icon */ }
```

## 9. Screen-reader testing — TalkBack (Android) & VoiceOver (iOS)

**TalkBack (Android emulator or device)**

1. Settings → Accessibility → TalkBack → turn on (or hold both volume keys for 3 s).
2. Swipe right/left to move focus between elements; double-tap to activate.
3. Check that every interactive element announces: name + role + state
   (e.g., "Save, button" / "Email address, edit box, double-tap to edit" /
   "Option A, selected, button").
4. Open a dialog/bottom sheet — focus should land inside it immediately.
5. Close — focus should return to the triggering control.

**VoiceOver (iOS — Compose Multiplatform)**

1. Settings → Accessibility → VoiceOver → turn on (or triple-click Side button).
2. Swipe right/left to move focus; double-tap to activate.
3. Use the Rotor (two-finger rotate) to navigate by Headings or Buttons.
4. Same dialog focus checks as TalkBack.

**Compose layout inspector (Android Studio)**

Run in debug mode; use **Layout Inspector → Semantics** to inspect the semantics
tree. Faster for structural checks without a device.

**`runComposeUiTest` — semantics assertions**

```kotlin
@Test
fun saveButton_hasCorrectSemantics() = runComposeUiTest {
    setContent { AppTheme { SaveButton(onSave = {}) } }

    onNodeWithContentDescription("Save")
        .assertHasClickAction()
        .assertIsEnabled()
}

@Test
fun decorativeImage_isExcluded() = runComposeUiTest {
    setContent { AppTheme { HeroImage() } }

    // Node is present visually but absent from the semantics tree
    onNodeWithContentDescription("background wave").assertDoesNotExist()
}
```

## 10. A11y review checklist

- [ ] Every tappable is a native `Button`/`IconButton` or has `Modifier.semantics { role = Role.Button }`.
- [ ] Every icon-only button has `contentDescription` on the `Icon` or enclosing semantics.
- [ ] Meaningful images have `contentDescription`; decorative images have `contentDescription = null`.
- [ ] All touch targets are ≥ 48dp in both dimensions (`minimumInteractiveComponentSize()` or `sizeIn`).
- [ ] `selected` / `disabled()` / `expanded` / `stateDescription` in `Modifier.semantics`, not color alone.
- [ ] Text uses `sp` units; `LocalDensity.fontScale` never clamped without a comment.
- [ ] Color is paired with text/icon; WCAG AA contrast met (4.5:1 body, 3:1 UI).
- [ ] Dialogs/sheets: `FocusRequester.requestFocus()` in `LaunchedEffect` on open; focus restored on close.
- [ ] Async status changes use `liveRegion = LiveRegionMode.Polite`.
- [ ] Card/row groups use `semantics(mergeDescendants = true)`; independent actions excluded from the merge.
- [ ] Native Material3 controls chosen over custom-drawn equivalents where possible;
  any `Canvas`-based control has a `Modifier.semantics` layer.

## Official references

- Compose accessibility: https://developer.android.com/develop/ui/compose/accessibility
- `Modifier.semantics` API: https://developer.android.com/reference/kotlin/androidx/compose/ui/semantics/package-summary
- `Role` enum: https://developer.android.com/reference/kotlin/androidx/compose/ui/semantics/Role
- `FocusRequester`: https://developer.android.com/reference/kotlin/androidx/compose/ui/focus/FocusRequester
- Compose Multiplatform a11y: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-accessibility.html
- `minimumInteractiveComponentSize`: https://developer.android.com/reference/kotlin/androidx/compose/material3/package-summary#minimumInteractiveComponentSize()
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [../../guidance.md](../../guidance.md)

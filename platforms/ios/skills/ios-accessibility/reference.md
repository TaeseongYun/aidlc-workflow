# ios-accessibility — Reference

Deep-dive for `SKILL.md`. Focus management, VoiceOver testing, grouping,
Dynamic Type, and bad→good SwiftUI snippets for the trickiest rules.
Decision criteria live in `SKILL.md`.

---

## 1. Role/trait — native control vs. bare container

```swift
// ❌ VoiceOver reads this as static text; no button role, no activation action
Text("Submit")
    .onTapGesture { submit() }

// ✅ Button carries .isButton trait and "Activate" action automatically
Button("Submit") { submit() }

// ❌ Image with tap gesture — no role, no name
Image(systemName: "trash")
    .onTapGesture { delete() }

// ✅ Button wrapper gives role; label gives name
Button(action: delete) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete item")
```

When a `ZStack` or custom layout must be tappable (e.g., a card):

```swift
// ✅ Explicit trait + label on the container
cardView
    .onTapGesture { openDetail() }
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("Order #1042, pending")
```

---

## 2. Accessible names — labels and icon-only buttons

```swift
// ❌ Icon button with no name — VoiceOver reads "image" or nothing
Button(action: close) {
    Image(systemName: "xmark")
}

// ✅
Button(action: close) {
    Image(systemName: "xmark")
}
.accessibilityLabel("Close")

// ✅ Meaningful image
Image("map-pin")
    .accessibilityLabel("Store location")

// ✅ Decorative image — hidden from the a11y tree
Image("background-gradient")
    .accessibilityHidden(true)
```

---

## 3. State exposure — selected, checked, disabled, loading

```swift
// ❌ Selected state shown only by background color change
Text(tab.title)
    .background(isSelected ? Color.accentColor : Color.clear)

// ✅ Trait mirrors the visual state
Text(tab.title)
    .background(isSelected ? Color.accentColor : Color.clear)
    .accessibilityAddTraits(isSelected ? .isSelected : [])

// ✅ Toggle — built-in, state announced automatically
Toggle("Notifications", isOn: $notificationsEnabled)

// ✅ Loading / live-updating indicator
ProgressView()
    .accessibilityLabel("Loading orders")
    .accessibilityAddTraits(.updatesFrequently)

// ✅ Async status announcement (no visible element needed)
UIAccessibility.post(notification: .announcement, argument: "Order placed successfully")
```

---

## 4. Focus management with @AccessibilityFocusState

`@AccessibilityFocusState` moves VoiceOver focus programmatically — analogous
to `focus()` / `aria-live` in web. Use it whenever a sheet, alert, or inline
overlay appears so VoiceOver users land in the new content immediately.

```swift
struct OrderSheet: View {
    @Binding var isPresented: Bool
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm order")
                .font(.title2.bold())
                .accessibilityFocused($titleFocused)   // focus lands here on appear

            // … sheet body …

            Button("Place order") { placeOrder() }
            Button("Cancel") { isPresented = false }
        }
        .onAppear { titleFocused = true }              // move focus in
        // Focus returns to the triggering element automatically when sheet dismisses
    }
}
```

For an inline error message that appears conditionally:

```swift
@AccessibilityFocusState private var errorFocused: Bool

if let error = validationError {
    Text(error)
        .foregroundColor(.red)
        .accessibilityFocused($errorFocused)
        .onChange(of: validationError) { _ in
            errorFocused = validationError != nil
        }
}
```

---

## 5. Grouping and merging — accessibilityElement(children:)

### Combine (merge into one focus stop)

Use when the children carry no independent actions and reading them together
is more meaningful than reading them separately.

```swift
// ❌ VoiceOver stops on "Subtotal" then "$24.99" separately — noisy
HStack {
    Text("Subtotal")
    Spacer()
    Text("$24.99")
}

// ✅ One focus stop: "Subtotal, $24.99"
HStack {
    Text("Subtotal")
    Spacer()
    Text("$24.99")
}
.accessibilityElement(children: .combine)
```

### Contain (group but keep children reachable)

Use when children have independent actions (buttons inside a card).

```swift
// ✅ The card is a logical group; buttons inside are still reachable
VStack {
    Text("Order #1042")
    Button("Track") { track() }
    Button("Cancel") { cancel() }
}
.accessibilityElement(children: .contain)
// ponytail: .contain keeps child buttons focusable; .combine would swallow them
```

### Ignore (custom label replaces all children)

Use when you want a single, hand-crafted description instead of synthesized child text.

```swift
ratingStarsView   // five Image stars
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Rating: 4 out of 5 stars")
```

---

## 6. Dynamic Type — semantic styles and ScaledMetric

```swift
// ❌ Fixed size — clips at large accessibility sizes
Text("Subtotal")
    .font(.system(size: 14))

// ✅ Semantic style — scales with the system setting
Text("Subtotal")
    .font(.subheadline)

// ✅ Custom numeric spacing/size that scales
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24

Image(systemName: "cart")
    .frame(width: iconSize, height: iconSize)
```

For containers that must not break layout at XXXL sizes, use
`.minimumScaleFactor` sparingly and only after confirming the content still
reads legibly — never `allowsTightening` as a substitute for proper layout.

---

## 7. Touch target size — expanding below 44pt

```swift
// ❌ 20×20 icon — too small to tap reliably
Image(systemName: "info.circle")
    .frame(width: 20, height: 20)
    .onTapGesture { showInfo() }

// ✅ Visual stays 20pt; hit area expands to 44pt
Button(action: showInfo) {
    Image(systemName: "info.circle")
        .frame(width: 20, height: 20)
}
.contentShape(Rectangle())
.frame(minWidth: 44, minHeight: 44)
```

---

## 8. VoiceOver testing — manual checklist

Run on a physical device or simulator (Simulator → Device → Toggle Accessibility).

Enable: Settings → Accessibility → VoiceOver → On  
Navigate: swipe right/left to move focus; double-tap to activate.

- [ ] Every tappable element receives focus and announces a meaningful label + role.
- [ ] Icon-only buttons announce their label (not "button" alone).
- [ ] Decorative images are skipped entirely.
- [ ] Sheets/alerts: focus moves into the overlay on appear; returns on dismiss.
- [ ] State changes (selected, error, loading) are announced without a swipe.
- [ ] Custom row/card reads as a unit (not as five separate text fragments).
- [ ] Dynamic Type at XXXL: text scales; layout does not clip or overflow illegibly.
- [ ] Reduce Motion (Settings → Accessibility → Motion → Reduce Motion):
  animations replaced by cross-fades or instant transitions.

Simulator shortcut: `⌘F5` toggles VoiceOver; use the Accessibility Inspector
(Xcode → Open Developer Tool → Accessibility Inspector) to audit the a11y tree
without full VoiceOver navigation.

---

## 9. A11y review checklist

- [ ] Every tappable non-Button view has `.accessibilityAddTraits(.isButton)` and a label.
- [ ] Every icon-only `Button` has `.accessibilityLabel`.
- [ ] Every decorative `Image`/`Shape` has `.accessibilityHidden(true)`.
- [ ] No `.font(.system(size: N))` on body text; semantic styles or `@ScaledMetric` used.
- [ ] State (selected, error, disabled, loading) exposed via trait or value — not color alone.
- [ ] Sheets and alerts move VoiceOver focus in on appear via `@AccessibilityFocusState`.
- [ ] Grouped content uses `.accessibilityElement(children: .combine/.contain/.ignore)` correctly.
- [ ] Touch targets are at minimum 44×44pt (padded with `.contentShape` if visual is smaller).
- [ ] Native SwiftUI controls (`Button`, `Toggle`, `Picker`, `Slider`) used before custom-drawn equivalents.

## Official references

- Apple Accessibility for SwiftUI: https://developer.apple.com/documentation/accessibility
- Human Interface Guidelines — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- AccessibilityFocusState: https://developer.apple.com/documentation/swiftui/accessibilityfocusstate
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [../../guidance.md](../../guidance.md)

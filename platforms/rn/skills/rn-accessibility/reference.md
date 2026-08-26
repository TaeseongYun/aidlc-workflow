# rn-accessibility — Reference

Deep-dive for `SKILL.md`. Focus management, screen-reader testing, grouping,
Dynamic Type, and bad→good snippets for the trickiest rules. Decision criteria
live in `SKILL.md`.

## 1. Role and accessible name (Pressable over View+onPress)

```tsx
// ❌ View+onPress: no role, no keyboard focus, invisible to assistive tech
<View onPress={onDelete} style={styles.btn}>
  <TrashIcon />
</View>

// ✅ Pressable: role exposed, focused by screen reader, named for icon-only case
<Pressable
  accessibilityRole="button"
  accessibilityLabel="Delete item"
  onPress={onDelete}
>
  <TrashIcon />
</Pressable>

// ✅ Navigation: link role signals navigation semantics to screen readers
<Pressable
  accessibilityRole="link"
  accessibilityLabel="View order details"
  onPress={() => router.push(`/orders/${id}`)}
>
  <Text>View order</Text>
</Pressable>
```

## 2. Accessible names — labels, hints, icon-only controls

```tsx
// ✅ Visible text label — Text child is the accessible name automatically
<Pressable accessibilityRole="button" onPress={onSave}>
  <Text>Save</Text>
</Pressable>

// ✅ Icon-only: must supply accessibilityLabel explicitly
<Pressable
  accessibilityRole="button"
  accessibilityLabel="Close"
  onPress={onClose}
>
  <CloseIcon accessible={false} />  {/* hide decorative icon from tree */}
</Pressable>

// ✅ Image with meaning: label describes the content
<Image
  source={{ uri: user.avatar }}
  accessibilityLabel={`${user.name} profile photo`}
/>

// ✅ Decorative image: excluded from a11y tree
<Image
  source={require('./divider.png')}
  importantForAccessibility="no"   // Android
  accessible={false}               // iOS
/>
```

## 3. State exposure (disabled / checked / busy / expanded)

Screen readers announce state alongside role and name. Color alone is never enough.

```tsx
// ✅ Disabled button — state propagated to assistive tech
<Pressable
  accessibilityRole="button"
  accessibilityLabel="Submit"
  accessibilityState={{ disabled: isLoading }}
  disabled={isLoading}
  onPress={onSubmit}
>
  {isLoading ? <ActivityIndicator /> : <Text>Submit</Text>}
</Pressable>

// ✅ Checkbox
<Pressable
  accessibilityRole="checkbox"
  accessibilityLabel="Accept terms"
  accessibilityState={{ checked: accepted }}
  onPress={() => setAccepted(v => !v)}
>
  <CheckIcon visible={accepted} />
  <Text>Accept terms</Text>
</Pressable>

// ✅ Expandable section
<Pressable
  accessibilityRole="button"
  accessibilityLabel="FAQ: How do I reset my password?"
  accessibilityState={{ expanded: open }}
  onPress={() => setOpen(v => !v)}
>
  <Text>How do I reset my password?</Text>
  <ChevronIcon rotated={open} />
</Pressable>
{open && <Text>{answer}</Text>}

// ❌ State by color only — screen reader announces nothing about loading
<Pressable onPress={onSubmit} style={{ opacity: isLoading ? 0.4 : 1 }}>
  <Text>Submit</Text>
</Pressable>
```

## 4. Focus management — modals, bottom sheets, async updates

### Move focus into an overlay on open

```tsx
import { useRef, useEffect } from 'react';
import { AccessibilityInfo, findNodeHandle, View } from 'react-native';

function BottomSheet({ visible, onClose, children }: Props) {
  const containerRef = useRef<View>(null);

  useEffect(() => {
    if (!visible) return;
    // Give RN a frame to render the overlay before moving focus
    const id = setTimeout(() => {
      const tag = findNodeHandle(containerRef.current);
      if (tag) AccessibilityInfo.setAccessibilityFocus(tag);
    }, 0);
    return () => clearTimeout(id);
  }, [visible]);

  if (!visible) return null;
  return (
    <View ref={containerRef} accessible={true} accessibilityViewIsModal={true}>
      {children}
    </View>
  );
}
```

- `accessibilityViewIsModal={true}` tells VoiceOver to restrict focus to the
  overlay while it is open — equivalent to a focus trap.
- For Android TalkBack, `importantForAccessibility="no-hide-descendants"` on
  the content behind the overlay prevents focus from escaping.

### Restore focus to the trigger on close

```tsx
function useOverlayFocus(visible: boolean) {
  const triggerRef = useRef<View>(null);  // attach to the button that opens the overlay

  const close = useCallback(() => {
    setVisible(false);
    setTimeout(() => {
      const tag = findNodeHandle(triggerRef.current);
      if (tag) AccessibilityInfo.setAccessibilityFocus(tag);
    }, 0);
  }, []);

  return { triggerRef, close };
}
```

### Announcing async / live updates

```tsx
import { AccessibilityInfo } from 'react-native';

// After a save completes, announce politely to TalkBack / VoiceOver
async function handleSave() {
  await save(data);
  AccessibilityInfo.announceForAccessibility('Changes saved.');
}

// Loading / busy state — pair with accessibilityState busy
function LoadingRow() {
  return (
    <View
      accessibilityRole="progressbar"
      accessibilityLabel="Loading results"
      accessibilityState={{ busy: true }}
    />
  );
}
```

## 5. Touch target size — hitSlop

The minimum is 44×44 pt on iOS, 48×48 dp on Android. When the visual is
smaller, expand the hit area with `hitSlop` rather than enlarging the visual.

```tsx
// ✅ Visual icon is 24px but tappable area is 44px
<Pressable
  accessibilityRole="button"
  accessibilityLabel="Add to favourites"
  hitSlop={{ top: 10, right: 10, bottom: 10, left: 10 }}  // 24 + 20 = 44pt
  onPress={onFavourite}
>
  <HeartIcon size={24} />
</Pressable>

// ❌ No hitSlop on a small icon — impossible to tap accurately with motor impairments
<Pressable accessibilityRole="button" onPress={onFavourite}>
  <HeartIcon size={20} />
</Pressable>
```

## 6. Grouping — read a unit once, not fragment by fragment

Related labels and values should be merged into one focusable unit so TalkBack
and VoiceOver announce them as a sentence, not word by word.

```tsx
// ❌ Fragmented: screen reader stops on "Product", then "Running Shoes", then "$129"
<View>
  <Text>Product</Text>
  <Text>Running Shoes</Text>
  <Text>$129</Text>
</View>

// ✅ Grouped: announces "Running Shoes, $129" as one stop
<View
  accessible={true}
  accessibilityLabel="Running Shoes, $129"
>
  <Text aria-hidden>Product</Text>  {/* label covers it; hide redundant prefix */}
  <Text>Running Shoes</Text>
  <Text>$129</Text>
</View>

// ✅ List item with action — group info, keep action separate so users can
//    reach each tap target independently
<View accessible={true} accessibilityLabel={`Order #${id}, ${status}, placed ${date}`}>
  <Text>Order #{id}</Text>
  <Text>{status}</Text>
  <Text>{date}</Text>
</View>
<Pressable accessibilityRole="button" accessibilityLabel={`View order #${id}`} onPress={…}>
  <Text>View</Text>
</Pressable>
```

Do not over-merge: grouping an entire list card into one focusable element that
also contains tappable actions removes the actions from the a11y tree. Keep
informational content grouped; keep interactive controls as separate focusable elements.

## 7. Dynamic Type — font scaling

`allowFontScaling` is `true` by default. Never override it.

```tsx
// ❌ Disables user's font-size preference; text becomes inaccessible at large scales
<Text allowFontScaling={false} style={{ fontSize: 14 }}>Description</Text>

// ✅ Scales with the OS setting; layout adapts
<Text style={{ fontSize: 14 }}>Description</Text>

// ❌ Fixed height clips scaled text
<View style={{ height: 20 }}>
  <Text>Label</Text>
</View>

// ✅ Let height expand with content
<View style={{ minHeight: 20 }}>
  <Text>Label</Text>
</View>
```

For containers whose height must be constrained, use `numberOfLines` with
`ellipsizeMode` and expose the full content via `accessibilityLabel`.

## 8. Screen-reader testing

### VoiceOver (iOS)

1. Settings → Accessibility → VoiceOver → On (or triple-click the side button
   with the shortcut set).
2. Swipe right to move to the next focusable element; double-tap to activate.
3. Verify: role announced ("button"), name announced, state announced
   ("dimmed" for disabled, "checked" for checkbox).
4. Open a bottom sheet — confirm focus moves in and does not leak behind it.
5. Close the sheet — confirm focus returns to the trigger.

### TalkBack (Android)

1. Settings → Accessibility → TalkBack → On (or press Volume Up + Down for 3 s
   if the shortcut is enabled).
2. Swipe right to move; double-tap to activate.
3. Verify: element is reachable, role spoken, state spoken.
4. Open an overlay — confirm content behind it is unreachable
   (`importantForAccessibility="no-hide-descendants"` on backdrop).
5. Check `announceForAccessibility` fires after async actions.

### Useful shell commands during development

```sh
# iOS Simulator: toggle VoiceOver without going into Settings
xcrun simctl accessibility <DEVICE_UDID> voiceOver --enable

# Android Emulator: enable TalkBack
adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
```

## 9. A11y review checklist

- [ ] Every tappable is `<Pressable accessibilityRole="button/link">`, not `<View onPress>`.
- [ ] All actionable controls and meaningful images have `accessibilityLabel`.
- [ ] Decorative images have `importantForAccessibility="no"` / `accessible={false}`.
- [ ] Touch targets are ≥ 44×44 pt; `hitSlop` applied where the visual is smaller.
- [ ] `accessibilityState` carries `disabled`/`checked`/`selected`/`expanded`/`busy`.
- [ ] `allowFontScaling` is not set to `false` anywhere; containers use `minHeight` or `flex`.
- [ ] Color paired with text/icon; contrast meets WCAG AA (4.5:1 / 3:1).
- [ ] Modals/sheets move focus in on open and restore it on close.
- [ ] Related content is grouped; interactive controls remain separate focusable items.
- [ ] Platform `Switch`/`CheckBox` used before a custom-drawn alternative.

## Official references

- React Native Accessibility: https://reactnative.dev/docs/accessibility
- `AccessibilityInfo` API: https://reactnative.dev/docs/accessibilityinfo
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Apple VoiceOver / Dynamic Type: https://developer.apple.com/documentation/accessibility
- Android TalkBack / Accessibility: https://developer.android.com/guide/topics/ui/accessibility
- Team baseline: [../../guidance.md](../../guidance.md)

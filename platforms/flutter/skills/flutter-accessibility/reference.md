# flutter-accessibility — Reference

Deep-dive for `SKILL.md`. Semantics patterns, focus management, screen-reader
testing, grouping/merging, textScaler, and bad→good Dart snippets for the
trickiest rules. Decision criteria live in `SKILL.md`.

## 1. Role exposure — button/image/hidden

The most common a11y omission in Flutter is a `GestureDetector` with no
Semantics: the screen reader sees a focusable area with no name and no role.

```dart
// ❌ Invisible to TalkBack/VoiceOver — no role, no label
GestureDetector(
  onTap: onSave,
  child: Container(
    padding: const EdgeInsets.all(12),
    child: const Icon(Icons.save),
  ),
)

// ✅ Use a native button — role + focus + keyboard for free
ElevatedButton(
  onPressed: onSave,
  child: const Text('Save'),
)

// ✅ Icon-only: IconButton carries the button role; tooltip provides the label
IconButton(
  tooltip: 'Save',
  icon: const Icon(Icons.save),
  onPressed: onSave,
)

// ✅ Custom tappable must wrap with Semantics
Semantics(
  button: true,
  label: 'Save document',
  child: GestureDetector(
    onTap: onSave,
    child: const _CustomSaveWidget(),
  ),
)
```

Image roles:

```dart
// ✅ Meaningful image — describe the content
Image.asset(
  'assets/logo.png',
  semanticsLabel: 'Acme Inc. company logo',
)

// ✅ Decorative image — exclude from a11y tree entirely
Image.asset(
  'assets/background_wave.png',
  excludeFromSemantics: true,
)

// ✅ Or exclude an arbitrary widget subtree
ExcludeSemantics(
  child: SvgPicture.asset('assets/divider.svg'),
)
```

## 2. Accessible names — labels and icon-only buttons

```dart
// ❌ Icon-only tappable with no accessible name
IconButton(
  icon: const Icon(Icons.close),
  onPressed: onClose,
  // TalkBack announces "button" with no name
)

// ✅ tooltip: contributes the accessible name
IconButton(
  tooltip: 'Close dialog',
  icon: const Icon(Icons.close),
  onPressed: onClose,
)

// ✅ TextField — always provide a visible or semantic label
TextField(
  decoration: const InputDecoration(
    labelText: 'Email address',   // visible label, tied automatically
  ),
)

// ✅ When no visible label is possible, use Semantics
Semantics(
  label: 'Search',
  child: TextField(
    decoration: const InputDecoration(
      hintText: 'Search…',        // hint alone is not an accessible name
    ),
  ),
)
```

## 3. State exposure — checked / selected / disabled / expanded

Flutter's built-in controls (`Checkbox`, `Switch`, `Radio`, `ExpansionTile`)
propagate their state to the a11y tree automatically. Custom controls must do it
explicitly.

```dart
// ❌ State shown only by color — screen reader hears nothing
Container(
  color: isSelected ? Colors.blue : Colors.grey,
  child: const Text('Option A'),
)

// ✅ State exposed via Semantics
Semantics(
  selected: isSelected,
  button: true,
  label: 'Option A',
  child: GestureDetector(
    onTap: () => setState(() => isSelected = !isSelected),
    child: Container(
      color: isSelected ? Colors.blue : Colors.grey,
      child: const Text('Option A'),
    ),
  ),
)

// ✅ Disabled state
Semantics(
  enabled: false,
  label: 'Submit',
  button: true,
  child: GestureDetector(
    onTap: null,
    child: const _SubmitButton(enabled: false),
  ),
)

// ✅ Expanded/collapsed (custom accordion header)
Semantics(
  expanded: isExpanded,
  button: true,
  label: 'Section details',
  child: InkWell(
    onTap: () => setState(() => isExpanded = !isExpanded),
    child: _AccordionHeader(isExpanded: isExpanded),
  ),
)
```

## 4. Touch target sizing

`kMinInteractiveDimension` is 48.0 logical pixels — the Material Design and
Android minimum. iOS HIG recommends 44pt. Use the constant; do not hard-code.

```dart
// ❌ 24dp icon — too small to tap reliably, fails target-size check
Icon(Icons.info, size: 24)

// ✅ Expand hit area without changing the visual
SizedBox(
  width: kMinInteractiveDimension,
  height: kMinInteractiveDimension,
  child: Center(child: Icon(Icons.info, size: 24)),
)

// ✅ IconButton already enforces the 48dp minimum by default
IconButton(
  icon: const Icon(Icons.info),
  onPressed: onInfo,
)

// ✅ Custom tappable — constrain to minimum
ConstrainedBox(
  constraints: const BoxConstraints(
    minWidth: kMinInteractiveDimension,
    minHeight: kMinInteractiveDimension,
  ),
  child: GestureDetector(
    onTap: onTap,
    child: const _PillChip(),
  ),
)
```

## 5. Focus management — dialogs, sheets, and overlays

Flutter's `AlertDialog` and `showModalBottomSheet` move focus automatically.
Hand-rolled overlays and custom route pages must manage focus explicitly.

```dart
// Pattern: move focus into an overlay, restore on close
class _AccessibleDialog extends StatefulWidget {
  final VoidCallback onClose;
  const _AccessibleDialog({required this.onClose});

  @override
  State<_AccessibleDialog> createState() => _AccessibleDialogState();
}

class _AccessibleDialogState extends State<_AccessibleDialog> {
  final FocusNode _dialogFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Move focus after the frame is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _dialogFocus,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
          title: const Text('Details'),
        ),
        body: const _DialogBody(),
      ),
    );
  }
}
```

Caller pattern — restore focus on close:

```dart
// Track the widget that triggered the dialog
final _triggerFocus = FocusNode();

// In the trigger button
Focus(
  focusNode: _triggerFocus,
  child: ElevatedButton(
    onPressed: () async {
      await showDialog<void>(
        context: context,
        builder: (_) => const _AccessibleDialog(onClose: Navigator.of(context).pop),
      );
      // Restore focus after dialog closes
      _triggerFocus.requestFocus();
    },
    child: const Text('Open details'),
  ),
)
```

## 6. Announcing async / live changes

`SemanticsService.announce` is the Flutter equivalent of `aria-live`. Use it
for status messages that appear asynchronously (save confirmation, network
errors, background task completion).

```dart
// ✅ Announce a save confirmation after async operation
Future<void> _save() async {
  await _repository.save(_formData);
  SemanticsService.announce('Document saved', TextDirection.ltr);
}

// ✅ Announce an error
void _onNetworkError() {
  SemanticsService.announce(
    'Could not connect. Check your connection and try again.',
    TextDirection.ltr,
  );
}

// ponytail: liveRegion: true on a Semantics node works for continuously
// updating values (e.g., a progress label); SemanticsService.announce is
// better for one-shot status messages.
Semantics(
  liveRegion: true,
  label: 'Upload progress: $percent%',
  child: LinearProgressIndicator(value: percent / 100),
)
```

## 7. Grouping and merging with MergeSemantics / ExcludeSemantics

`MergeSemantics` collapses a subtree into one a11y node so TalkBack/VoiceOver
reads it as a unit. Use it for card-style rows where the icon + title + subtitle
should read together. Over-merging (wrapping the whole screen) removes
individual focus stops for actions inside.

```dart
// ❌ Three separate focus stops: icon, title, subtitle — fragmented reading
Row(
  children: [
    const Icon(Icons.email),
    const SizedBox(width: 8),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(contact.name),
        Text(contact.email, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  ],
)

// ✅ One focus stop: "John Smith, john@example.com"
MergeSemantics(
  child: Row(
    children: [
      ExcludeSemantics(child: const Icon(Icons.email)), // icon redundant after merge
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contact.name),
          Text(contact.email, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ],
  ),
)

// ❌ Over-merge: card contains a Delete button — now unreachable separately
MergeSemantics(
  child: Card(
    child: Row(
      children: [
        Text(item.title),
        IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
      ],
    ),
  ),
)

// ✅ Merge the label area only; leave the action button as its own node
Row(
  children: [
    Expanded(
      child: MergeSemantics(child: Text(item.title)),
    ),
    IconButton(
      tooltip: 'Delete ${item.title}',
      icon: const Icon(Icons.delete),
      onPressed: onDelete,
    ),
  ],
)
```

## 8. Font scaling with MediaQuery.textScaler

```dart
// ❌ Hard-coded scale suppresses OS font-size preference
Text(
  'Hello',
  textScaleFactor: 1.0,   // deprecated but still seen; ignores user setting
)

// ❌ Clamping to a max suppresses accessibility needs
Builder(
  builder: (context) {
    final clamped = MediaQuery.of(context).copyWith(
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
    );
    return MediaQuery(data: clamped, child: child);
  },
)
// Only acceptable when layout genuinely cannot reflow — document with
// // ponytail: clamped at 1.3 to prevent overflow in fixed-height banner;
// revisit if banner becomes scrollable.

// ✅ Default Text already scales — nothing extra needed
const Text('Hello')

// ✅ Read the scaler only when you need to size a non-text element proportionally
final scale = MediaQuery.textScalerOf(context).scale(1.0);
SizedBox(height: 24 * scale, child: const _Icon())
```

## 9. Screen-reader testing — TalkBack (Android) & VoiceOver (iOS)

**TalkBack (Android emulator or device)**

1. Settings → Accessibility → TalkBack → turn on (or use the accessibility
   shortcut: hold both volume keys for 3 s).
2. Swipe right/left to move focus between elements; double-tap to activate.
3. Check that every interactive element announces: name + role + state
   (e.g., "Save, button" / "Email address, text field, double-tap to edit" /
   "Option A, selected, button").
4. Open a dialog/bottom sheet — focus should land inside it immediately.
5. Close — focus should return to the triggering control.

**VoiceOver (iOS simulator or device)**

1. Settings → Accessibility → VoiceOver → turn on (or triple-click Side button
   if set as shortcut).
2. Swipe right/left to move focus; double-tap to activate.
3. Use the Rotor (two-finger rotate) to navigate by Headings, Links, or Buttons.
4. Same dialog focus checks as TalkBack.

**Flutter Accessibility Inspector (desktop)**

Run in debug mode; use the **Accessibility** pane in DevTools (accessible via
`flutter pub global run devtools`) to inspect the semantics tree. This is
faster for structural checks without a device.

**`flutter test` — SemanticsController**

```dart
testWidgets('Save button has correct semantics', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MyApp());

  expect(
    tester.getSemantics(find.text('Save')),
    matchesSemantics(
      label: 'Save',
      isButton: true,
      hasTapAction: true,
    ),
  );
  handle.dispose();
});

testWidgets('Decorative image is excluded', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MyApp());

  // Widget is present visually but absent from the semantics tree
  expect(
    find.bySemanticsLabel('background wave'),
    findsNothing,
  );
  handle.dispose();
});
```

## 10. A11y review checklist

- [ ] Every tappable is a native button or wrapped in `Semantics(button: true)`.
- [ ] Every icon-only button has `tooltip:` or `Semantics(label: ...)`.
- [ ] Meaningful images have `semanticsLabel`; decorative images have
  `excludeFromSemantics: true` or `ExcludeSemantics`.
- [ ] All touch targets are ≥ `kMinInteractiveDimension` (48dp) in both dimensions.
- [ ] checked / selected / disabled / expanded state is in `Semantics`, not color
  alone.
- [ ] `textScaleFactor`/`textScaler` is never hard-coded to 1.0; no unchecked
  clamp without a comment.
- [ ] Color is paired with text/icon; WCAG AA contrast met (4.5:1 body, 3:1 UI).
- [ ] Dialogs/sheets: focus moves in on open, restores to trigger on close.
- [ ] Async status changes call `SemanticsService.announce`.
- [ ] Card/row groups use `MergeSemantics`; independent actions excluded from the merge.
- [ ] Native Flutter controls chosen over custom-drawn equivalents where possible;
  any `CustomPaint`-based control has a `Semantics` layer.

## Official references

- Flutter accessibility docs: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility
- `Semantics` API: https://api.flutter.dev/flutter/widgets/Semantics-class.html
- `MergeSemantics` / `ExcludeSemantics`: https://api.flutter.dev/flutter/widgets/MergeSemantics-class.html
- `SemanticsService.announce`: https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html
- `kMinInteractiveDimension`: https://api.flutter.dev/flutter/material/kMinInteractiveDimension-constant.html
- `MediaQuery.textScalerOf`: https://api.flutter.dev/flutter/widgets/MediaQuery/textScalerOf.html
- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- Team baseline: [../../guidance.md](../../guidance.md)

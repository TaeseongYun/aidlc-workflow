# rn-performance-ux — Reference

Deep-dive for `SKILL.md`. Lists + keys, Reanimated, styling, accessibility.
Decision criteria live in `SKILL.md`.

## 1. Virtualized lists with stable keys

```tsx
// ❌ Unbounded map inside a ScrollView — renders everything, no recycling
<ScrollView>{items.map((it, i) => <Row key={i} item={it} />)}</ScrollView>

// ✅ FlatList/FlashList — virtualized; stable id key, not index
<FlashList
  data={items}
  keyExtractor={(it) => it.id}          // stable id, NOT the index
  renderItem={({ item }) => <Row item={item} />}
  estimatedItemSize={72}
/>
```

- Index keys on reorderable data recycle the wrong row state (checkboxes, inputs
  jump). Use a stable domain id.

## 2. Animate on the UI thread (Reanimated worklets)

```tsx
// ❌ animation driven by React renders — a setState per frame, janky
const [x, setX] = useState(0);
useEffect(() => { const id = setInterval(() => setX(v => v + 1), 16); return () => clearInterval(id); }, []);

// ✅ shared value + worklet runs on the UI thread, off the JS render loop
const x = useSharedValue(0);
const style = useAnimatedStyle(() => ({ transform: [{ translateX: x.value }] }));
x.value = withTiming(100);
```

## 3. One styling system

```tsx
// ❌ two styling systems in one app (styled-components next to NativeWind)
// ✅ match the project's convention — a second system fragments tokens + bundle
const styles = StyleSheet.create({ card: { padding: 16 } });
```

## 4. Accessibility (safety guard)

```tsx
// ❌ Pressable with no role/label, tiny target
<Pressable onPress={onClose}><Icon name="x" /></Pressable>

// ✅ role + label + ≥44pt target
<Pressable
  onPress={onClose}
  accessibilityRole="button"
  accessibilityLabel="Close"
  hitSlop={8}
  style={{ minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}
>
  <Icon name="x" />
</Pressable>
```

- Announce async status where it matters:
  `AccessibilityInfo.announceForAccessibility('Saved')`.

## 5. Memoize rows on evidence

```tsx
// Only after measuring re-render cost (not reflexively):
const Row = React.memo(function Row({ item, onPress }: RowProps) { /* ... */ });
const onPress = useCallback((id: string) => nav.navigate('Order', { id }), [nav]); // stable identity
```

## 6. Performance/UX review checklist

- [ ] Long/unbounded lists use `FlatList`/`FlashList`, not `ScrollView` + `.map`.
- [ ] `keyExtractor` uses a stable id, never the array index on reorderable data.
- [ ] Animations run via Reanimated worklets, not React renders.
- [ ] One styling system.
- [ ] Interactive elements have `accessibilityRole` + `accessibilityLabel`.
- [ ] Touch targets ≥ 44pt.
- [ ] `memo`/`useCallback` added only against a measured re-render problem.

## Official references

- FlatList & optimization: https://reactnative.dev/docs/optimizing-flatlist-configuration
- FlashList: https://shopify.github.io/flash-list/
- Reanimated: https://docs.swmansion.com/react-native-reanimated/
- React Native accessibility: https://reactnative.dev/docs/accessibility
- Apple HIG / Material touch-target guidance (≥44pt / 48dp): https://developer.apple.com/design/human-interface-guidelines/accessibility
- Team baseline: [../../guidance.md](../../guidance.md)

# rn-design-system — Reference

Bad → good code pairs for all 10 guard rules, plus Mode-A worked examples.
Decision criteria and rule definitions live in [SKILL.md](./SKILL.md).
Generation counterpart: [rn-figma-to-code](../rn-figma-to-code/SKILL.md).

---

## Rule 1 — Hardcoded color

**Bad** — hex literal from Figma pasted into `StyleSheet`:

```tsx
// ❌ Figma hex pasted directly — breaks theming and dark mode
const styles = StyleSheet.create({
  header: { backgroundColor: '#3B82F6' },
  label:  { color: '#1A1A1A' },
  overlay:{ backgroundColor: 'rgba(0, 0, 0, 0.5)' },
});
```

**Good** — semantic token from the theme object:

```tsx
// ✅ Theme token — adapts to re-theming and dark mode
import { theme } from '../theme';

const styles = StyleSheet.create({
  header:  { backgroundColor: theme.colors.primary },
  label:   { color: theme.colors.onSurface },
  overlay: { backgroundColor: theme.colors.scrim },   // opacity baked into token
});
```

With `@shopify/restyle`:

```tsx
// ✅ Restyle Box — no StyleSheet needed; token resolved by ThemeProvider
<Box backgroundColor="primary" />
```

---

## Rule 2 — Magic spacing / size

**Bad** — raw magic numbers scattered in component styles:

```tsx
// ❌ Off-scale literals — inconsistent across the app
const styles = StyleSheet.create({
  container: { padding: 13, marginBottom: 7, gap: 10 },
  avatar:    { width: 36, height: 36 },
});
```

**Good** — spacing scale from the theme:

```tsx
// ✅ Token-based — changing the scale updates every consumer
import { theme } from '../theme';

const styles = StyleSheet.create({
  container: {
    padding: theme.space.md,        // 16
    marginBottom: theme.space.xs,   // 8
    gap: theme.space.sm,            // 8  (RN ≥ 0.71)
  },
  avatar: {
    width: theme.size.avatarSm,     // 36 defined once in theme
    height: theme.size.avatarSm,
  },
});
```

With restyle:

```tsx
// ✅ Restyle Box props map directly to theme spacing keys
<Box padding="md" marginBottom="xs" gap="sm" />
```

---

## Rule 3 — Ad-hoc typography

**Bad** — font properties set per-component:

```tsx
// ❌ Per-component typography — diverges from the type ramp immediately
const styles = StyleSheet.create({
  title: { fontSize: 18, fontWeight: '600', lineHeight: 24, fontFamily: 'Inter-SemiBold' },
  body:  { fontSize: 14, fontWeight: '400', lineHeight: 20, fontFamily: 'Inter-Regular' },
});
```

**Good** — text-style tokens spread into the `StyleSheet`:

```tsx
// ✅ Theme text style — one place to update the type ramp
import { theme } from '../theme';

const styles = StyleSheet.create({
  title: { ...theme.text.titleM },    // { fontSize:18, fontWeight:'600', lineHeight:24, fontFamily:'Inter-SemiBold' }
  body:  { ...theme.text.bodyM },     // { fontSize:14, fontWeight:'400', lineHeight:20, fontFamily:'Inter-Regular' }
});
```

With restyle `Text` component:

```tsx
// ✅ Restyle Text — variant resolved from theme.textVariants
<Text variant="titleM">{title}</Text>
<Text variant="bodyM">{body}</Text>
```

---

## Rule 4 — Reinvented component

**Bad** — bespoke button duplicating the design system:

```tsx
// ❌ Fifth bespoke Button — drifts from the design system the moment it lands
function PrimaryButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <TouchableOpacity
      onPress={onPress}
      style={{ backgroundColor: '#3B82F6', borderRadius: 8, paddingHorizontal: 16, paddingVertical: 10 }}
    >
      <Text style={{ color: '#fff', fontWeight: '600', fontSize: 14 }}>{label}</Text>
    </TouchableOpacity>
  );
}
```

**Good** — import the existing design-system component:

```tsx
// ✅ Existing Button — all visual rules maintained in one place
import { Button } from '../components/Button';

// caller:
<Button label="Pay" variant="primary" onPress={onPress} />
```

If the existing `Button` lacks a needed prop, add the prop to `Button` — don't fork it.

---

## Rule 5 — Off-scale variant

**Bad** — a near-duplicate that is not a token:

```tsx
// ❌ #3B83F7 ≠ brand primary #3B82F6 — one-off copy that silently diverges
const styles = StyleSheet.create({
  badge:  { backgroundColor: '#3B83F7' },  // almost brand-primary
  chip:   { borderRadius: 7 },             // almost theme.radius.sm=8
  inset:  { padding: 14 },                 // almost theme.space.md=16
});
```

**Good** — exact token reference:

```tsx
// ✅ Token value — single source of truth; no drift
import { theme } from '../theme';

const styles = StyleSheet.create({
  badge: { backgroundColor: theme.colors.primary },  // #3B82F6
  chip:  { borderRadius: theme.radius.sm },           // 8
  inset: { padding: theme.space.md },                 // 16
});
```

Grep check when reviewing:

```bash
# Surface near-duplicates of known brand color
grep -rE '#3B8[0-9A-Fa-f]{4}' src/
# Surface magic radii near token values
grep -rE 'borderRadius:\s*(5|6|7|9|10|11)' src/
```

---

## Rule 6 — Inline style bypassing theme

**Bad** — static literal object inline in JSX:

```tsx
// ❌ Static inline style — bypasses StyleSheet optimization and theme
<View style={{ padding: 16, backgroundColor: '#ffffff', borderRadius: 8, marginTop: 12 }}>
  <Text style={{ fontSize: 14, color: '#333333', fontWeight: '500' }}>Hello</Text>
</View>
```

**Good** — `StyleSheet.create` referencing theme; inline only for computed/animated values:

```tsx
// ✅ StyleSheet + tokens; inline reserved for truly dynamic values
import { theme } from '../theme';

const styles = StyleSheet.create({
  card:  { padding: theme.space.md, backgroundColor: theme.colors.surface,
           borderRadius: theme.radius.md, marginTop: theme.space.sm },
  label: { ...theme.text.bodyM, color: theme.colors.onSurface },
});

// animated opacity is legitimately dynamic — inline is fine here
<View style={[styles.card, { opacity: fadeAnim }]}>
  <Text style={styles.label}>Hello</Text>
</View>
```

---

## Rule 7 — Dark-mode / theme break

**Bad** — hardcoded colors that break in dark mode:

```tsx
// ❌ Hardcoded white/black — invisible in dark mode
const styles = StyleSheet.create({
  screen: { backgroundColor: 'white' },
  text:   { color: 'black' },
  border: { borderColor: '#e5e7eb' },
});

// ❌ Manual dark-mode patch with more raw literals — still off-system
const colorScheme = useColorScheme();
const bg = colorScheme === 'dark' ? '#000' : '#fff';  // not using theme variants
```

**Good** — semantic tokens + theme variants resolved at runtime:

```tsx
// ✅ Option A: restyle ThemeProvider — variants switch the whole theme object
import { useTheme } from '@shopify/restyle';
import { Theme } from '../theme';

function ScreenBackground() {
  const { colors } = useTheme<Theme>();
  return (
    <Box flex={1} backgroundColor="background">
      <Text color="onSurface">Hello</Text>
    </Box>
  );
}

// ThemeProvider at root switches between lightTheme / darkTheme
// based on useColorScheme() — no component-level color branching needed.
```

```tsx
// ✅ Option B: themed StyleSheet via useColorScheme + typed theme variants
import { useColorScheme } from 'react-native';
import { lightTheme, darkTheme } from '../theme';

function useThemeColors() {
  const scheme = useColorScheme();
  return scheme === 'dark' ? darkTheme.colors : lightTheme.colors;
}

// Inside component:
const colors = useThemeColors();
const styles = StyleSheet.create({
  screen: { backgroundColor: colors.background },   // semantic — adapts
  text:   { color: colors.onSurface },
});
```

---

## Rule 8 — Duplicated icon / asset

**Bad** — raw SVG path or duplicate asset file:

```tsx
// ❌ Inline SVG path data — duplicated, brittle, not accessible by default
import Svg, { Path } from 'react-native-svg';

function CloseButton({ onPress }: { onPress: () => void }) {
  return (
    <TouchableOpacity onPress={onPress}>
      <Svg width={24} height={24} viewBox="0 0 24 24">
        <Path d="M18 6L6 18M6 6l12 12" stroke="#000" strokeWidth={2} />
      </Svg>
    </TouchableOpacity>
  );
}
```

**Good** — icon-set component from the project's icon library:

```tsx
// ✅ Design-system icon component — size/color tokenized, a11y handled inside
import { Icon } from '../components/Icon';

function CloseButton({ onPress }: { onPress: () => void }) {
  return (
    <TouchableOpacity onPress={onPress} accessibilityLabel="Close" accessibilityRole="button">
      <Icon name="close" size={theme.iconSize.md} color={theme.colors.onSurface} />
    </TouchableOpacity>
  );
}
```

If the icon set genuinely doesn't have the needed icon, add it to the icon library once —
don't inline SVG paths in consumer components.

---

## Rule 9 — Ad-hoc radius / elevation / shadow

**Bad** — one-off shadow and radius per component:

```tsx
// ❌ Hand-rolled shadow + magic radius — 6 slightly different shadows across the app
const styles = StyleSheet.create({
  card: {
    borderRadius: 7,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
  },
});
```

**Good** — radius and shadow tokens from the theme:

```tsx
// ✅ Theme tokens — surfaces look consistent; one place to tune
import { theme } from '../theme';

const styles = StyleSheet.create({
  card: {
    borderRadius: theme.radius.md,      // 8
    ...theme.shadow.card,               // { elevation:4, shadowColor:'#000', shadowOffset:{width:0,height:2},
                                        //   shadowOpacity:0.12, shadowRadius:4 }
  },
});
```

Define `theme.shadow.card` once in the theme, reference everywhere. Cross-platform note:
`elevation` is Android-only; `shadow*` props are iOS-only — define both in the token.

---

## Rule 10 — Primitive instead of semantic token

**Bad** — palette primitive referenced directly in a component:

```tsx
// ❌ Palette primitive in component code — white-label theming silently breaks
import { COLORS } from '../tokens/colors';  // { blue500: '#3B82F6', gray200: '#E5E7EB', ... }

const styles = StyleSheet.create({
  button: { backgroundColor: COLORS.blue500 },   // primitive — not remappable
  border: { borderColor: COLORS.gray200 },
});
```

**Good** — semantic token resolves the primitive for you:

```tsx
// ✅ Semantic token — re-theming changes `primary` once in the theme; every consumer updates
import { theme } from '../theme';

// In theme/index.ts (token definition — the ONE place primitives appear):
// colors: { primary: COLORS.blue500, border: COLORS.gray200, ... }

const styles = StyleSheet.create({
  button: { backgroundColor: theme.colors.primary },
  border: { borderColor: theme.colors.border },
});
```

With restyle, the primitive → semantic mapping lives entirely in `createTheme` and never
leaks into component code:

```tsx
// theme/index.ts
import { createTheme } from '@shopify/restyle';
const palette = { blue500: '#3B82F6', gray200: '#E5E7EB' };
export const theme = createTheme({
  colors: {
    primary: palette.blue500,   // semantic ← primitive
    border:  palette.gray200,
  },
  // ...
});

// Component — only sees semantic names
<Box backgroundColor="primary" borderColor="border" />
```

---

## Mode-A worked examples

### Example A — mapping a new screen to existing tokens + components

Scenario: a new `OrderSummary` screen arrives from [rn-figma-to-code](../rn-figma-to-code/SKILL.md)
with `manifest.json` tokens `color.brand.primary`, `space.md`, `radius.lg`.

**Step 1 — locate the theme:**

```bash
find . -path "*/theme*" -name "*.ts" | head -5
# → src/theme/index.ts
```

**Step 2 — read the token shape:**

```ts
// src/theme/index.ts (excerpt)
export const theme = {
  colors: { primary: '#3B82F6', surface: '#fff', onSurface: '#1A1A1A' },
  space:  { xs: 4, sm: 8, md: 16, lg: 24 },
  radius: { sm: 4, md: 8, lg: 12 },
  text:   { titleM: { fontSize: 18, fontWeight: '600', lineHeight: 24 } },
} as const;
```

**Step 3 — find existing components:**

```bash
grep -r "export.*function\|export.*const" src/components/ | grep -E "Button|Card|Badge"
# → src/components/Card.tsx: export function Card({ ... })
# → src/components/Button.tsx: export function Button({ ... })
```

**Step 4 — write the screen using only what was found:**

```tsx
import { View, Text, StyleSheet } from 'react-native';
import { theme } from '../theme';
import { Card } from '../components/Card';
import { Button } from '../components/Button';

export function OrderSummary({ orderId, onConfirm }: { orderId: string; onConfirm: () => void }) {
  return (
    <View style={styles.screen}>
      <Card>
        <Text style={styles.title} accessibilityRole="header">Order #{orderId}</Text>
      </Card>
      <Button label="Confirm" variant="primary" onPress={onConfirm} />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: theme.space.md, gap: theme.space.sm },
  title:  { ...theme.text.titleM, color: theme.colors.onSurface },
});
```

Zero raw literals. The whole screen passes the guard.

---

### Example B — adding ONE new token instead of inlining

Scenario: the design calls for a warning-tinted background (`#FFF3CD`) that no existing
token covers.

**Wrong — inline the one-off:**

```tsx
// ❌ Inline → five files end up with slightly different yellows within a month
backgroundColor: '#FFF3CD'
```

**Right — extend the theme once:**

```ts
// src/theme/index.ts — ONE addition
export const theme = {
  colors: {
    // ... existing tokens ...
    warningSubtle: '#FFF3CD',   // new semantic token, reviewed here
  },
} as const;
```

```tsx
// Every consumer references the token
backgroundColor: theme.colors.warningSubtle
```

The hex appears exactly once (the theme definition). Re-theming, dark-mode variants, and
design changes all touch one line.

---

## References

- Rule definitions and checklist: [SKILL.md](./SKILL.md)
- Generation counterpart (produces code this skill guards): [rn-figma-to-code](../rn-figma-to-code/SKILL.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md)
- `@shopify/restyle` API: https://github.com/Shopify/restyle
- React Native StyleSheet: https://reactnative.dev/docs/stylesheet
- useColorScheme: https://reactnative.dev/docs/usecolorscheme

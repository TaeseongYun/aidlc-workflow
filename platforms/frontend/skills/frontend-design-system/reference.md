# frontend-design-system — reference

Bad→good TSX pairs for all 10 guard rules, plus Mode A worked examples (locating tokens +
mapping a screen). Companion to [SKILL.md](./SKILL.md). Generation counterpart:
[frontend-figma-to-code](../frontend-figma-to-code/SKILL.md).

---

## Mode A — Reuse: worked examples

### A-1. Find the token source before writing any component

```bash
# Locate the DTCG token file (output of frontend-figma-to-code extractor)
find . -name "tokens.json" -o -name "*.tokens.json" | head -20
ls src/design-tokens/ 2>/dev/null || ls src/theme/ 2>/dev/null

# Inspect available semantic color tokens
grep -E '"color\.' tokens.json | head -30

# Confirm Tailwind is wired to the tokens (look for cssVariables / custom properties)
grep -A5 'colors' tailwind.config.ts | head -30
```

Once you see what tokens exist (e.g. `--color-primary`, `--color-background`,
`--color-foreground`, `--color-border`, `--color-card`), use those names in every component.
Never resolve them to their hex values.

### A-2. Map a new screen to existing tokens + components

Design brief: "Profile card — avatar, name, subtitle, a follow button."

**Step 1 — find the component library.**
```bash
grep -E 'shadcn|@radix-ui|@mui/material' package.json
ls src/components/ui/   # shadcn-generated components
```
Found: `Button`, `Avatar`, `Card`, `CardContent`, `CardHeader`.

**Step 2 — map to existing pieces (do NOT build from scratch).**

```tsx
// ponytail: all primitives come from the installed library; no new components needed
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";

export function ProfileCard({ name, subtitle, avatarSrc }: ProfileCardProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center gap-4">
        <Avatar>
          <AvatarImage src={avatarSrc} alt={name} />
          <AvatarFallback>{name[0]}</AvatarFallback>
        </Avatar>
        <div>
          <p className="text-sm font-semibold text-foreground">{name}</p>
          <p className="text-xs text-muted-foreground">{subtitle}</p>
        </div>
      </CardHeader>
      <CardContent>
        <Button variant="outline" size="sm" className="w-full">
          Follow
        </Button>
      </CardContent>
    </Card>
  );
}
```

All colors (`text-foreground`, `text-muted-foreground`), spacing (`gap-4`), and typography
(`text-sm`, `text-xs`, `font-semibold`) come from the theme. No new component built.

### A-3. Adding ONE token instead of inlining

Design brief: "Use the new 'success' green (#22C55E) for a status badge."

`#22C55E` does not exist as a semantic token yet. Correct flow:

```jsonc
// tokens.json — add ONE entry
{
  "color": {
    "success": { "$type": "color", "$value": "#22C55E" }
  }
}
```

```ts
// tailwind.config.ts — wire it
colors: {
  success: "var(--color-success)",
}
```

```css
/* globals.css — CSS variable definition */
:root { --color-success: #22C55E; }
.dark { --color-success: #16a34a; } /* adjusted for dark mode */
```

```tsx
// component — reference the semantic token, never the hex
<Badge className="bg-success text-white">Active</Badge>
```

The hex appears exactly once (in the token definition). Every component that needs "success"
references `bg-success` and picks up the dark-mode adjustment automatically.

---

## Rule 1 — Hardcoded color

**Bad** — hex pasted directly from Figma inspect:
```tsx
// AI output from figma-to-code: color extracted as raw hex
function PrimaryButton({ children }: { children: React.ReactNode }) {
  return (
    <button
      style={{ backgroundColor: "#3B82F6", color: "#FFFFFF" }}
      className="rounded px-4 py-2"
    >
      {children}
    </button>
  );
}
```

**Good** — semantic token via Tailwind utility:
```tsx
// Uses semantic tokens; survives re-theme and dark mode
import { Button } from "@/components/ui/button";

function PrimaryButton({ children }: { children: React.ReactNode }) {
  return <Button variant="default">{children}</Button>;
}
```

If a raw `<button>` is truly needed (no library available):
```tsx
<button className="rounded bg-primary px-4 py-2 text-primary-foreground">
  {children}
</button>
```

---

## Rule 2 — Magic spacing / size

**Bad** — Figma geometry copied as raw pixels:
```tsx
function HeroSection() {
  return (
    <section style={{ padding: "48px 32px", gap: "13px" }}>
      <h1 style={{ marginBottom: "20px" }}>Hello</h1>
      <p className="p-[13px]">Subtitle text</p>
    </section>
  );
}
```

**Good** — Tailwind spacing utilities from the scale:
```tsx
function HeroSection() {
  return (
    <section className="flex flex-col gap-3 px-8 py-12">
      <h1 className="mb-5 text-4xl font-bold">Hello</h1>
      <p className="p-3">Subtitle text</p>
    </section>
  );
}
// ponytail: gap-3=12px, p-3=12px, py-12=48px, px-8=32px — Tailwind scale steps, not literals
```

If a spacing value is genuinely off the Tailwind default scale, add it to
`tailwind.config.ts → theme.extend.spacing` rather than using an arbitrary value.

---

## Rule 3 — Ad-hoc typography

**Bad** — per-component font overrides:
```tsx
function ArticleTitle({ title }: { title: string }) {
  return (
    <h1
      style={{
        fontSize: "28px",
        fontWeight: 700,
        lineHeight: 1.3,
        fontFamily: "Inter, sans-serif",
      }}
    >
      {title}
    </h1>
  );
}
```

**Good** — type-scale utilities from the token/theme:
```tsx
// text-3xl, font-bold, leading-tight all map to DTCG typography tokens
function ArticleTitle({ title }: { title: string }) {
  return <h1 className="text-3xl font-bold leading-tight">{title}</h1>;
}
```

For a project-specific type ramp defined in `tailwind.config.ts`:
```tsx
// e.g. theme.extend.fontSize.display = ['3rem', { lineHeight: '1.1', fontWeight: '700' }]
<h1 className="text-display">{title}</h1>
```

---

## Rule 4 — Reinvented component

**Bad** — hand-rolled button that duplicates the library:
```tsx
// AI builds from scratch when <Button> already exists in src/components/ui/button.tsx
function SubmitButton({ label }: { label: string }) {
  return (
    <button
      className="rounded-md bg-blue-600 px-6 py-2.5 text-sm font-semibold text-white
                 shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2
                 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
    >
      {label}
    </button>
  );
}
```

**Good** — use the existing component:
```tsx
import { Button } from "@/components/ui/button";

function SubmitButton({ label }: { label: string }) {
  return <Button type="submit">{label}</Button>;
}
```

Same pattern for cards, modals, inputs, badges, dialogs — search `src/components/ui/` and the
installed library FIRST, build only if truly absent.

---

## Rule 5 — Off-scale variant

**Bad** — near-duplicate of a token, not the token:
```tsx
// Brand primary is #3B82F6 in tokens.json; AI uses #3B83F7 (one digit off)
// Or radius token maps to rounded-md (6px); AI uses rounded-[7px]
function Tag() {
  return (
    <span
      style={{ backgroundColor: "#3B83F7", borderRadius: "7px" }}
      className="px-2 py-0.5 text-xs text-white"
    >
      New
    </span>
  );
}
```

**Good** — exact token, every time:
```tsx
// bg-primary resolves to var(--color-primary) = #3B82F6; rounded-md = 6px from the token
function Tag() {
  return (
    <span className="rounded-md bg-primary px-2 py-0.5 text-xs text-primary-foreground">
      New
    </span>
  );
}
```

When auditing AI output, grep for hex values and diff against `tokens.json` to catch
single-digit drift before it accumulates across the codebase.

---

## Rule 6 — Inline style bypassing theme

**Bad** — style prop with literal values where variant/size API exists:
```tsx
function StatusChip({ label }: { label: string }) {
  return (
    <span
      style={{
        color: "#fff",
        backgroundColor: "#1d4ed8",
        padding: "4px 12px",
        borderRadius: "9999px",
        fontSize: "12px",
        fontWeight: 600,
      }}
    >
      {label}
    </span>
  );
}
```

**Good** — component variant API + semantic utilities:
```tsx
import { Badge } from "@/components/ui/badge";

// Badge already ships variant="default" with primary bg + foreground color
function StatusChip({ label }: { label: string }) {
  return <Badge variant="default">{label}</Badge>;
}
```

For a genuinely dynamic style (e.g. a user-supplied brand color), bind it to a CSS variable:
```tsx
// ponytail: CSS variable binding, not a literal — the variable is then used in the className
<div style={{ "--card-accent": userColor } as React.CSSProperties}
     className="border-l-4 border-[color:var(--card-accent)]">
```

---

## Rule 7 — Dark-mode / theme break

**Bad** — hardcoded light/dark pair that breaks any custom theme:
```tsx
function Sidebar() {
  return (
    <aside className="bg-white text-gray-900 dark:bg-gray-900 dark:text-white">
      {/* content */}
    </aside>
  );
}
```

**Good** — semantic tokens that resolve for any theme:
```tsx
// bg-background and text-foreground are CSS vars: --background / --foreground
// They are defined in globals.css for :root (light) and .dark (dark), and for any custom theme
function Sidebar() {
  return (
    <aside className="bg-background text-foreground">
      {/* content */}
    </aside>
  );
}
```

Semantic utility reference (shadcn/ui convention):

| Purpose | Semantic utility | Avoid |
|---|---|---|
| Page background | `bg-background` | `bg-white` / `bg-gray-950` |
| Primary text | `text-foreground` | `text-gray-900` / `text-white` |
| Secondary text | `text-muted-foreground` | `text-gray-500` |
| Card surface | `bg-card` | `bg-white` / `bg-zinc-800` |
| Border | `border-border` | `border-gray-200` |
| Primary action | `bg-primary text-primary-foreground` | `bg-blue-500 text-white` |

---

## Rule 8 — Duplicated icon / asset

**Bad** — inline SVG path for an icon the library already ships:
```tsx
// lucide-react ships <ChevronRight /> — no need to paste the path data
function AccordionToggle() {
  return (
    <button>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
        <path d="M9 18l6-6-6-6" stroke="currentColor" strokeWidth="2"
              strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </button>
  );
}
```

**Good** — icon component from the installed library:
```tsx
import { ChevronRight } from "lucide-react";

function AccordionToggle() {
  return (
    <button aria-label="Expand">
      <ChevronRight className="h-4 w-4" aria-hidden="true" />
    </button>
  );
}
```

Before adding any SVG file or inline path, run:
```bash
# Check lucide-react (most common)
node -e "const l = require('lucide-react'); console.log(Object.keys(l).filter(k => /close|x|chevron|arrow/i.test(k)))"
# Or search the icon set docs: https://lucide.dev/icons/
```

---

## Rule 9 — Ad-hoc radius / elevation / shadow

**Bad** — one-off values not from the token scale:
```tsx
function Popover({ children }: { children: React.ReactNode }) {
  return (
    <div
      style={{
        borderRadius: "7px",
        boxShadow: "0 4px 12px rgba(0, 0, 0, 0.15)",
        zIndex: 50,
      }}
      className="bg-white p-3"
    >
      {children}
    </div>
  );
}
```

**Good** — Tailwind utilities backed by the design-token scale:
```tsx
// rounded-md = 6px (token), shadow-md = token shadow, z-50 = token z-index
function Popover({ children }: { children: React.ReactNode }) {
  return (
    <div className="z-50 rounded-md bg-popover p-3 shadow-md">
      {children}
    </div>
  );
}
```

Radius/shadow token reference (Tailwind defaults, extend in `tailwind.config.ts` as needed):

| Token | Tailwind utility | Approx value |
|---|---|---|
| radius-sm | `rounded-sm` | 2px |
| radius-md | `rounded-md` | 6px |
| radius-lg | `rounded-lg` | 8px |
| radius-xl | `rounded-xl` | 12px |
| radius-full | `rounded-full` | 9999px |
| shadow-sm | `shadow-sm` | subtle |
| shadow-md | `shadow-md` | card-level |
| shadow-lg | `shadow-lg` | popover/modal |

---

## Rule 10 — Primitive instead of semantic token

**Bad** — palette primitive in component code:
```tsx
// bg-blue-500 is a palette primitive: it breaks when brand color changes
function PrimaryAction({ label }: { label: string }) {
  return (
    <button className="rounded bg-blue-500 px-4 py-2 font-semibold text-white hover:bg-blue-600">
      {label}
    </button>
  );
}
```

**Good** — semantic token that re-themes automatically:
```tsx
// bg-primary resolves to var(--color-primary); text-primary-foreground is its contrast pair.
// Change --color-primary in globals.css and every component updates with zero code changes.
function PrimaryAction({ label }: { label: string }) {
  return (
    <button className="rounded bg-primary px-4 py-2 font-semibold text-primary-foreground hover:bg-primary/90">
      {label}
    </button>
  );
}
```

Where primitives belong vs. where they don't:

```css
/* globals.css — ONLY place primitives are allowed: wiring them to semantic vars */
:root {
  --color-primary: theme("colors.blue.500");   /* primitive lives here */
  --color-primary-foreground: theme("colors.white");
}
.dark {
  --color-primary: theme("colors.blue.400");   /* dark variant here too */
}
```

```tsx
/* Component code — semantic only */
<div className="bg-primary text-primary-foreground" />    /* correct */
<div className="bg-blue-500 text-white" />                 /* wrong — primitive */
```

For MUI projects, the same rule applies to `theme.palette`:
```tsx
// Bad
sx={{ backgroundColor: theme.palette.blue[500] }}
// Good
sx={{ backgroundColor: "primary.main" }}
```

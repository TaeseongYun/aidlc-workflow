# frontend-accessibility — Reference

Deep-dive for `SKILL.md`. Semantic controls, focus management, ARIA patterns,
role-based testing. Decision criteria live in `SKILL.md`.

## 1. Real controls, not div-onClick

```tsx
// ❌ Not keyboard-operable, no role, no focus
<div onClick={onSave} className="btn">Save</div>

// ✅ Native button — keyboard + focus + role for free
<button type="button" onClick={onSave}>Save</button>

// ✅ Navigation is a link, not a button with router.push
<Link href={`/orders/${id}`}>View order</Link>
```

## 2. Labels and accessible names

```tsx
// ✅ Visible label tied to the control
<label htmlFor="email">Email</label>
<input id="email" type="email" name="email" />

// ✅ Icon-only button needs a name
<button type="button" aria-label="Close"><CloseIcon aria-hidden="true" /></button>

// ✅ Images: meaningful alt, or empty alt for decorative
<img src={avatar} alt={`${user.name} avatar`} />
<img src={divider} alt="" />
```

## 3. Focus management (dialogs, route changes)

```tsx
// Native <dialog> handles most of this; if hand-rolling, move → trap → restore focus.
function Modal({ open, onClose, children }: ModalProps) {
  const ref = useRef<HTMLDivElement>(null);     // container needs tabIndex={-1} to be focusable
  const prevFocus = useRef<HTMLElement | null>(null);
  useEffect(() => {
    if (!open) return;
    prevFocus.current = document.activeElement as HTMLElement;
    ref.current?.focus();                       // move focus in (container has tabIndex={-1})
    return () => prevFocus.current?.focus();     // restore on close
  }, [open]);
  // trap Tab within the dialog; Esc closes → onClose
}
```

- On client-side route change, move focus to the page `<h1>`/main region so
  screen-reader users land in the new content.

## 4. Platform over library

```tsx
// ❌ JS date-picker dependency for a plain date
<DatePicker value={d} onChange={setD} />
// ✅ Native input — accessible, zero-bundle
<input type="date" value={d} onChange={e => setD(e.target.value)} />

// ❌ JS accordion lib   →   ✅ <details><summary>Title</summary>…</details>
```

## 5. Status signals (not color alone)

```tsx
// ✅ Error uses text + icon + aria, not just red
<p role="alert"><ErrorIcon aria-hidden="true" /> Email is required.</p>
// async status announced politely
<div aria-live="polite">{isSaving ? 'Saving…' : saved ? 'Saved' : ''}</div>
```

## 6. Test by role/label (behavior, not implementation)

```tsx
// Aligns with the guidance test convention: query by role/label, not internals
const btn = screen.getByRole('button', { name: /save/i });
const email = screen.getByLabelText(/email/i);
```

## 7. A11y review checklist

- [ ] Every clickable is a `<button>`; every navigation is an `<a>`/`<Link>`.
- [ ] All inputs have associated labels; icon buttons have accessible names.
- [ ] All images have `alt` (empty for decorative).
- [ ] Dialogs move/trap/restore focus; route changes reset focus.
- [ ] Everything operable by keyboard; visible `:focus-visible` styles.
- [ ] Color paired with text/icon; contrast meets WCAG AA.
- [ ] Native element + CSS chosen over a JS library where possible.

## Official references

- WCAG 2.2 quick reference: https://www.w3.org/WAI/WCAG22/quickref/
- ARIA Authoring Practices: https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN accessibility: https://developer.mozilla.org/docs/Web/Accessibility
- Testing Library — guiding principles (query by role): https://testing-library.com/docs/queries/about/#priority
- Team baseline: [../../guidance.md](../../guidance.md)

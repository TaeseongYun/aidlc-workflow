---
name: flutter-widget-performance
description: Flutter widget performance and correctness rules (build/rebuild hygiene, async-gap safety, theme literals). const constructors wherever possible, rebuild scope kept tight (Riverpod select / Bloc buildWhen), no BuildContext used after an await without a mounted check, no business logic in build()/initState(), no expensive work in build(), strings/colors/dimensions come from the theme and localization (no literals in feature widgets), and optimization driven by evidence (DevTools) not speculation. Use when writing/reviewing/refactoring screens, pages, views, or widgets, and when a rebuild/jank/async-context issue is suspected.
when_to_use: When writing/reviewing widget build methods, tightening rebuild scope, fixing jank, guarding context across async gaps, or removing literals in favor of theme/localization. Also for "widget rebuilds too much", "const", "mounted after await", "no strings in widgets".
paths: **/*_screen.dart, **/*_page.dart, **/*_view.dart, **/widgets/**/*.dart, **/presentation/**/*.dart
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-widget-performance

Rules for widget build hygiene, rebuild scope, and async-gap safety. The Rules
items from `guidance.md` expanded to an enforceable level. Project `ctx/`
overrides this document. Deeper material (const/select/buildWhen samples,
DevTools workflow) lives in [reference.md](./reference.md).

## Scope

- In scope: widget `build`, rebuild scope, `const` usage, `mounted`/async-gap
  safety, theme/localization sourcing.
- Covers: keeping builds cheap and correct, tight rebuilds, no context-after-await.
- Doesn't cover: state modeling, module layout, navigation, security — follow the
  Related skills in [flutter-architecture].

## Core rules

Do:

- **`const` wherever possible.** Const widgets skip rebuilds and are canonicalized.
  Prefer `const` constructors for leaf/static widgets.
- **Keep rebuild scope tight.** Watch only the slice you render: Riverpod
  `ref.watch(p.select((s) => s.field))`, Bloc `BlocBuilder(buildWhen: ...)`.
  Split large widgets so a small change rebuilds a small subtree.
- **`build` is pure and cheap.** No I/O, no controller creation, no allocation of
  expensive objects, no business logic. Build reads state and returns widgets.
- **No `BuildContext` after an `await` without a `mounted` check** (capture
  context-derived objects before the gap, or guard with `if (!context.mounted)
  return;`) → [flutter-state-management].
- **Source strings/colors/dimensions from theme + localization.** Feature widgets
  use `Theme.of(context)` tokens and the l10n setup — no hardcoded literals.
- **Optimize on evidence.** Profile with DevTools first; don't add `const`
  churn / `RepaintBoundary` / keys speculatively.

Don't:

- Business rules or data fetching in `build()` / `initState()`.
- Allocate controllers, run loops, or do I/O inside `build`.
- Watch the whole state object when you render one field (over-rebuild).
- Use `BuildContext` across an async gap without `mounted`.
- Hardcode user-facing strings, hex colors, or magic dimensions in feature widgets.
- Add `RepaintBoundary`/keys/micro-opts without a measured problem.

## Decision table

| Symptom | Fix |
|---|---|
| Static subtree rebuilding | make it `const` / hoist above the rebuilding scope |
| Whole screen rebuilds on one field change | `select` / `buildWhen` to that field; split the widget |
| Jank in a scroll/list | lazy `ListView.builder`, `const` items, profile with DevTools |
| `context` used after `await` | capture before the gap or `if (!context.mounted) return;` |
| Literal string/color/size in a widget | theme token + localization |
| "Might be slow" hunch | measure in DevTools **before** optimizing |

## Refactor / red-flag signals

- Non-`const` leaf widgets that never change.
- `ref.watch(provider)` (whole object) where one field is rendered.
- `BlocBuilder` with no `buildWhen` rebuilding on unrelated changes.
- Data fetch / business logic in `build()` or `initState()`.
- `BuildContext` after `await` with no `mounted` guard.
- Hardcoded strings/colors/dimensions in feature widgets.
- Speculative `RepaintBoundary`/keys added without profiling.

## References

- Performance best practices: https://docs.flutter.dev/perf/best-practices
- Performance & DevTools: https://docs.flutter.dev/tools/devtools/performance
- `use_build_context_synchronously` lint: https://dart.dev/tools/linter-rules/use_build_context_synchronously
- Internationalization: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- Team baseline: [`../../guidance.md`](../../guidance.md)
- const/select/buildWhen samples, DevTools workflow: [`reference.md`](reference.md)

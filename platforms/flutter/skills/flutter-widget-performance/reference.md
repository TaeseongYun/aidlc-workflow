# flutter-widget-performance — Reference

Deep-dive for `SKILL.md`. `const`/`select`/`buildWhen` samples, async-gap
safety, DevTools workflow. Decision criteria live in `SKILL.md`.

## 1. `const` and tight rebuild scope

```dart
// ❌ Whole screen rebuilds when only the counter changes
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider); // watches everything
    return Column(children: [
      const HeaderBar(),                              // rebuilds too (no const before)
      Text('${state.counter}'),
    ]);
  }
}

// ✅ const for the static part, select for the field actually rendered
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(homeControllerProvider.select((s) => s.counter));
    return Column(children: [
      const HeaderBar(),        // const → not rebuilt
      Text('$counter'),
    ]);
  }
}
```

```dart
// Bloc equivalent: buildWhen scopes the rebuild
BlocBuilder<HomeBloc, HomeState>(
  buildWhen: (prev, curr) => prev.counter != curr.counter,
  builder: (context, s) => Text('${s.counter}'),
);
```

## 2. `build` stays pure and cheap

```dart
// ❌ Side effects / allocation in build
@override
Widget build(BuildContext context) {
  final repo = MyRepository();      // new instance every rebuild
  repo.fetch();                     // I/O in build!
  return /* ... */;
}

// ✅ Work in the controller / initState-once; build only reads state
// fetch triggered by the controller's build()/an action → flutter-state-management
```

## 3. Async gap safety (mounted)

```dart
// ❌ context after await, no guard
onPressed: () async {
  await ref.read(cartProvider.notifier).checkout();
  Navigator.of(context).push(/* ... */);  // context may be defunct
}

// ✅ capture before, or guard after
onPressed: () async {
  final router = GoRouter.of(context);      // capture before the gap
  await ref.read(cartProvider.notifier).checkout();
  if (!context.mounted) return;             // guard after
  router.go('/done');
}
```

- The `use_build_context_synchronously` lint catches these — keep it on.

## 4. Theme + localization, no literals

```dart
// ❌ literals in a feature widget
Text('Checkout', style: TextStyle(fontSize: 18, color: Color(0xFF1A1A1A)));
Padding(padding: EdgeInsets.all(16));

// ✅ theme tokens + generated l10n
Text(AppLocalizations.of(context)!.checkout, style: Theme.of(context).textTheme.titleMedium);
Padding(padding: EdgeInsets.all(context.spacing.md));  // spacing from a theme extension
```

## 5. Optimize on evidence (DevTools)

1. Reproduce the jank in **profile mode** (`flutter run --profile`), not debug.
2. Open DevTools → Performance; record the interaction.
3. Find the expensive frames / rebuilt widgets (the rebuild counter, timeline).
4. Fix the measured cause (`const`, `select`/`buildWhen`, `ListView.builder`,
   a targeted `RepaintBoundary`).
5. Re-measure. Don't ship speculative micro-opts.

## 6. Widget review checklist

- [ ] Static/leaf widgets are `const`.
- [ ] Rebuild scoped to the rendered slice (`select` / `buildWhen`); big widgets split.
- [ ] `build` does no I/O, allocation, or business logic.
- [ ] No `BuildContext` after `await` without `mounted`.
- [ ] Strings/colors/dimensions from theme + localization, not literals.
- [ ] Any perf change backed by a DevTools measurement.

## Official references

- Performance best practices: https://docs.flutter.dev/perf/best-practices
- DevTools performance view: https://docs.flutter.dev/tools/devtools/performance
- Impeller / rendering perf: https://docs.flutter.dev/perf/rendering-performance
- `use_build_context_synchronously`: https://dart.dev/tools/linter-rules/use_build_context_synchronously
- Internationalization: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- Team baseline: [../../guidance.md](../../guidance.md)

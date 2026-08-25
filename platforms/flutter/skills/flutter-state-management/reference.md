# flutter-state-management — Reference

Deep-dive for `SKILL.md`. Sealed/`freezed` state, effect streams, Riverpod↔Bloc
mapping. Decision criteria live in `SKILL.md`.

## 1. Model illegal states unrepresentable

```dart
// ❌ Parallel nullables — allows isLoading && error && data all at once
class HomeState {
  final bool isLoading;
  final List<Item>? data;
  final String? error;
}

// ✅ Sealed hierarchy — exactly one case is possible
sealed class HomeState {}
class HomeLoading extends HomeState {}
class HomeError extends HomeState { final Failure failure; HomeError(this.failure); }
class HomeLoaded extends HomeState { final List<Item> items; HomeLoaded(this.items); }
```

- With Riverpod, `AsyncValue<List<Item>>` already encodes loading/data/error —
  prefer it over a hand-rolled sealed type for pure async fetches.

## 2. Riverpod controller — state + effect

```dart
// State via AsyncNotifier; effect via a separate signal the widget listens to.
class HomeController extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() => ref.read(repoProvider).load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(repoProvider).load());
  }
}

// One-shot effect: expose a signal, the widget reacts with ref.listen (not stored in state)
final homeEffectProvider = StreamProvider<HomeEffect>((ref) => /* ... */);

// In the widget:
ref.listen(homeEffectProvider, (_, next) {
  next.whenData((e) => switch (e) {
    ShowSnack(:final msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))),
    GoDetail(:final id)   => context.go('/detail/$id'),
  });
});
```

## 3. Bloc — state + effect equivalent

```dart
// Bloc emits state; one-shot effects surface via BlocListener (not persisted in state).
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._repo) : super(HomeLoading()) {
    on<Load>((e, emit) async {
      emit(HomeLoading());
      final r = await _repo.load();
      emit(r.fold((f) => HomeError(f), (items) => HomeLoaded(items)));
    });
  }
}

// Widget: BlocListener for effects, BlocBuilder(buildWhen: ...) for render → flutter-widget-performance
BlocListener<HomeBloc, HomeState>(
  listenWhen: (p, c) => c is HomeError,
  listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(/* ... */),
  child: BlocBuilder<HomeBloc, HomeState>(builder: (context, s) => /* render */),
)
```

## 4. Async gap safety (mounted)

```dart
// ❌ context used after await without a mounted check
Future<void> onSave() async {
  await controller.save();
  Navigator.of(context).pop();          // context may be defunct
}

// ✅ Capture before, or guard with mounted
Future<void> onSave() async {
  final nav = Navigator.of(context);    // capture before the gap
  await controller.save();
  if (!context.mounted) return;         // or guard after
  nav.pop();
}
```

## 5. Riverpod ↔ Bloc mapping (pick one, never both)

| Concept | Riverpod | Bloc |
|--------|----------|------|
| Screen state holder | `Notifier` / `AsyncNotifier` | `Bloc` / `Cubit` |
| Emit new state | `state = ...` | `emit(...)` |
| Async loading/error | `AsyncValue` / `AsyncValue.guard` | sealed state + try/catch |
| Render subset only | `ref.watch(p.select(...))` | `BlocBuilder(buildWhen: ...)` |
| One-shot effect | `ref.listen(signalProvider)` | `BlocListener` |
| Scope | provider scope / `ProviderScope` override | `BlocProvider` at the right subtree |

## 6. State review checklist

- [ ] One immutable/sealed state type per screen.
- [ ] loading/content/error modeled explicitly (sealed / `AsyncValue`), no parallel nullables.
- [ ] One-shot effects via listener stream, not stored in state.
- [ ] Controller imports no Flutter UI types, holds no `BuildContext`.
- [ ] Repository failures mapped to typed state; no raw exceptions to widgets.
- [ ] `mounted` checked after every `await` that precedes `context` use.
- [ ] Exactly one state library in the project.

## Official references

- State management options: https://docs.flutter.dev/data-and-backend/state-mgmt/options
- Riverpod side effects: https://riverpod.dev/docs/essentials/side_effects
- Bloc concepts: https://bloclibrary.dev/bloc-concepts/
- `BuildContext` across async gaps (`use_build_context_synchronously`): https://dart.dev/tools/linter-rules/use_build_context_synchronously
- Team baseline: [../../guidance.md](../../guidance.md)

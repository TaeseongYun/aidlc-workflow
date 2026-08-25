# flutter-module-structure — Reference

Deep-dive for `SKILL.md`. Folder trees, DI scoping, melos split timing. Decision
criteria live in `SKILL.md`.

## 1. Feature-first tree (grow layers on demand)

```
lib/
  core/
    theme/          # tokens, ThemeData, text styles
    widgets/        # shared, reusable widgets
    router/         # go_router config → flutter-navigation-platform
    utils/
  domain/           # SHARED domain models — no package:flutter imports
  data/             # shared API clients, repositories, DTOs
  features/
    home/
      presentation/ # screens, widgets, controllers/blocs
      # domain/  — omitted: this feature has no use cases yet
      data/         # home-specific repository/source
    checkout/
      presentation/
      domain/       # checkout use cases (exist → folder exists)
      data/
```

- A layer folder appears **only when it has a file**. Empty `domain/`/`data/`
  scaffolding is over-engineering — add it when the first file lands.

## 2. DI / provider scoping

```dart
// ✅ App-wide singletons at app scope (config, HTTP client, auth)
final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(/* ... */)));
final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

// ✅ Feature state scoped to the feature subtree — not global
// (Riverpod: override at the feature route; Bloc: BlocProvider on the route)
GoRoute(
  path: '/checkout',
  builder: (_, __) => BlocProvider(
    create: (_) => CheckoutBloc(context.read()),  // lives with the route, disposed on exit
    child: const CheckoutScreen(),
  ),
);
```

- Global everything → memory held for the app's life + hidden coupling. Scope
  feature state to where it's used.

## 3. Cross-feature dependencies

```
✅ features/checkout → core/widgets, domain/Money      (downward, via shared layers)
❌ features/checkout → features/home/presentation/...   (feature→feature internals)
```

- When two features need the same thing, lift it into `core` (has UI) or
  `domain` (pure). Don't reach into another feature's folders.

## 4. When to split into packages (melos)

Single package until a **real** second consumer:

| Trigger | Action |
|--------|--------|
| One app, growing feature count | stay single-package, feature-first folders |
| A second app (e.g. companion/admin) shares code | extract shared code to a package |
| Publishing a Flutter plugin / platform-channel package | separate plugin package |
| Independent build/test/versioning genuinely needed | melos workspace |

```yaml
# melos.yaml — only once a second consumer exists
name: my_workspace
packages:
  - apps/**
  - packages/**
```

- Do not start with melos "to be scalable". The split has real cost (wiring,
  path deps, CI) and pays off only with a second consumer.

## 5. Structure review checklist

- [ ] Layer folders exist only where they hold files (no empty scaffolding).
- [ ] `domain/` imports no `package:flutter/*`.
- [ ] App-wide clients/config/auth at app scope; feature state scoped to its subtree.
- [ ] No feature→feature internal imports; shared code lives in `core`/`domain`.
- [ ] Single package unless a second app/plugin consumer exists.

## Official references

- Flutter architecture case study: https://docs.flutter.dev/app-architecture/case-study
- Dart package layout: https://dart.dev/tools/pub/package-layout
- melos: https://melos.invertase.dev/
- Team baseline: [../../guidance.md](../../guidance.md)

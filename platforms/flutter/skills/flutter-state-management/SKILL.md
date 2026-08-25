---
name: flutter-state-management
description: Flutter state-management rules (controller/notifier/bloc state modeling). Controller owns screen state as a single immutable/sealed type, one-shot effects (snackbar/navigation) separated into an event/listener stream (not persisted in state), loading/content/error modeled explicitly (not parallel nullables), unidirectional data flow (widget renders state and raises actions), controller holds no BuildContext or Flutter UI types, async gaps guarded with a mounted check, repository failures mapped to typed state. Riverpod (Notifier/AsyncNotifier) or Bloc — never both. Use when writing/reviewing/refactoring controllers, notifiers, blocs/cubits, or *_state.dart, and when deciding where state lives and how effects are surfaced.
when_to_use: When designing/implementing/reviewing a controller/notifier/bloc/state type, splitting state vs effect, choosing the state home, or catching smells like parallel-nullable state, BuildContext in a controller, or effects stored in state.
paths: **/*_controller.dart, **/*_notifier.dart, **/*_bloc.dart, **/*_cubit.dart, **/*_state.dart, **/presentation/**/*.dart
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-state-management

Rules for a controller's state/effect handling. The State items from
`guidance.md` expanded to an enforceable level. Project `ctx/` overrides this
document. Deeper material (freezed/sealed samples, Riverpod↔Bloc mapping) lives
in [reference.md](./reference.md).

## Scope

- In scope: controllers (Riverpod `Notifier`/`AsyncNotifier` or Bloc/Cubit),
  screen state types, effect streams, the state-home decision.
- Covers: immutable/sealed state modeling, effect vs state, UDF, async-gap
  safety, repository-failure mapping.
- Doesn't cover: module/DI wiring, widget rebuild perf, navigation/deep links,
  platform channels — follow the Related skills in [flutter-architecture].

## Core rules

Do:

- **One state type per screen**, immutable (sealed classes / `freezed` if the
  project uses it). The controller mutates by emitting a new value
  (`state = state.copyWith(...)` / `emit(...)`); widgets never mutate state.
- **Model loading/content/error explicitly** as a sealed hierarchy or
  `AsyncValue`, not as parallel nullables (`isLoading` + `data?` + `error?`).
- **One-shot effects** (snackbar, navigation, toast) go through an
  event/listener channel — Riverpod `ref.listen` on a signal, or Bloc
  listener — **not** persisted in state.
- **UDF**: widget renders state and raises actions up via callbacks; the
  controller turns actions into state and effects.
- Map **repository failures to typed state**. Raw exceptions never reach a
  widget → [flutter-architecture].
- After an `await`, **check `mounted`** before using `BuildContext` (or capture
  `context`-derived objects before the gap) → [flutter-widget-performance].
- Use the state library the project already has — Riverpod **or** Bloc, never
  both.

Don't:

- Reference `BuildContext`, `Widget`, or any Flutter UI type inside a controller.
- Encode a screen's state as a bag of independent nullables.
- Store a one-shot effect in a state field and reset it to null after consuming.
- Call a repository/client directly from a widget, or mutate state in the UI.
- Scatter multiple state types across one screen (related state is one type).
- Introduce a second state-management library into an existing project.

## Decision table

State vs effect — where each type lives:

| Nature of data | Where | Mechanism |
|---|---|---|
| Persistent state the screen renders (list, form, loading/error) | Controller state | sealed type / `AsyncValue` / freezed |
| Widget-local, ephemeral (scroll pos, dialog open, field focus) | UI local | `StatefulWidget`/`setState` |
| A signal expressible as state (login success → show CTA) | state flag, widget reacts | flag in state + `ref.listen`/`BlocListener` |
| A truly one-shot effect not expressible as state (navigate once, one snackbar) | effect stream | `ref.listen` signal / Bloc listener |
| Shared/business state across screens | Provider/Bloc scoped at feature/app | scoped provider / `BlocProvider` |

## Refactor / red-flag signals

- Controller importing `package:flutter/material.dart` or holding `BuildContext`.
- State as a bundle of mutually independent nullables → replace with sealed/`AsyncValue`.
- An effect stored in a state field and reset to null after consumption.
- `BuildContext` used after an `await` with no `mounted` check.
- Widget calling a repository/client directly or mutating state.
- More than one state type on a single screen.
- Both Riverpod and Bloc present in the codebase.

## References

- Flutter state management: https://docs.flutter.dev/data-and-backend/state-mgmt/options
- Riverpod (Notifier/AsyncNotifier): https://riverpod.dev/docs/essentials/side_effects
- Bloc — core concepts: https://bloclibrary.dev/bloc-concepts/
- freezed: https://pub.dev/packages/freezed
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Code samples, freezed/sealed patterns, effect wiring: [`reference.md`](reference.md)

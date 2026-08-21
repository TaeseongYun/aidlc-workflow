# Extension Rules

Rules for managing optional rule packs (Extensions).

## Purpose

Provides rules not needed by every project (security, compliance, performance, etc.) on an opt-in basis.
Loads only the needed rules to save context window, and enables per-team customization.

## Directory Structure

```text
extensions/
└── <domain>/
    ├── <name>.opt-in.md      # Lightweight prompt (~20 lines). Loaded at startup.
    └── <name>.md              # Full rules. Loaded only after opt-in.
```

## Rules

### Opt-In Files (`*.opt-in.md`)
- In STEP 1, scan the `extensions/` directory and load all `*.opt-in.md` files.
- Each opt-in file contains a simple question asking the user whether to enable it.
- Keep opt-in files within 20 lines. Do not include detailed rules.

### Full Rule Files (`*.md`)
- Load only when the user has approved the opt-in.
- An enabled extension applies as a **mandatory rule** throughout that workflow.
- Do not load the rule files of disabled extensions.

### State Tracking
- Record the state of each extension in the `Extension Configuration` section of `aidlc-state.md`.
- State: `disabled` (default) / `enabled`

### How to Add an Extension
1. Create the `extensions/<domain>/` directory.
2. Write `<name>.opt-in.md` (1 question, 1-2 lines of description).
3. Write `<name>.md` (full rules).
4. Add an entry to the Extension Configuration in the `aidlc-state.md` template.

## Currently Provided Extensions

| Extension | Domain | Description |
|-----------|--------|------|
| security-baseline | security | 11 production security baseline items (SECURITY-01~11) |
| performance-baseline | performance | 6 performance requirement items (PERF-01~06) |
| api-contract | api-contract | 5 API contract items (API-01~05) |

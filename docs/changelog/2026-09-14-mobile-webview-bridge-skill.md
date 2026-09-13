# 2026-09-14 — mobile-webview-bridge skill

## Summary

New skill `skills/mobile-webview-bridge/`: design, implement, and review the
JavaScript-to-native bridge between a WebView and native code on Android, iOS,
KMP, React Native, and Flutter. One platform-neutral core (message envelope,
handshake and versioning, security baseline, threading, lifecycle, error model)
with thin per-platform API bindings, following the mobile-core structure.

Two operating modes:

- **Generator** — given a filled message contract, scaffold the native handler
  and the JS client for the detected platform. Contract-first is enforced: no
  bridge code before `references/contract-template.md` is filled in.
- **Guard** — review existing bridge code against a severity-rated checklist
  (core checklist in SKILL.md; each platform reference appends only
  platform-specific items).

## Files Changed

- `skills/mobile-webview-bridge/SKILL.md` — core protocol, mode select,
  platform routing table (KMP marker checked before Android), guard checklist.
- `skills/mobile-webview-bridge/references/contract-template.md` — the message
  contract filled in before any generation; reserved error codes; additive-only
  change log.
- `skills/mobile-webview-bridge/references/{android,ios,kmp,rn,flutter}.md` —
  per-platform bindings: mechanism choice, threading deltas, security
  hardening, generator skeleton, platform guard-checklist additions.
- `skills/mobile-webview-bridge/scripts/validate_envelope.py` — offline
  stdlib-only validator for a message envelope or a captured message log
  (exit 0 valid / 1 findings / 2 bad input).
- `scripts/install-skills.sh` — added to the SKILLS array.
- `skills/README.md` — index entry.

## Rationale

Mobile work increasingly runs through hybrid WebView screens, and the JS
bridge is a recurring trust boundary none of the existing per-platform skill
families covered (security skills only warn about WebView in passing). The
hard problems — untrusted input at the boundary, contract drift between the
web and native teams, per-platform threading and lifecycle traps — are
identical across the five platforms, so the protocol lives once in the core
and each platform file is a thin delta.

## Impact

Additive: a new skill plus registry entries. No existing skill or script
behavior changes.

## Migration

None. Run `bash scripts/install-skills.sh` to install the new skill into
Codex skills and Claude commands.

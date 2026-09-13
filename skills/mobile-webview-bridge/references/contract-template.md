# Bridge message contract

Fill this in BEFORE writing any bridge code. It is the single source of truth
shared verbatim by the web team and the native team. One row per method. Copy
this file into the project (e.g. `docs/bridge-contract.md`) and keep it under
version control next to the code it governs.

## Metadata

- Protocol version: `1` (bump only on a breaking change; see the deprecation rule)
- Target platform(s): (android | ios | kmp | rn | flutter — one bridge per row set)
- Origin allowlist: (exact hosts the bridge is enabled on, e.g. `https://app.example.com`)
- Owner (native): (team/person)
- Owner (web): (team/person)

## Methods

| method | direction | request payload | response payload | error codes | owner | notes |
|---|---|---|---|---|---|---|
| `bridge.init` | JS→native | `{}` | `{ protocolVersion: number, capabilities: string[] }` | — | native | handshake; must be first call |
| `device.getInfo` | JS→native | `{}` | `{ os: string, appVersion: string }` | `UNAVAILABLE` | native | example |
| `analytics.track` | JS→native | `{ event: string, props?: object }` | `{ ok: true }` | `INVALID_PAYLOAD` | web | example, fire-and-forget still returns ack |
| `session.expired` | native→JS event | — | `{ reason: string }` | — | native | example push; no reply |

## Reserved error codes (every bridge)

| code | meaning |
|---|---|
| `UNKNOWN_METHOD` | method not in `capabilities` |
| `INVALID_PAYLOAD` | envelope or payload failed schema validation |
| `PAYLOAD_TOO_LARGE` | message exceeded the size bound |
| `TIMEOUT` | JS-side request timed out awaiting a response |
| `INTERNAL` | native handler threw; mapped, not crashed |

## Change log (additive-only)

- Adding a method or an optional field: bump nothing, append a row, ship.
- Renaming/removing a method or making a field required: this is breaking —
  open a deprecation window (old app + new web AND new app + old web must both
  work), announce the removal version, and only then delete.

| date | change | type (additive / breaking) | removal version (if breaking) |
|---|---|---|---|
| | | | |

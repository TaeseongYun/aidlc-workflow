---
name: frontend-api-contract
description: Frontend API-contract rules (single API client module, typed boundary, error normalization). All backend calls go through one API client module (base URL, auth header, error normalization) — no raw fetch scattered in components; API response types are declared (generated from the contract when codegen exists, hand-written and runtime-validated otherwise) with no any at the API boundary; errors are normalized to one shape the UI renders; untrusted responses are validated (zod/schema) before use. Use when adding/reviewing API client functions, typing responses, normalizing errors, or catching raw-fetch and any-at-the-boundary smells.
when_to_use: When adding an endpoint call, typing an API response, designing error normalization, validating a response, or catching raw fetch in components / any at the API boundary. Also for API client module design, response codegen, zod validation at the boundary.
paths: **/lib/api/**, **/api/**/*.ts, **/*.api.ts, **/services/**/*.ts, **/*client*.ts, **/openapi*.yaml, **/openapi*.json
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-api-contract — API client boundary

Rules that pin how the frontend talks to the backend: one client module, typed
responses, normalized errors. Expands the API-client items of `guidance.md` to an
actionable level. Project `ctx/` overrides this document. Deeper material (client
module, error normalization, zod validation) lives in [reference.md](./reference.md).

## Scope

- In scope: the API client module, request/response typing, error normalization,
  runtime response validation, auth-header wiring.
- Out of scope: where fetched data lives / caching → [frontend-state-data],
  component boundaries → [frontend-architecture], client-side security of
  responses (XSS on render, secrets) → [frontend-security].

## Core rules

Do:

- **One API client module.** Every backend call goes through it — base URL, auth
  header, timeout, and error normalization live in one place. Feature `api.ts`
  files wrap this client, not raw `fetch`.
- **Declare response types.** Generate them from the contract when the project
  has codegen (OpenAPI/GraphQL); otherwise hand-write them and **validate at
  runtime** (zod/valibot) at the boundary. **No `any`** at the API boundary.
- **Normalize errors to one shape.** Non-2xx / network / parse failures map to a
  single typed error (code · message · optional field errors) the UI renders.
  Don't let each call site invent its own error handling.
- **Never swallow failures.** An error surfaces as the error fetch-state, not a
  silent empty result → [frontend-state-data].
- **Validate untrusted responses** before use when the backend contract isn't
  guaranteed (third-party, versioned drift) — parse, then use the typed value.
- Send credentials deliberately (httpOnly cookie or `Authorization`), consistent
  across the client → [frontend-security].

Don't:

- Call `fetch`/`axios` directly inside a component or feature code, bypassing the
  client module.
- Type a response as `any`/`unknown`-then-cast without validation.
- Return raw backend error text / stack detail to the UI.
- `catch {}` a failed request and return `[]`/`null` silently.
- Duplicate base URL, headers, or error handling per call site.

## Endpoint-call checklist

When adding/changing an API call, in order:

| # | Check | If it fails |
|---|-------|-------------|
| 1 | Does the call go through the single client module? | Move it into the client / feature `api.ts` |
| 2 | Is the response typed (codegen or hand-written)? | Add the type; no `any` |
| 3 | Is an untrusted/drifting response validated at runtime? | Add a zod/schema parse at the boundary |
| 4 | Do errors normalize to the one shared shape? | Route through the client's error normalizer |
| 5 | Is the failure surfaced (not swallowed)? | Propagate to the error fetch-state |
| 6 | Are credentials sent consistently & safely? | Align with the auth strategy → frontend-security |

## Refactor / red-flag signals

- Raw `fetch`/`axios` calls scattered in components.
- `any` on API responses; `as SomeType` casts without validation.
- Error handling that swallows failures silently (`catch {} return []`).
- Base URL / auth header / error handling duplicated per call site.
- A third-party/versioned response consumed without validation.
- Backend error text or stack detail rendered to the user.

## References

- Team baseline: [../../guidance.md](../../guidance.md) (API client section)
- Deeper material: [reference.md](./reference.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- zod (runtime validation): https://zod.dev/
- TypeScript `fetch` typing / OpenAPI codegen: https://openapi-ts.dev/

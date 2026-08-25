---
name: backend-api-contract
description: Backend API contract rules — RESPONSE SHAPE LOCK, single error envelope (no stack-trace exposure), backward compatibility/versioning (additive-only), input validation at the controller boundary, CORS · pagination · content negotiation. Use when authoring or reviewing a Controller/Handler · route · OpenAPI spec, when adding a new endpoint or deciding a request/response DTO, or when adding/removing/retyping a field. Covers both Spring MVC (@RestController) and Node/TS (Express/Nest). This is the API contract skill for endpoint design, response shape, error envelope, versioning, CORS.
when_to_use: Adding/changing an endpoint/controller, designing request/response DTOs, deciding error-response format, judging API versioning/backward compatibility, setting CORS/rate-limit headers, authoring an OpenAPI spec
paths: **/*Controller.kt, **/*Controller.java, **/controller/**, **/web/**, **/*Resource.java, **/routes/**, **/*.controller.ts, **/*.router.ts, **/openapi*.yaml, **/openapi*.yml, **/swagger*.yaml
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-api-contract — API contract

Rules that pin the API's external contract. Response shape · error format ·
versioning are **part of the requirement**, not an implementation detail. Expands
the "API Contract" section of `../../guidance.md` to an actionable-decision level.
Deeper material (error envelope samples, versioning strategy, CORS config) lives in
[reference.md](./reference.md).

## Scope

- In scope: endpoint design, request/response DTOs, error responses, status codes,
  versioning/backward compatibility, CORS, pagination, content negotiation.
- Out of scope: authN/authZ judgment → [backend-auth], security validation of inputs
  (injection, etc.) → [backend-security-guard], rate-limit implementation/resilience
  → [backend-reliability].

## Core rules (do / don't)

### RESPONSE SHAPE LOCK — do not decide the response shape on your own

- The response schema is a requirement. **If it is not explicitly decided, STOP and
  ask** — do not pick String vs List, nullable vs default, or flat vs nested on your
  own. (Aligns with `ctx-run`'s RESPONSE SHAPE LOCK.)
- A refactor must not **silently** change the response shape. Adding a field is
  additive; removing/retyping is a design decision (approval required).

### Do

- **DO** return an explicit DTO, not the entity. Mapping is explicit
  (constructor/factory/mapper). Serving an entity directly is excessive exposure
  (BOPLA) → [backend-data-transactions].
- **DO** validate every external input at the controller boundary (Bean Validation
  `@Valid`, or Node's zod/class-validator). Type · range · required fields before the
  service is entered.
- **DO** use a single **error envelope** (code · message · field errors). If an
  existing format exists, use only that — do not invent a second format.
- **DO** bind **only allowed fields** on the request DTO (mass assignment / over-binding
  prevention): do not accept internal fields like `id` · `role` · `isAdmin` in the
  request body.
- **DO** use status codes by meaning: validation failure 400, authN 401, authZ 403,
  not found 404, conflict 409, rate limit 429. Exception→status mapping in one global
  handler.

### Don't

- **DON'T** expose a stack trace · SQL · internal class names · the framework's default
  error page to the client → information exposure. Production: a generalized message +
  a server-log correlation ID.
- **DON'T** remove/retype a field or make a breaking change to the response shape on a
  public API → additive-only. Breaking changes go in a new version (`/v2`) or an
  approved design.
- **DON'T** open CORS with `Access-Control-Allow-Origin: *` + credentials. Specify an
  origin allowlist → [reference.md](./reference.md) §CORS.
- **DON'T** return an entire list without pagination (unbounded resource consumption,
  API4:2023).
- **DON'T** put business logic/transactions in the controller → [backend-architecture].

## Endpoint-addition checklist

When touching a new/changed endpoint, in order:

| # | Check | If it fails |
|---|-------|-------------|
| 1 | Is the response schema explicitly decided? | STOP, confirm the requirement (no arbitrary decision) |
| 2 | Is the response a DTO, not an entity? | Add DTO mapping |
| 3 | Does the request DTO accept only allowed fields? | Remove internal fields (over-binding) |
| 4 | Is input validation at the controller boundary? | Add `@Valid`/validator |
| 5 | Do errors follow the single envelope · status-code convention? | Route through the global handler |
| 6 | No stack-trace/internal-info exposure? | Generalized message + log correlation ID |
| 7 | Is the change backward compatible (additive)? | If breaking, version/approval |
| 8 | Is the contract recorded in the technical design (Section 3)? | Record it |

## Refactor / red-flag signals

- The controller returns the entity as-is (excessive exposure · over-binding).
- An exception is passed to the client as a default stack trace/error page.
- Error format differs per endpoint (envelope not unified).
- The request body accepts authority/identity fields like `role`/`isAdmin`/`id`.
- CORS wildcard origin + credentials.
- List response has no pagination/cap.
- Response fields silently disappear or change type in review.

## References

- Team baseline: [../../guidance.md](../../guidance.md) (API Contract section)
- Deeper material: [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- REST Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html
- Error Handling Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html

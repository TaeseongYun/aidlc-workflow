---
name: frontend-contract-codegen
description: Frontend API contract codegen — generate typed client code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, any at the boundary, stringly-typed
  endpoints, unmodeled error/status responses, manual (de)serialization drift, nullable/required
  mismatch, enum-as-raw-string, regen without diffing, hand-edited generated files, no single source
  of truth). Covers openapi-typescript + openapi-fetch, orval, openapi-generator (typescript-axios),
  and @graphql-codegen with typed React Query/SWR hooks. Auto-loads when generating clients from a
  schema.
when_to_use: When generating or wiring an API client from OpenAPI/GraphQL, adding an endpoint,
  reviewing hand-written models, or on requests like "generate the client", "types from the schema",
  "why is the client out of sync".
paths: "**/openapi*.{yaml,yml,json}, **/*.graphql, **/generated/**, **/*.gen.ts, **/codegen.{ts,yml,yaml}"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# frontend-contract-codegen — API contract codegen + drift guard

The OpenAPI spec or GraphQL schema is the **single source of truth**. AI codegen
ignores it: it hand-writes a duplicate interface that drifts from the schema, types
responses as `any`, hardcodes URL strings, models only the 200 path, and hand-edits
generated files that the next regen wipes. The result is client/server drift and
runtime surprises at the boundary the type system was supposed to protect.

This skill is a **generator** (run the codegen tool, wire the typed client) plus a
**guard** (block hand-written drift). It is the codegen counterpart to
[frontend-api-contract](../frontend-api-contract/SKILL.md), which governs the API
client module shape and error normalization; this one turns the contract into code.
Project `ctx/` overrides this document. Code examples live in
[reference.md](./reference.md).

## Scope

- In scope: finding the schema, running the codegen tool, wiring the generated client,
  and blocking the 10 contract-drift failure modes below.
- **Contract definition/review** → [frontend-api-contract] (one API client module,
  error normalization, zod validation for uncontrolled backends).
- **Client/data layer architecture** → [frontend-architecture].
- **Contract tests** (MSW, vitest, Playwright) → [frontend-testing].
- **Auth/transport security** → [frontend-security].

## Mode A — Generate

### 1. Find the schema (single source of truth)

The schema lives in one canonical location — the backend publishes it, the frontend
consumes it. Do not copy/paste it or maintain a parallel version.

```
# OpenAPI: commonly served live or committed as a file
GET https://api.example.com/openapi.json
# or committed at:
openapi.yaml  /  openapi/openapi.yaml  /  specs/openapi.yaml
```

For GraphQL: the schema is fetched via introspection or committed as a `.graphql`
file. Use the canonical URL the backend team publishes.

### 2. Run the codegen tool

**OpenAPI → TypeScript** (choose one per project; be consistent):

```bash
# Option A: openapi-typescript (types only) + openapi-fetch (typed fetch client)
npx openapi-typescript ./openapi.yaml -o src/generated/api.gen.ts

# Option B: orval (types + React Query / SWR hooks in one step)
npx orval --config orval.config.ts

# Option C: openapi-generator (typescript-axios)
npx @openapitools/openapi-generator-cli generate \
  -i ./openapi.yaml -g typescript-axios \
  -o src/generated/api
```

Minimal `orval.config.ts`:

```ts
import { defineConfig } from 'orval';

export default defineConfig({
  api: {
    input: './openapi.yaml',
    output: {
      mode: 'tags-split',
      target: 'src/generated/api.gen.ts',
      client: 'react-query',        // or 'swr'
      override: { mutator: { path: 'src/lib/api/client.ts', name: 'apiClient' } },
    },
  },
});
```

**GraphQL → TypeScript** (@graphql-codegen):

```yaml
# codegen.yml
schema: https://api.example.com/graphql
documents: 'src/**/*.graphql'
generates:
  src/generated/graphql.gen.ts:
    plugins:
      - typescript
      - typescript-operations
      - typescript-react-query   # or typescript-urql / typescript-react-apollo
```

```bash
npx graphql-codegen --config codegen.yml
```

### 3. Wire the generated client

The generated types/client plug into the single API client module from
[frontend-api-contract] — they do not replace it.

```ts
// src/lib/api/client.ts  — your existing client module (openapi-fetch example)
import createClient from 'openapi-fetch';
import type { paths } from '@/generated/api.gen';  // generated types

export const apiClient = createClient<paths>({ baseUrl: process.env.NEXT_PUBLIC_API_BASE });
```

Feature call with **typed request + typed error handling** (no `any`):

```ts
// src/features/users/api.ts
import { apiClient } from '@/lib/api/client';

export async function getUser(id: string) {
  const { data, error } = await apiClient.GET('/users/{id}', {
    params: { path: { id } },
  });
  if (error) throw new ApiError(error);   // error is typed from the schema's error component
  return data;                            // data is typed from the schema's 200 response
}
```

For typed React Query hooks via orval, the generated hook already carries the typed
response and error — import and use it directly; do not re-wrap.

### 4. Regenerate on schema change

A new field, endpoint, or status code is a **schema change + regen**, not a
hand-written parallel model. Choose one regeneration discipline and enforce it:

| Approach | When to use | How |
|---|---|---|
| **Commit generated code** | Schema changes infrequently; reviewers should see the typed diff | Run regen, commit `src/generated/`, include in PR diff |
| **Generate at build time** | Schema is fetched live; CI always has the latest | `prebuild` script in `package.json`; `src/generated/` in `.gitignore` |

Either way: regen is one command, the diff is reviewed, and no hand-editing of
generated files happens. The calibration knob: regenerating and reviewing the diff
once is smaller work than maintaining a hand-written parallel type indefinitely.

## Mode B — Guard

Detect and block the 10 contract-drift failure modes AI commonly introduces. Each
item: **rule → common AI failure → red-flag**. Code examples in
[reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: interfaces/types that mirror a schema component must come from the
  codegen output. If a type duplicates a schema shape by hand, delete it and
  import the generated type.
- **Common AI failure**: writes `interface UserResponse { id: string; name: string; }`
  that mirrors the schema's `User` component — maintained manually, drifts silently.
- **red-flag**: a manually maintained interface whose fields match a schema component;
  no import from `generated/`; the field list is suspiciously close to a spec type.

### 2. Untyped boundary (`any`)

- **Rule**: API response and request bodies are typed. No `any`, `unknown`-then-cast
  without validation, or `as SomeType` at the boundary. Generated types cover this
  automatically; if codegen is absent, use zod at the boundary →
  [frontend-api-contract].
- **Common AI failure**: `const data = await res.json() as any`, or
  `const result: any = await apiClient.get(...)`.
- **red-flag**: `any` on a fetch result or API client return value; bare `as
  SomeType` cast without a zod parse.

### 3. Stringly-typed endpoint

- **Rule**: use the generated operation method or typed path constant — no raw URL
  string + verb inline in feature code. The path lives in the schema; the generated
  client enforces it.
- **Common AI failure**: `fetch('/api/users/' + id, { method: 'GET' })` or `axios.get('/users/${id}')` inline in a feature file.
- **red-flag**: a URL string literal for a backend path in feature or component code;
  raw `fetch`/`axios` calls bypassing the typed client method.

### 4. Unmodeled error/status

- **Rule**: the schema declares error response schemas (4xx, 5xx, problem-detail).
  Generated types include them. Wire typed error handling for the declared error
  components — not just a catch-all `Error`.
- **Common AI failure**: only handles the 200 response; wraps all non-2xx in
  `throw new Error(res.statusText)` with no typed shape.
- **red-flag**: a call site with no typed error branch; `error` typed as `Error` or
  `unknown` where the schema has an error component.

### 5. Manual (de)serialization drift

- **Rule**: generated clients handle JSON (de)serialization. Do not hand-roll
  `JSON.parse(res.text())` or manual field extraction when the generated client
  already returns a typed object.
- **Common AI failure**: `const user = { id: data['user_id'], name: data['userName'] }`
  — field names drift from the schema's `snake_case`/`camelCase` contract.
- **red-flag**: manual `data['field']` access on a fetch response; snake/camelCase
  mismatches; hand-rolled `JSON.parse` where a generated client method exists.

### 6. Nullable/required mismatch

- **Rule**: a schema field marked `nullable: true` or absent from `required` is
  optional — treat it as `T | null | undefined`. A required field is `T`. Do not
  force-unwrap or non-null-assert a field the schema marks optional.
- **Common AI failure**: `user.email!` or `user.address.street` when `address` is
  nullable in the schema; or wrapping a required field in an unnecessary `?? ''`.
- **red-flag**: non-null assertion (`!`) or optional chain omission on a field that
  is optional in the schema; conversely, defensive fallbacks on schema-required
  fields obscuring type errors.

### 7. Enum as raw string

- **Rule**: a schema enum generates a TypeScript union type or const enum. Use the
  generated type — not a bare string literal — so that exhaustiveness and typo
  safety apply.
- **Common AI failure**: `status === 'active'` where the generated type is
  `UserStatus = 'active' | 'inactive' | 'suspended'`, missing exhaustive switch
  coverage for the added `'suspended'` value.
- **red-flag**: string literals compared against a field whose generated type is an
  enum/union; no exhaustive switch/map; the literal doesn't appear in the generated
  union.

### 8. Regen without diffing

- **Rule**: every schema bump that triggers regen must include a generated-code diff
  in the PR. Breaking changes (renamed fields, removed paths, narrowed types) surface
  in the diff — reviewing it is the contract-migration step.
- **Common AI failure**: updates `openapi.yaml` version and re-runs codegen in the
  same commit with a "bump schema" message; no generated diff visible.
- **red-flag**: a schema/version bump with no corresponding change in `generated/`;
  or `generated/` excluded from the PR diff with `# nogenerate` / `.gitattributes`
  collapse.

### 9. Hand-edited generated file

- **Rule**: files in `generated/` or annotated `// GENERATED — do not edit` must not
  be modified by hand. They are owned by the codegen tool and overwritten on the
  next regen. Put customizations in wrappers outside the generated dir.
- **Common AI failure**: patches a field name inside `src/generated/api.gen.ts` to
  fix a mismatch; the patch is erased on the next schema regen.
- **red-flag**: a diff that edits lines inside a `generated/` directory or a file
  with a `do not edit` header comment; customization logic inside a generated file.

### 10. No single source of truth

- **Rule**: the schema is the one definition of the API shape. The frontend must not
  maintain a hand-written parallel copy of any type the schema defines. If the schema
  is absent or not under your control, generate from a local committed copy — do not
  fork the shape.
- **Common AI failure**: the backend and frontend each define `type User = { ... }`
  independently; they diverge within a sprint.
- **red-flag**: a type defined in both a backend module and a frontend module with no
  codegen relationship; two files maintaining the same field list by hand.

## Contract-codegen review checklist

For any PR adding/changing API calls or schema types:

- [ ] Response/request types come from `generated/` — no hand-maintained duplicates.
- [ ] No `any` at the API boundary; generated types used directly.
- [ ] Endpoint accessed via the generated typed method, not a raw URL string.
- [ ] Error responses (4xx/5xx) handled with typed error shapes from the schema.
- [ ] No manual JSON field access; the generated client handles (de)serialization.
- [ ] Nullable/required mirrors the schema; no unsafe non-null assertions on optional
  fields.
- [ ] Schema enums used as generated union types, not bare string literals.
- [ ] Schema bump accompanied by a generated-code diff in the PR.
- [ ] No hand-edits inside `generated/`; customizations live in wrappers.
- [ ] One canonical schema location; no parallel hand-maintained type copies.

## Halt conditions

Stop and report if:

- The schema file cannot be found and the backend team has no canonical location —
  the contract is undefined. Do not proceed with codegen or hand-write types.
- The project uses two competing codegen tools generating overlapping types — resolve
  the toolchain conflict before proceeding.
- A generated file has been so heavily hand-edited that regen would destroy work —
  surface this before running regen.

On halt output:

```
## [action] halted

Reason:
- (specific reason)

Items requiring confirmation:
1. ...
```

Do not propose alternatives. Output only the halt reason.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Contract counterpart: [frontend-api-contract](../frontend-api-contract/SKILL.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent: [frontend-security](../frontend-security/SKILL.md), [frontend-testing](../frontend-testing/SKILL.md)
- Code examples (bad → good per guard rule): [reference.md](./reference.md)
- openapi-typescript: https://openapi-ts.dev/
- openapi-fetch: https://openapi-ts.dev/openapi-fetch/
- orval: https://orval.dev/
- openapi-generator (typescript-axios): https://openapi-generator.tech/docs/generators/typescript-axios
- @graphql-codegen: https://the-guild.dev/graphql/codegen

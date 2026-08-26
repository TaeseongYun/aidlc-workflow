---
name: rn-contract-codegen
description: React Native API contract codegen — generate typed TS client code from the OpenAPI/GraphQL
  contract (the single source of truth) instead of hand-writing types, and detect/block the drift AI
  commonly produces (hand-written DTO duplicating the schema, any at the boundary, stringly-typed
  endpoints, unmodeled error/status responses, manual (de)serialization drift, nullable/required mismatch,
  enum-as-raw-string, regen without diffing, hand-edited generated files, no single source of truth).
  Covers the RN codegen tools (openapi-typescript + openapi-fetch, orval, @graphql-codegen). Auto-loads
  when generating clients from a schema or reviewing hand-written API models.
when_to_use: When generating or wiring an API client from OpenAPI/GraphQL, adding an endpoint,
  reviewing hand-written models, or on requests like "generate the client", "types from the schema",
  "why is the client out of sync", "add a new API call".
paths: >-
  **/openapi*.{yaml,yml,json}, **/*.graphql, **/generated/**, **/*.gen.ts,
  **/codegen.{ts,yml,yaml}
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# rn-contract-codegen — API contract → typed client

AI generates API client code the wrong way: it hand-writes a duplicate DTO
that drifts from the schema, types the response as `any`, hardcodes URL strings
inline, models only the happy 200 path, and edits generated files the next
regen will wipe. The result is client/server drift that surfaces at runtime —
usually in production. This skill is a **generator** (run the codegen tool,
wire the typed client) plus a **guard** (block hand-written drift). It is the
codegen execution counterpart to `rn-security` (transport/auth), `rn-testing`
(contract tests), and `rn-architecture` (client/data layer placement). Project
`ctx/` overrides this document. Code samples live in [reference.md](./reference.md).

## Scope

- In scope: running `openapi-typescript`/`orval`/`@graphql-codegen`, wiring the
  generated client, typed error handling, regen discipline, and the 10 drift
  guard rules below.
- Doesn't cover: defining or reviewing the OpenAPI/GraphQL schema itself (no
  `rn-api-contract` skill; cross-link the backend/server as the schema's owner);
  client placement in the data layer → [rn-architecture]; auth/transport security
  → [rn-security]; contract tests (e.g. MSW request handlers) → [rn-testing].
- Single source of truth: the **schema** owns the shape. The client is generated
  from it — never the reverse.

## Mode A — Generate

### 1. Locate the schema (single source of truth)

The schema lives in one place: an `openapi*.yaml|yml|json` file, a `*.graphql`
schema file, or a remote URL the server publishes. Never copy-paste field
definitions from a Postman collection or a Slack message — those are already
downstream of the truth.

```
# Common locations
openapi.yaml            # project root or docs/
src/api/openapi.yaml
graphql/schema.graphql
http://localhost:4000/graphql  # introspect live schema
```

### 2. Run the codegen tool

**OpenAPI → TypeScript types + fetch client (openapi-typescript + openapi-fetch)**

```bash
# Install once
npm install -D openapi-typescript openapi-fetch

# Generate types (output to src/generated/api.d.ts or src/generated/api.ts)
npx openapi-typescript openapi.yaml -o src/generated/api.ts
```

Minimal `package.json` script so regen is one command:

```json
"scripts": {
  "gen:api": "openapi-typescript openapi.yaml -o src/generated/api.ts"
}
```

**OpenAPI → typed React Query hooks (orval)**

```bash
npm install -D orval
```

`orval.config.ts`:

```ts
import { defineConfig } from 'orval';

export default defineConfig({
  api: {
    input: './openapi.yaml',
    output: {
      mode: 'tags-split',
      target: './src/generated/api.ts',
      schemas: './src/generated/model',
      client: 'react-query',
      override: {
        mutator: {
          path: './src/lib/axios-instance.ts',
          name: 'customInstance',
        },
      },
    },
  },
});
```

```bash
npx orval           # generates typed hooks + model types
```

**GraphQL → typed operations (@graphql-codegen)**

```bash
npm install -D @graphql-codegen/cli @graphql-codegen/typescript \
  @graphql-codegen/typescript-operations @graphql-codegen/typescript-react-query
```

`codegen.ts`:

```ts
import type { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  schema: 'http://localhost:4000/graphql',   // or a .graphql file path
  documents: ['src/**/*.graphql'],           // operation documents
  generates: {
    './src/generated/graphql.ts': {
      plugins: [
        'typescript',
        'typescript-operations',
        'typescript-react-query',
      ],
      config: {
        fetcher: { endpoint: 'http://localhost:4000/graphql' },
        exposeQueryKeys: true,
      },
    },
  },
};
export default config;
```

```bash
npx graphql-codegen   # generates typed hooks + all operation types
```

### 3. Wire the generated client with typed error handling

Generated code is not self-wiring. After codegen, do exactly this:

```ts
// src/lib/api-client.ts
import createClient from 'openapi-fetch';
import type { paths } from '../generated/api';

export const apiClient = createClient<paths>({ baseUrl: process.env.API_BASE_URL });
```

```ts
// src/features/orders/useOrders.ts
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../lib/api-client';
import type { components } from '../../generated/api';

// The error schema is generated — use it, don't ignore it
type ApiError = components['schemas']['ErrorResponse'];

export function useOrders() {
  return useQuery({
    queryKey: ['orders'],
    queryFn: async () => {
      const { data, error, response } = await apiClient.GET('/orders', {});
      if (error) {
        // error is typed from the schema's error response schema
        const apiError = error as ApiError;
        throw new Error(apiError.message ?? `HTTP ${response.status}`);
      }
      return data;  // typed as components['schemas']['Order'][]
    },
  });
}
```

### 4. Regen discipline — the calibration knob

A new field, endpoint, or schema version is a **schema change + regen** cycle,
reviewed once — never a hand-written parallel model:

```
Schema changes  →  run npm run gen:api  →  review the generated diff  →  update callers
```

Pick one regen strategy and be consistent:

- **Commit generated code** (simpler, diff is visible in PRs): commit
  `src/generated/` and run `gen:api` locally before each PR that changes the schema.
- **Generate at build time** (no generated files in git): add `gen:api` to the
  prebuild/CI step, gitignore `src/generated/`. MSW mocks for tests still need a
  committed snapshot → [rn-testing].

Never mix strategies: don't commit some generated files and build-generate others.

## Mode B — Guard (10 drift failure modes)

Each rule: **rule → the failure AI commonly produces → red-flag**. Code pairs in [reference.md](./reference.md).

### 1. Hand-written DTO instead of generated

- **Rule**: interfaces/types that mirror a schema component live in `src/generated/`
  only — generated, not hand-maintained. If the shape comes from the schema, codegen
  owns it.
- **Common AI failure**: `interface UserResponse { id: number; name: string; email: string; }`
  written by hand, duplicating a schema component, diverging the moment the schema changes.
- **red-flag**: a `interface`/`type` whose fields match a schema component, in a
  non-generated file, maintained by hand.

### 2. Untyped boundary (`any` at the API layer)

- **Rule**: API response/request types are **never** `any`, `unknown` with no
  narrowing, or `Record<string, any>`. The generated types are the boundary — use them.
- **Common AI failure**: `const data: any = await fetch(...).then(r => r.json())`,
  or casting the response `as any` to "fix" a type error.
- **red-flag**: `any` or unnarrowed `unknown` on an API call result or request body.

### 3. Stringly-typed endpoint

- **Rule**: URL paths and HTTP verbs are expressed through the generated client's
  typed methods — not as string literals assembled inline.
- **Common AI failure**: `fetch('/api/users/' + userId, { method: 'GET' })` or
  `axios.get(\`/api/orders/${id}\`)` inline in a component, duplicating a path
  already in the spec.
- **red-flag**: a URL path string literal (or template literal) for an API call
  where a generated client method covers the operation.

### 4. Unmodeled error/status responses

- **Rule**: the spec's declared 4xx/5xx error schemas are typed and handled — not
  silently swallowed or typed as `any`. At minimum the error response shape is
  destructured from the generated client.
- **Common AI failure**: a `try/catch` that ignores the error body, or a
  `.catch(e => console.log(e))` where the spec defines a structured error response.
- **red-flag**: no typed handling for the schema's declared error responses; an
  untyped `catch (e: any)` where error schema types are available.

### 5. Manual (de)serialization drift

- **Rule**: field mapping is the codegen tool's job. No hand-rolled `JSON.parse` +
  field access, no manual snake→camel transforms the tool already handles.
- **Common AI failure**: `const user = { id: res.data.user_id, name: res.data.full_name }`
  mapping snake_case by hand when the generated client already transforms the shape.
- **red-flag**: manual field access like `data['snake_case_field']` or an explicit
  `JSON.parse(response.text())` on a response the generated client already deserializes.

### 6. Nullable/required mismatch

- **Rule**: fields the schema marks optional (`nullable: true` / `required: false`)
  are treated as `T | null | undefined` — no non-null assertion on them. Fields
  the schema marks required are not guarded unnecessarily either.
- **Common AI failure**: `user.address!.city` when `address` is `nullable: true`
  in the schema; or over-guarding a required field with `??` defaults that mask
  real nulls the server never sends.
- **red-flag**: `!` non-null assertion on a field the generated type marks
  optional/nullable; or repeated `?? ''` on required fields.

### 7. Enum as raw string

- **Rule**: schema enums are used as the generated enum/union type — never as bare
  string literals. Callers get exhaustiveness checking; the compiler catches removed
  members.
- **Common AI failure**: `if (order.status === 'PENDING')` where `order.status` is
  a generated union type and `'PENDING'` drifts when the schema adds `'AWAITING_PAYMENT'`.
- **red-flag**: string literals where a generated enum or string-union type covers
  the values; no exhaustive switch/exhaustiveness check on a discriminated union from
  the schema.

### 8. Regen without diffing

- **Rule**: bumping the schema version or regenerating after a schema change requires
  a diff review of the generated client before merging. Breaking changes in the diff
  (removed operations, changed required fields, renamed types) are addressed — not
  silently merged.
- **Common AI failure**: running `gen:api`, accepting all generated changes wholesale,
  and opening a PR with no review of what changed in the generated types.
- **red-flag**: a schema/version bump with no generated-code diff visible in the PR
  (or a diff that shows breaking changes with no corresponding fix in callers).

### 9. Hand-edited generated file

- **Rule**: files under `src/generated/` (or whatever dir the codegen tool targets)
  carry a `// This file is auto-generated — do not edit` header. Any manual edits
  are lost on the next regen. Customizations go in wrapper modules.
- **Common AI failure**: editing `src/generated/api.ts` directly to "fix" a type or
  add a missing field, then regenerating and losing the edit.
- **red-flag**: a diff that modifies files inside `src/generated/` or any file whose
  first line is an auto-generated warning header.

### 10. No single source of truth

- **Rule**: the schema (owned by the server) is the one definition of the contract.
  The client is generated from it. There is no second hand-maintained copy of the
  shape on the client side.
- **Common AI failure**: a hand-written `types/api.ts` on the client that mirrors
  what the server already publishes in `openapi.yaml`, maintained independently by
  both sides.
- **red-flag**: two independent type definitions for the same contract shape — one
  server-side (in the schema) and one client-side (hand-written). The client copy
  has no CI verification that it matches.

## Halt conditions

Stop and report (do not proceed) when:

- No schema file or URL is locatable and none is provided — codegen has no input.
- The codegen tool is not installed and cannot be added without a dependency decision
  outside this task's scope.
- The generated output would overwrite hand-edited files that have no wrapper story —
  flag the conflict before regenerating.

**Output on halt:**

```
## Codegen halted

Halt reason:
- <specific reason>

Required before proceeding:
1. <what is needed>
```

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Umbrella: [rn-architecture](../rn-architecture/SKILL.md) — client/data layer placement
- Safety floor: [rn-security](../rn-security/SKILL.md) — auth, transport, TLS
- Contract tests + MSW mocks: [rn-testing](../rn-testing/SKILL.md)
- Code samples (bad→good per rule, codegen examples): [reference.md](./reference.md)
- openapi-typescript: https://openapi-ts.dev/
- openapi-fetch: https://openapi-ts.dev/openapi-fetch/
- orval: https://orval.dev/
- @graphql-codegen: https://the-guild.dev/graphql/codegen

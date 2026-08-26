# frontend-contract-codegen — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code per guard rule +
Mode-A worked examples. TypeScript / React. Decision criteria live in `SKILL.md`.

---

## Mode A — Worked examples

### A1. Codegen command + config (openapi-typescript + openapi-fetch)

```bash
# Install (once)
npm install -D openapi-typescript
npm install openapi-fetch

# Generate types from the committed schema
npx openapi-typescript ./openapi.yaml -o src/generated/api.gen.ts

# Or from a live endpoint (CI / prebuild)
npx openapi-typescript https://api.example.com/openapi.json -o src/generated/api.gen.ts
```

`package.json` integration:

```json
{
  "scripts": {
    "codegen": "openapi-typescript ./openapi.yaml -o src/generated/api.gen.ts",
    "prebuild": "npm run codegen"
  }
}
```

### A2. Wiring a typed call with typed error handling

```ts
// src/lib/api/client.ts
import createClient from 'openapi-fetch';
import type { paths } from '@/generated/api.gen';

export const apiClient = createClient<paths>({
  baseUrl: process.env.NEXT_PUBLIC_API_BASE ?? '',
});

// Typed error shape from the schema's error component
export class ApiError extends Error {
  constructor(public readonly detail: paths['/errors']['get']['responses'][400]['content']['application/json']) {
    super(detail.message);
  }
}
```

```ts
// src/features/users/api.ts
import { apiClient, ApiError } from '@/lib/api/client';

// ✅ typed request params, typed 200 response, typed error branch
export async function getUser(id: string) {
  const { data, error } = await apiClient.GET('/users/{id}', {
    params: { path: { id } },
  });
  if (error) throw new ApiError(error);  // error typed from schema's error component
  return data;                           // data: components['schemas']['User'] — no cast needed
}

// ✅ typed mutation with typed body
export async function updateUser(id: string, body: paths['/users/{id}']['patch']['requestBody']['content']['application/json']) {
  const { data, error } = await apiClient.PATCH('/users/{id}', {
    params: { path: { id } },
    body,
  });
  if (error) throw new ApiError(error);
  return data;
}
```

### A3. orval with typed React Query hooks

```ts
// orval.config.ts
import { defineConfig } from 'orval';

export default defineConfig({
  api: {
    input: './openapi.yaml',
    output: {
      mode: 'tags-split',
      target: 'src/generated/api.gen.ts',
      client: 'react-query',
      override: {
        mutator: { path: 'src/lib/api/client.ts', name: 'apiClient' },
      },
    },
  },
});
```

```bash
npx orval --config orval.config.ts
```

```tsx
// src/features/users/UserDetail.tsx
import { useGetUsersId } from '@/generated/api.gen';  // typed hook, orval-generated

export function UserDetail({ id }: { id: string }) {
  const { data, error, isLoading } = useGetUsersId(id);  // data: User, error: ApiError
  if (isLoading) return <Spinner />;
  if (error) return <ErrorBanner error={error} />;
  return <div>{data.name}</div>;  // data is typed — no assertion needed
}
```

---

## Guard rule examples

### Rule 1 — Hand-written DTO instead of generated

```ts
// ❌ Hand-maintained interface that duplicates the schema's User component — drifts silently
interface UserResponse {
  id: string;
  name: string;
  email: string;      // schema later makes this optional — this won't update
  createdAt: string;
}
const res = await fetch('/users/1');
const user = (await res.json()) as UserResponse;
```

```ts
// ✅ Import the generated type — regen keeps it in sync
import type { components } from '@/generated/api.gen';
type User = components['schemas']['User'];  // tracks the schema automatically

const { data } = await apiClient.GET('/users/{id}', { params: { path: { id: '1' } } });
// data is already typed as User — no cast
```

---

### Rule 2 — Untyped boundary (`any`)

```ts
// ❌ any at the boundary — loses all type safety downstream
const res = await fetch(`/api/users/${id}`);
const data: any = await res.json();
console.log(data.nmae);  // typo compiles silently
```

```ts
// ✅ generated client returns typed data — no cast, no any
import { apiClient } from '@/lib/api/client';

const { data, error } = await apiClient.GET('/users/{id}', {
  params: { path: { id } },
});
// data: components['schemas']['User'] | undefined
// error: components['schemas']['ErrorResponse'] | undefined
```

```ts
// ✅ If codegen is not available, validate at the boundary with zod → frontend-api-contract
import { z } from 'zod';
const UserSchema = z.object({ id: z.string(), name: z.string() });
const user = UserSchema.parse(await res.json());  // typed + runtime-safe
```

---

### Rule 3 — Stringly-typed endpoint

```ts
// ❌ raw URL string + verb — path can drift from the schema without a type error
const res = await fetch(`/api/users/${id}`, { method: 'GET' });
const data = await res.json();

// ❌ axios inline — same problem
const { data } = await axios.get<UserResponse>(`/users/${id}`);
```

```ts
// ✅ generated typed path — the compiler rejects a path that doesn't exist in the schema
import { apiClient } from '@/lib/api/client';

const { data } = await apiClient.GET('/users/{id}', {
  params: { path: { id } },
  // TS error if '/users/{id}' is not in paths — catches renames at compile time
});
```

---

### Rule 4 — Unmodeled error/status

```ts
// ❌ only handles the 200 path; 4xx errors have no typed shape
async function deleteUser(id: string) {
  const res = await fetch(`/users/${id}`, { method: 'DELETE' });
  if (!res.ok) throw new Error(res.statusText);  // error detail lost, no typed fields
  return res.json();
}
```

```ts
// ✅ typed error branch using the schema's error component
import { apiClient } from '@/lib/api/client';
import type { components } from '@/generated/api.gen';

type DeleteError = components['schemas']['ErrorResponse'];  // 404 | 403 schema shape

async function deleteUser(id: string) {
  const { data, error } = await apiClient.DELETE('/users/{id}', {
    params: { path: { id } },
  });
  if (error) {
    // error is typed as DeleteError — access .code, .message, .field_errors
    if (error.code === 'NOT_FOUND') throw new NotFoundError(error.message);
    throw new ApiError(error);
  }
  return data;
}
```

---

### Rule 5 — Manual (de)serialization drift

```ts
// ❌ hand-rolling field extraction — field names drift from schema's snake_case contract
const res = await fetch('/users/1');
const raw = await res.json();
const user = {
  id: raw['user_id'],          // schema says 'id'
  name: raw['userName'],       // schema says 'user_name' — mismatch
  email: raw['emailAddress'],  // schema says 'email'
};
```

```ts
// ✅ generated client handles deserialization; fields match the schema definition
import { apiClient } from '@/lib/api/client';

const { data } = await apiClient.GET('/users/{id}', {
  params: { path: { id: '1' } },
});
// data.id, data.name, data.email — exactly as declared in the schema, no mapping needed
```

---

### Rule 6 — Nullable/required mismatch

```ts
// ❌ non-null assertion on an optional field — runtime crash when the field is absent
// Schema: address: { type: 'object', nullable: true }
const street = user.address!.street;   // crashes when address is null

// ❌ missing guard on an optional nested field
const city = user.address.city;        // TS error if address is Address | null
```

```ts
// ✅ respect nullable — use optional chaining / guard
const street = user.address?.street;          // string | undefined — safe
const city = user.address?.city ?? 'Unknown'; // explicit fallback

// ✅ narrow before accessing
if (user.address) {
  console.log(user.address.street);  // Address in this branch — no assertion needed
}
```

---

### Rule 7 — Enum as raw string

```ts
// ❌ bare string literal — misses schema values added later, no exhaustiveness
// Schema: status enum: ['active', 'inactive', 'suspended']
if (user.status === 'active') { /* ... */ }
// 'suspended' case silently falls through with no compile-time warning
```

```ts
// ✅ use the generated union type + exhaustive handling
import type { components } from '@/generated/api.gen';

type UserStatus = components['schemas']['User']['status'];
// = 'active' | 'inactive' | 'suspended'

function labelForStatus(status: UserStatus): string {
  switch (status) {
    case 'active':    return 'Active';
    case 'inactive':  return 'Inactive';
    case 'suspended': return 'Suspended';
    default: {
      const _exhaustive: never = status;  // compile error when schema adds a new value
      return _exhaustive;
    }
  }
}
```

---

### Rule 8 — Regen without diffing

```diff
# ❌ schema version bump + regen with no visible generated diff in the PR
- version: '1.2.0'
+ version: '1.3.0'

# generated/ unchanged in the PR — reviewers can't see the breaking field rename
```

```bash
# ✅ regen explicitly and commit the diff
npm run codegen          # regenerate
git diff src/generated/  # inspect: renamed fields, removed paths, narrowed types
# review the diff, then commit generated/ alongside the schema bump
git add openapi.yaml src/generated/
git commit -m "feat: bump schema 1.3 — user.userName renamed to user.name"
```

If `generated/` is generated at build time (not committed), add a CI step that
regenerates and fails the build on unexpected drift:

```yaml
# .github/workflows/ci.yml
- run: npm run codegen
- run: git diff --exit-code src/generated/  # fail if schema ≠ committed types
```

---

### Rule 9 — Hand-edited generated file

```ts
// ❌ inside src/generated/api.gen.ts — "do not edit" header present
// GENERATED by openapi-typescript — do not edit
export type User = {
  id: string;
  userName: string;  // ← hand-patched to match an old backend field name
};
// This edit is erased on the next `npm run codegen`
```

```ts
// ✅ customization lives in a wrapper outside generated/
// src/lib/api/users.ts  — not generated, safe to edit
import type { components } from '@/generated/api.gen';

type User = components['schemas']['User'];

// extend or adapt the generated type without touching the generated file
export type UserViewModel = User & { displayName: string };

export function toViewModel(user: User): UserViewModel {
  return { ...user, displayName: user.name ?? user.email };
}
```

---

### Rule 10 — No single source of truth

```ts
// ❌ backend team's openapi.yaml defines:
//   User: { id, name, email, role }
// Frontend hand-maintains a parallel copy:
// src/types/user.ts
export interface User {
  id: string;
  name: string;
  email: string;
  role: string;  // backend changes this to an enum — frontend doesn't know
}
// These diverge within a sprint. Runtime crash when role values change.
```

```ts
// ✅ one canonical schema; frontend generates from it
// Run: npm run codegen  (points to backend's canonical openapi.yaml or published URL)
import type { components } from '@/generated/api.gen';

export type User = components['schemas']['User'];
// When backend changes role to an enum, regen surfaces it as a type error → fix once
```

```ts
// ✅ if the backend schema is not yet published, commit a local copy and own the regen
// openapi/openapi.yaml  ← committed, the frontend team's SSOT until backend publishes
// codegen reads from it; the file is updated (not reimplemented) when backend delivers theirs
```

---

## Codegen regen discipline cheatsheet

| Event | Action |
|---|---|
| New endpoint added to the schema | `npm run codegen` → review diff → commit |
| Existing field renamed in schema | `npm run codegen` → fix TS errors in callers → commit |
| Nullable changed to required (or vice versa) | `npm run codegen` → audit `!` assertions → commit |
| New enum value added | `npm run codegen` → check exhaustive switches → commit |
| Generated file shows unexpected diff in CI | Do not ignore — investigate schema/tool version mismatch |
| Tempted to hand-edit a generated file | Stop — add a wrapper outside `generated/` instead |

## References

- Decision criteria: [SKILL.md](./SKILL.md)
- Contract module rules: [frontend-api-contract](../frontend-api-contract/SKILL.md)
- openapi-typescript docs: https://openapi-ts.dev/
- openapi-fetch docs: https://openapi-ts.dev/openapi-fetch/
- orval docs: https://orval.dev/
- openapi-generator (typescript-axios): https://openapi-generator.tech/docs/generators/typescript-axios
- @graphql-codegen: https://the-guild.dev/graphql/codegen
- Team baseline: [../../guidance.md](../../guidance.md)

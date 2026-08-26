# rn-contract-codegen — Reference

Deep-dive for `SKILL.md`. One bad→good TS pair per guard rule, plus Mode-A
worked examples: codegen command + config, and wiring a typed call with typed
error handling. Decision criteria and the guard rules live in `SKILL.md`.

---

## Mode A — Codegen end to end

### Example 1: OpenAPI → typed client (openapi-typescript + openapi-fetch)

Schema fragment (`openapi.yaml`):

```yaml
openapi: '3.1.0'
info:
  title: Orders API
  version: '1.0.0'
paths:
  /orders:
    get:
      operationId: listOrders
      parameters:
        - name: status
          in: query
          schema:
            $ref: '#/components/schemas/OrderStatus'
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Order'
        '422':
          description: Validation error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ValidationError'
components:
  schemas:
    OrderStatus:
      type: string
      enum: [PENDING, PROCESSING, SHIPPED, DELIVERED]
    Order:
      type: object
      required: [id, status, total]
      properties:
        id:          { type: string }
        status:      { $ref: '#/components/schemas/OrderStatus' }
        total:       { type: number }
        shippedAt:   { type: string, format: date-time, nullable: true }
    ValidationError:
      type: object
      required: [message, fields]
      properties:
        message: { type: string }
        fields:  { type: array, items: { type: string } }
```

Generate:

```bash
npm run gen:api
# npx openapi-typescript openapi.yaml -o src/generated/api.ts
```

Wire the typed client:

```ts
// src/lib/api-client.ts
import createClient from 'openapi-fetch';
import type { paths } from '../generated/api';

export const apiClient = createClient<paths>({
  baseUrl: process.env.EXPO_PUBLIC_API_BASE_URL,
});
```

Typed React Query hook with typed error handling:

```ts
// src/features/orders/useOrders.ts
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../lib/api-client';
import type { components } from '../../generated/api';

type Order = components['schemas']['Order'];
type OrderStatus = components['schemas']['OrderStatus'];
type ValidationError = components['schemas']['ValidationError'];

interface UseOrdersParams {
  status?: OrderStatus;
}

export function useOrders({ status }: UseOrdersParams = {}) {
  return useQuery<Order[], ValidationError>({
    queryKey: ['orders', status],
    queryFn: async () => {
      const { data, error, response } = await apiClient.GET('/orders', {
        params: { query: status ? { status } : {} },
      });

      if (error) {
        // error is typed as ValidationError from the 422 schema
        throw Object.assign(new Error(error.message), { fields: error.fields });
      }

      return data;  // typed as Order[]
    },
  });
}
```

### Example 2: GraphQL → typed hooks (@graphql-codegen)

Write the operation document alongside the feature, not inline:

```graphql
# src/features/orders/operations.graphql
query ListOrders($status: OrderStatus) {
  orders(status: $status) {
    id
    status
    total
    shippedAt
  }
}
```

`codegen.ts` at project root:

```ts
import type { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  schema: process.env.GRAPHQL_ENDPOINT ?? 'http://localhost:4000/graphql',
  documents: ['src/**/*.graphql'],
  generates: {
    './src/generated/graphql.ts': {
      plugins: [
        'typescript',
        'typescript-operations',
        'typescript-react-query',
      ],
      config: {
        fetcher: {
          endpoint: process.env.GRAPHQL_ENDPOINT ?? 'http://localhost:4000/graphql',
        },
        exposeQueryKeys: true,
        scalars: { DateTime: 'string' },
      },
    },
  },
};
export default config;
```

```bash
npx graphql-codegen
```

Use the generated hook — no hand-written fetch:

```ts
// src/features/orders/OrdersScreen.tsx
import { useListOrdersQuery } from '../../generated/graphql';
import type { OrderStatus } from '../../generated/graphql';

export function OrdersScreen() {
  const { data, isLoading, error } = useListOrdersQuery({ status: OrderStatus.Pending });
  // data.orders is typed from the schema; OrderStatus.Pending is the generated enum
  ...
}
```

---

## Mode B — Guard rule code pairs

### Rule 1: Hand-written DTO instead of generated

```ts
// BAD — hand-written interface duplicating the schema's Order component
interface Order {
  id: string;
  status: string;          // lost the enum; will drift when schema adds a new status
  total: number;
  shippedAt: string | null;
}

async function fetchOrder(id: string): Promise<Order> {
  const res = await fetch(`/api/orders/${id}`);
  return res.json();
}
```

```ts
// GOOD — use the generated type; regen keeps it in sync automatically
import type { components } from '../generated/api';
import { apiClient } from '../lib/api-client';

type Order = components['schemas']['Order'];

async function fetchOrder(id: string): Promise<Order> {
  const { data, error } = await apiClient.GET('/orders/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(String(error));
  return data;
}
```

---

### Rule 2: Untyped boundary (`any` at the API layer)

```ts
// BAD — response typed as any; compiler can't catch field access errors
async function getUser(id: string): Promise<any> {
  const res = await fetch(`/api/users/${id}`);
  const data: any = await res.json();
  return data;
}

// caller silently gets any — no type checking
const user = await getUser('u1');
console.log(user.emailAddress);  // typo; schema says 'email' — no error at compile time
```

```ts
// GOOD — generated type; field typo is a compile error
import type { components } from '../generated/api';
import { apiClient } from '../lib/api-client';

type User = components['schemas']['User'];

async function getUser(id: string): Promise<User> {
  const { data, error } = await apiClient.GET('/users/{id}', {
    params: { path: { id } },
  });
  if (error) throw new Error(String(error));
  return data;
  // user.emailAddress → TS error: Property 'emailAddress' does not exist on type 'User'
}
```

---

### Rule 3: Stringly-typed endpoint

```ts
// BAD — URL assembled as a string; duplicates the spec path; no type safety
async function createOrder(payload: { items: string[]; total: number }) {
  const res = await fetch('/api/v1/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return res.json();
}

// months later: spec renames /api/v1/orders → /api/v2/orders/create; this silently 404s
```

```ts
// GOOD — generated client method; path comes from the spec
import { apiClient } from '../lib/api-client';
import type { components } from '../generated/api';

type CreateOrderBody = components['schemas']['CreateOrderRequest'];
type Order = components['schemas']['Order'];

async function createOrder(payload: CreateOrderBody): Promise<Order> {
  const { data, error } = await apiClient.POST('/orders', { body: payload });
  if (error) throw new Error(String(error));
  return data;
  // if /orders is renamed in the spec and regenerated, this is a compile error immediately
}
```

---

### Rule 4: Unmodeled error/status responses

```ts
// BAD — only happy path; error body silently discarded; untyped catch
async function submitOrder(id: string) {
  try {
    const res = await fetch(`/api/orders/${id}/submit`, { method: 'POST' });
    const data = await res.json();
    return data;
  } catch (e: any) {
    console.error('submit failed', e);  // e is the fetch network error, not the API error body
  }
}
```

```ts
// GOOD — generated client surfaces the typed error schema; handle it explicitly
import { apiClient } from '../lib/api-client';
import type { components } from '../generated/api';

type SubmitError = components['schemas']['OrderSubmitError'];

async function submitOrder(id: string) {
  const { data, error, response } = await apiClient.POST('/orders/{id}/submit', {
    params: { path: { id } },
  });

  if (error) {
    const typed = error as SubmitError;
    // typed.code and typed.reason come from the 422 schema — handled, not discarded
    throw Object.assign(new Error(typed.reason), { code: typed.code, status: response.status });
  }

  return data;
}
```

---

### Rule 5: Manual (de)serialization drift

```ts
// BAD — hand-rolled field mapping; snake_case access that the client already handles;
// will silently break when schema renames the field
async function getProfile(userId: string) {
  const res = await fetch(`/api/profile/${userId}`);
  const raw = await res.json();
  return {
    id: raw.user_id,           // manual snake→camel mapping
    fullName: raw.full_name,
    avatarUrl: raw.avatar_url,
  };
}
```

```ts
// GOOD — generated client handles the shape (orval or openapi-fetch with camelCase transform);
// no manual field mapping; schema rename → compile error at the call site
import { apiClient } from '../lib/api-client';
import type { components } from '../generated/api';

type UserProfile = components['schemas']['UserProfile'];

async function getProfile(userId: string): Promise<UserProfile> {
  const { data, error } = await apiClient.GET('/profile/{userId}', {
    params: { path: { userId } },
  });
  if (error) throw new Error(String(error));
  return data;  // data.fullName is already camelCase; shape is exactly what the schema says
}
```

---

### Rule 6: Nullable/required mismatch

```ts
// BAD — non-null assertion on a nullable field; runtime crash when server sends null
import type { components } from '../generated/api';
type Order = components['schemas']['Order'];

function formatShippedAt(order: Order): string {
  // shippedAt is typed string | null in the generated type (schema: nullable: true)
  return new Date(order.shippedAt!).toLocaleDateString();  // ! asserts non-null → crash when null
}
```

```ts
// GOOD — respect the generated nullability; guard before use
import type { components } from '../generated/api';
type Order = components['schemas']['Order'];

function formatShippedAt(order: Order): string {
  if (order.shippedAt == null) return 'Not shipped yet';
  return new Date(order.shippedAt).toLocaleDateString();
  // TS narrows order.shippedAt to string after the null check — no assertion needed
}
```

---

### Rule 7: Enum as raw string

```ts
// BAD — string literal instead of generated union; exhaustiveness lost;
// if schema adds OrderStatus.AwaitingPayment this branch silently falls through
import type { components } from '../generated/api';
type Order = components['schemas']['Order'];

function getStatusLabel(order: Order): string {
  if (order.status === 'PENDING') return 'Pending';
  if (order.status === 'SHIPPED') return 'Shipped';
  return 'Other';  // new status values silently land here
}
```

```ts
// GOOD — use the generated enum/union; exhaustiveness check catches schema additions
import type { components } from '../generated/api';

type Order = components['schemas']['Order'];
type OrderStatus = components['schemas']['OrderStatus'];

function getStatusLabel(order: Order): string {
  const status: OrderStatus = order.status;
  switch (status) {
    case 'PENDING':     return 'Pending';
    case 'PROCESSING':  return 'Processing';
    case 'SHIPPED':     return 'Shipped';
    case 'DELIVERED':   return 'Delivered';
    default: {
      // exhaustiveness: if schema adds a new status this is a TS error
      const _exhaustive: never = status;
      return _exhaustive;
    }
  }
}
```

---

### Rule 8: Regen without diffing

```ts
// BAD workflow — regenerate and merge without reviewing what changed
// $ npm run gen:api
// $ git add src/generated/
// $ git commit -m "bump schema"
// $ git push
// (PR opens; reviewer sees only "generated file changed"; breaking rename unnoticed)
```

```ts
// GOOD workflow — diff-first regen
// 1. Pull the new schema
// 2. npm run gen:api
// 3. git diff src/generated/  ← review this before staging
//    — removed operation?  find all callers and update them
//    — required field added? find all places that build the request body
//    — enum member renamed? find all switch statements
// 4. Fix callers; then git add + commit
// 5. PR description references the schema diff and lists breaking changes

// A CI step that catches accidental drift:
// package.json:
//   "ci:check-gen": "npm run gen:api && git diff --exit-code src/generated/"
// If generated output differs from committed output, CI fails.
```

---

### Rule 9: Hand-edited generated file

```ts
// BAD — editing src/generated/api.ts directly
// src/generated/api.ts  (line 1: // This file is auto-generated — do not edit)
export interface Order {
  id: string;
  status: OrderStatus;
  total: number;
  shippedAt: string | null;
  internalNote: string;  // ← manually added; gone after next regen
}
```

```ts
// GOOD — extend in a separate module; generated file stays pristine
// src/generated/api.ts stays untouched
// src/lib/api-extensions.ts
import type { components } from '../generated/api';

type GeneratedOrder = components['schemas']['Order'];

// Augmented type lives outside the generated dir
export interface Order extends GeneratedOrder {
  internalNote: string;  // client-only field not in the schema; survives regen
}

// Or if the field should be in the schema, add it there and regen — never edit generated files.
```

---

### Rule 10: No single source of truth

```ts
// BAD — two independent definitions of the same contract shape;
// server updates its OpenAPI schema; client hand-type never gets updated

// server openapi.yaml:
//   UserProfile:
//     required: [id, email, displayName]
//     properties:
//       id: { type: string }
//       email: { type: string }
//       displayName: { type: string }
//       avatarUrl: { type: string, nullable: true }

// client src/types/api.ts (hand-maintained — no CI link to the server schema):
export interface UserProfile {
  id: string;
  email: string;
  name: string;      // ← server says displayName; silent mismatch
  avatar: string;    // ← server says avatarUrl, nullable; client treats as required string
}
```

```ts
// GOOD — one definition: the schema; client generated from it
// npm run gen:api → src/generated/api.ts (auto)
//
// src/types/api.ts is deleted; callers import from the generated module:
import type { components } from '../generated/api';

export type UserProfile = components['schemas']['UserProfile'];
// displayName and avatarUrl are correct and nullable-annotated because the schema says so.
// Next schema change → regen → compile errors point to every broken caller.
```

---

## MSW contract mocks (for rn-testing)

When testing hooks that call the generated client, mock at the network level with MSW
so the mock stays aligned with the generated types:

```ts
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';
import type { components } from '../generated/api';

type Order = components['schemas']['Order'];

const mockOrder: Order = {
  id: 'ord-1',
  status: 'PENDING',
  total: 99.99,
  shippedAt: null,
};

export const handlers = [
  http.get('/orders', () => HttpResponse.json([mockOrder])),
  http.post('/orders/:id/submit', () =>
    HttpResponse.json(
      // typed from the error schema
      { code: 'OUT_OF_STOCK', reason: 'Item unavailable' } satisfies components['schemas']['OrderSubmitError'],
      { status: 422 },
    ),
  ),
];
```

The mock shape is typed against the generated schema — if the schema changes and you
regen, a shape mismatch is a compile error in the test file, not a silent test pass
with wrong data. See [rn-testing](../rn-testing/SKILL.md) for test setup.

---

## References

- `SKILL.md` — guard rules, Mode A procedure, halt conditions
- openapi-typescript docs: https://openapi-ts.dev/
- openapi-fetch docs: https://openapi-ts.dev/openapi-fetch/
- orval docs: https://orval.dev/
- @graphql-codegen docs: https://the-guild.dev/graphql/codegen
- MSW (Mock Service Worker): https://mswjs.io/
- Contract tests: [rn-testing](../rn-testing/SKILL.md)
- Client/data layer: [rn-architecture](../rn-architecture/SKILL.md)

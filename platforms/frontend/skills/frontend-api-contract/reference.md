# frontend-api-contract — Reference

Deep-dive for `SKILL.md`. The client module, error normalization, runtime
validation. Decision criteria live in `SKILL.md`.

## 1. One API client module

```ts
// lib/api/client.ts — base URL, auth, timeout, error normalization all in one place.
export class ApiError extends Error {
  constructor(readonly code: string, message: string, readonly fields?: Record<string, string>) {
    super(message);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: { 'content-type': 'application/json', ...authHeader(), ...init?.headers },
    credentials: 'include', // httpOnly cookie strategy → frontend-security
  });
  if (!res.ok) throw await normalizeError(res);        // one error shape
  return (await res.json()) as T;
}

// Feature api.ts wraps the client — not raw fetch
export const ordersApi = {
  list: () => request<Order[]>('/orders'),
  get: (id: string) => request<Order>(`/orders/${id}`),
};
```

```tsx
// ❌ Anti-pattern: raw fetch in a component
const res = await fetch('/api/orders'); const data = await res.json(); // untyped, no error norm
```

## 2. Error normalization (one shape)

```ts
async function normalizeError(res: Response): Promise<ApiError> {
  const body = await res.json().catch(() => ({}));
  // map backend envelope → one client-side shape; never surface raw stack detail
  return new ApiError(body.code ?? `http_${res.status}`, body.message ?? 'Request failed', body.fieldErrors);
}
// UI renders ApiError.message + field errors; the error fetch-state, not a silent empty.
```

## 3. Typed boundary + runtime validation

```ts
// ✅ Codegen path: types generated from OpenAPI/GraphQL — types match the contract by construction.

// ✅ Hand-written path: validate at runtime so a drifting/3rd-party response can't lie to TS
import { z } from 'zod';
const Order = z.object({ id: z.string(), total: z.number(), status: z.enum(['open', 'paid']) });
type Order = z.infer<typeof Order>;

async function getOrder(id: string): Promise<Order> {
  const raw = await request<unknown>(`/orders/${id}`);
  return Order.parse(raw); // throws on drift → caught + normalized, never a bad `any`
}

// ❌ const order = raw as Order;  // a cast is a lie, not a check
```

## 4. Don't swallow failures

```ts
// ❌ silent empty on error → the UI shows "no data" instead of an error
try { return await ordersApi.list(); } catch { return []; }

// ✅ let it propagate to the error fetch-state
return await ordersApi.list(); // useQuery surfaces isError → frontend-state-data
```

## 5. API-boundary review checklist

- [ ] All calls go through the single client module (no raw `fetch` in components).
- [ ] Responses typed (codegen) or hand-typed + runtime-validated. No `any`.
- [ ] Untrusted/drifting responses parsed (zod) before use.
- [ ] Errors normalized to one shape; no raw backend/stack text to the UI.
- [ ] Failures propagate to the error fetch-state (not swallowed).
- [ ] Base URL / auth header / error handling defined once.

## Official references

- zod: https://zod.dev/
- OpenAPI TypeScript codegen: https://openapi-ts.dev/
- MDN Fetch API: https://developer.mozilla.org/docs/Web/API/Fetch_API
- Team baseline: [../../guidance.md](../../guidance.md)

# frontend-observability — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per
failure mode. TypeScript + React / Next.js. Decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- AI-generated code ships `console.log` debugging verbatim — it is the fastest prototype path and
  the model has no prod-ops feedback loop to unlearn it.
- Logging PII is a compliance violation (GDPR, PCI-DSS) that appears frequently in AI-generated
  API wrappers and error handlers that dump full objects for "easy debugging".
- Empty catch blocks are the single most common AI-generated error-handling pattern — the model
  prefers syntactic completeness over operational visibility.
- Without a crash reporter wired on startup, every uncaught browser exception is invisible in
  production. AI scaffolds rarely include Sentry init.

---

## Logging wrapper (foundation — required before rule 1)

```ts
// src/lib/logger.ts — one logger, all output routes through here
// ponytail: thin wrapper; upgrade to a structured-log lib if log volume grows

type Level = 'debug' | 'info' | 'warn' | 'error';

interface LogFields {
  traceId?: string;
  [key: string]: unknown;
}

const IS_PROD = process.env.NODE_ENV === 'production';

function emit(level: Level, message: string, fields: LogFields = {}): void {
  if (IS_PROD && level === 'debug') return; // debug suppressed in prod
  // In prod, replace with your log-drain call (Datadog, Logtail, etc.)
  const entry = { level, message, timestamp: new Date().toISOString(), ...fields };
  // eslint-disable-next-line no-console -- logger.ts is the ONLY allowed console caller
  console[level](JSON.stringify(entry));
}

export const logger = {
  debug: (msg: string, fields?: LogFields) => emit('debug', msg, fields),
  info:  (msg: string, fields?: LogFields) => emit('info',  msg, fields),
  warn:  (msg: string, fields?: LogFields) => emit('warn',  msg, fields),
  error: (msg: string, fields?: LogFields) => emit('error', msg, fields),
};
```

```jsonc
// .eslintrc or eslint.config.mjs — enforce no-console outside the wrapper
{
  "rules": {
    "no-console": "error"          // ← catches every stray console.* at lint time
  },
  "overrides": [
    {
      "files": ["src/lib/logger.ts"],
      "rules": { "no-console": "off" }  // wrapper is the one allowed exception
    }
  ]
}
```

---

## 1. Debug print left in production

```ts
// ❌ Raw console calls shipped to prod
async function fetchOrder(id: string) {
  console.log("fetching order", id);
  const res = await api.get(`/orders/${id}`);
  console.log("got response", res.data);
  return res.data;
}

// ✅ Route through the logger wrapper; lint blocks any new console.*
import { logger } from '@/lib/logger';

async function fetchOrder(id: string, traceId: string) {
  logger.debug('fetchOrder start', { orderId: id, traceId });
  const res = await api.get(`/orders/${id}`);
  logger.debug('fetchOrder complete', { orderId: id, traceId });
  return res.data;
}
```

---

## 2. PII / secrets in logs

```ts
// ❌ Logs the full user object — includes email, phone, token
logger.info('user authenticated', { user });

// ❌ Logs the Authorization header verbatim
logger.error('API call failed', { headers: req.headers });

// ❌ Logs the entire response body (may contain card data, PII)
logger.info('payment response', { response: paymentRes.data });

// ✅ Log only non-sensitive identifiers — never the object itself
logger.info('user authenticated', { userId: user.id, traceId });

// ✅ Strip sensitive headers before logging; see frontend-security for the full surface
logger.error('API call failed', {
  status: res.status,
  traceId,
  // headers deliberately omitted
});

// ✅ Log outcome fields only; never the payload body
logger.info('payment response', {
  paymentId: paymentRes.data.id,
  status: paymentRes.data.status,
  traceId,
});
```

---

## 3. Unstructured logging

```ts
// ❌ Concatenated string — unsearchable, un-alertable in any log aggregator
logger.info("User " + userId + " completed checkout for order " + orderId);
logger.error(`Payment ${paymentId} failed with code ${code}`);

// ✅ Structured fields — every key is independently filterable
logger.info('checkout completed', { userId, orderId, traceId });
logger.error('payment failed',    { paymentId, errorCode: code, traceId });
```

---

## 4. Missing correlation / trace ID

```ts
// ❌ No traceId — these two logs cannot be tied together in production
async function submitOrder(order: Order) {
  logger.info('submitting order', { orderId: order.id });
  await notifyWarehouse(order);           // logs inside here have no shared ID
}

// ✅ Generate a traceId at the entry point and thread it through every call
import { randomUUID } from 'crypto'; // or use crypto.randomUUID() in the browser

async function submitOrder(order: Order) {
  const traceId = crypto.randomUUID(); // one ID per user action / request
  logger.info('submitting order', { orderId: order.id, traceId });
  await notifyWarehouse(order, traceId);
  logger.info('order submitted', { orderId: order.id, traceId });
}

async function notifyWarehouse(order: Order, traceId: string) {
  logger.debug('notifying warehouse', { orderId: order.id, traceId }); // same ID
  // ...
}
```

```tsx
// ✅ React context pattern — propagate traceId without prop-drilling
// src/lib/TraceContext.tsx
import { createContext, useContext, useMemo } from 'react';

const TraceCtx = createContext<string>('');
export const useTraceId = () => useContext(TraceCtx);

export function TraceProvider({ children }: { children: React.ReactNode }) {
  const traceId = useMemo(() => crypto.randomUUID(), []); // stable per mount
  return <TraceCtx.Provider value={traceId}>{children}</TraceCtx.Provider>;
}
```

---

## 5. Wrong log level

```ts
// ❌ error() for expected control flow — will fire every time a session expires
try {
  await requireAuth(req);
} catch (e) {
  logger.error('auth failed', { error: e, traceId }); // over-alerts on-call
  redirect('/login');
}

// ❌ info() for a genuine failure that needs attention
} catch (e) {
  logger.info('payment processing error', { error: e }); // will never alert
}

// ✅ warn() for expected, recoverable cases; error() only for genuine failures
try {
  await requireAuth(req);
} catch (e) {
  logger.warn('session expired, redirecting', { traceId }); // expected; no alert
  redirect('/login');
}

try {
  await chargeCard(order);
} catch (e) {
  logger.error('payment charge failed', { orderId: order.id, error: e, traceId }); // real failure
}
```

---

## 6. Swallowed error

```ts
// ❌ Empty catch — exception completely invisible
try {
  await syncInventory(productId);
} catch {}

// ❌ Logs a string but drops the exception object — stack trace lost
try {
  await syncInventory(productId);
} catch (e) {
  logger.error('sync failed'); // e is never passed — no stack, no type, no cause
}

// ✅ Always pass the caught exception as a field; re-throw if the caller needs to handle it
try {
  await syncInventory(productId);
} catch (e) {
  logger.error('inventory sync failed', { productId, error: e, traceId });
  Sentry.captureException(e, { extra: { productId, traceId } });
  throw e; // re-throw so callers can react — don't silently swallow
}
```

---

## 7. Logging in hot path / loop

```tsx
// ❌ Log inside .map() — fires once per list item on every render
function ProductList({ products }: { products: Product[] }) {
  return (
    <ul>
      {products.map((p) => {
        logger.debug('rendering product', { id: p.id }); // ← N logs per render
        return <li key={p.id}>{p.name}</li>;
      })}
    </ul>
  );
}

// ❌ Log inside a scroll handler — fires hundreds of times per second
window.addEventListener('scroll', () => {
  logger.debug('scroll event', { y: window.scrollY });
});

// ✅ Log once at mount; move per-item detail to dev-only tooling
function ProductList({ products }: { products: Product[] }) {
  useEffect(() => {
    logger.debug('ProductList mounted', { count: products.length }); // once
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  return <ul>{products.map((p) => <li key={p.id}>{p.name}</li>)}</ul>;
}

// ✅ Throttle or sample high-frequency events if logging is truly needed
let lastScrollLog = 0;
window.addEventListener('scroll', () => {
  const now = Date.now();
  if (now - lastScrollLog > 2000) { // log at most once per 2 s
    logger.debug('scroll checkpoint', { y: window.scrollY });
    lastScrollLog = now;
  }
});
```

---

## 8. No metrics (logs only)

```ts
// ❌ Payment flow with logging but zero metrics — no alert can fire on failure rate
async function processPayment(order: Order, traceId: string) {
  logger.info('payment started', { orderId: order.id, traceId });
  const result = await chargeCard(order);
  logger.info('payment complete', { orderId: order.id, traceId });
  return result;
}

// ✅ Wrap with a Sentry transaction (timing + pass/fail metric) and a custom mark
import * as Sentry from '@sentry/browser';

async function processPayment(order: Order, traceId: string) {
  performance.mark('payment-start');
  const span = Sentry.startInactiveSpan({ name: 'processPayment', op: 'payment' });
  try {
    logger.info('payment started', { orderId: order.id, traceId });
    const result = await chargeCard(order);
    logger.info('payment complete', { orderId: order.id, traceId });
    span.setStatus({ code: 1 }); // OK
    return result;
  } catch (e) {
    span.setStatus({ code: 2 }); // ERROR
    throw e;
  } finally {
    span.end();
    performance.measure('payment-duration', 'payment-start');
  }
}
```

```tsx
// ✅ web-vitals RUM — report Core Web Vitals to your analytics endpoint
import { onCLS, onFID, onLCP, onINP, onTTFB } from 'web-vitals';

function sendToAnalytics(metric: { name: string; value: number; id: string }) {
  // send to your RUM endpoint — NOT to a log call
  navigator.sendBeacon('/api/vitals', JSON.stringify(metric));
}

onCLS(sendToAnalytics);
onFID(sendToAnalytics);
onLCP(sendToAnalytics);
onINP(sendToAnalytics);
onTTFB(sendToAnalytics);
```

---

## 9. Missing crash / error reporting

```tsx
// ❌ Sentry never initialised — all uncaught exceptions silently vanish in prod
// main.tsx
import { App } from './App';
ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

// ❌ ErrorBoundary logs but never forwards to Sentry
class ErrorBoundary extends React.Component {
  componentDidCatch(error: Error) {
    console.error(error); // ← invisible in prod without Sentry
  }
}

// ✅ Sentry init before root mount — unconditional, not guarded by env check
// main.tsx
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: process.env.SENTRY_DSN, // server-side env var — no NEXT_PUBLIC_ prefix needed here
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.2,        // adjust per traffic volume
});

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

// ✅ ErrorBoundary forwards to Sentry + logs with context
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    logger.error('react error boundary caught', {
      error,
      componentStack: info.componentStack,
    });
    Sentry.captureException(error, { extra: { componentStack: info.componentStack } });
  }

  static getDerivedStateFromError() { return { hasError: true }; }

  render() {
    return this.state.hasError ? <ErrorFallback /> : this.props.children;
  }
}
```

---

## 10. Non-actionable message

```ts
// ❌ Bare strings — on-call can't tell what failed, for which user, or what to do
logger.error('error occurred');
logger.warn('something failed');
logger.info('request failed');

// ❌ Slightly better string but still no structured fields
logger.error(`Payment failed for order ${orderId}`); // unstructured, hard to aggregate

// ✅ Every log: entity IDs + operation + state + (for errors) structured error field
logger.error('payment charge failed', {
  orderId: order.id,
  userId: order.userId,
  paymentProvider: 'stripe',
  errorCode: (e as StripeError).code,
  error: e,
  traceId,
});

logger.warn('auth token expired', {
  userId: session.userId,
  expiredAt: session.expiresAt,
  traceId,
});

logger.info('checkout completed', {
  orderId: order.id,
  userId: order.userId,
  itemCount: order.items.length,
  totalCents: order.totalCents,
  traceId,
});
```

---

## Do example A — structured log with correlation ID + redaction

```ts
// src/services/orderService.ts
import { logger } from '@/lib/logger';
import * as Sentry from '@sentry/browser';

export async function placeOrder(
  cart: Cart,
  user: { id: string }, // only the ID, never the full user object
  traceId: string,
): Promise<Order> {
  logger.info('placeOrder start', {
    userId: user.id,
    itemCount: cart.items.length,
    traceId,
    // cart.items deliberately not logged (may contain user data)
  });

  try {
    const order = await api.post<Order>('/orders', { cartId: cart.id });
    logger.info('placeOrder success', {
      userId: user.id,
      orderId: order.id,
      traceId,
    });
    return order;
  } catch (e) {
    logger.error('placeOrder failed', {
      userId: user.id,
      cartId: cart.id,
      error: e,
      traceId,
    });
    Sentry.captureException(e, { extra: { userId: user.id, cartId: cart.id, traceId } });
    throw e;
  }
}
```

---

## Do example B — metric + crash reporter wired at app entry

```tsx
// src/main.tsx
import * as Sentry from '@sentry/react';
import { onCLS, onLCP, onINP } from 'web-vitals';
import ReactDOM from 'react-dom/client';
import { App } from './App';

// Crash reporter: unconditional, before mount
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  integrations: [Sentry.browserTracingIntegration()],
});

// RUM metrics: report Core Web Vitals to analytics endpoint
const reportVital = (m: { name: string; value: number; id: string }) =>
  navigator.sendBeacon('/api/vitals', JSON.stringify(m));

onCLS(reportVital);
onLCP(reportVital);
onINP(reportVital);

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);
```

---

## Full observability review checklist

- [ ] No raw `console.*` outside `src/lib/logger.ts`; `no-console` ESLint rule enforced in prod.
- [ ] No PII (email, token, card, SSN, auth header, full body) in any log — see [frontend-security](../frontend-security/reference.md).
- [ ] All log calls use structured key/value fields — no concatenated strings or inline template variables.
- [ ] Every async operation and API call carries a `traceId` / `correlationId` through all logs.
- [ ] Log levels match severity: `debug` dev-only, `info` normal, `warn` recoverable, `error` real failures.
- [ ] No empty catch blocks; every catch passes the exception object to the logger and Sentry.
- [ ] No log calls inside render bodies, loops, scroll/resize/animation-frame callbacks.
- [ ] Critical operations (auth, payment, key feature) emit a Sentry span or `performance.mark`.
- [ ] `Sentry.init()` called unconditionally before root mount; `ErrorBoundary` calls `Sentry.captureException()`.
- [ ] Every log and error includes entity IDs (`userId`, `orderId`, etc.) and operation context.

## Official references

- Sentry Browser SDK: https://docs.sentry.io/platforms/javascript/
- Sentry Performance Monitoring: https://docs.sentry.io/platforms/javascript/performance/
- web-vitals library: https://github.com/GoogleChrome/web-vitals
- Core Web Vitals: https://web.dev/vitals/
- W3C Trace Context (traceparent): https://www.w3.org/TR/trace-context/
- ESLint no-console rule: https://eslint.org/docs/latest/rules/no-console
- Team baseline: [../../guidance.md](../../guidance.md)

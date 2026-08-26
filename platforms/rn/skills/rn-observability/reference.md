# rn-observability — Reference

Deep-dive material for `SKILL.md`. **Anti-pattern (❌) vs correct (✅)** code samples per
failure mode. TypeScript + React Native. Decision criteria live in `SKILL.md`.

---

## Positive examples first — what good looks like

### Structured log with correlation ID and redaction

```ts
// src/lib/logger.ts — one logger, controls all transports
import * as Sentry from '@sentry/react-native';

type Level = 'debug' | 'info' | 'warn' | 'error';
type Fields = Record<string, unknown>;

const isDev = __DEV__;

function log(level: Level, message: string, fields: Fields = {}): void {
  // Sentry breadcrumb (always, for crash context)
  Sentry.addBreadcrumb({ category: message, data: fields, level });

  // Console output in dev only; stripped by babel-plugin-transform-remove-console in release
  if (isDev) {
    console[level](`[${level.toUpperCase()}] ${message}`, fields);
  }
}

export const logger = {
  debug: (msg: string, fields?: Fields) => log('debug', msg, fields),
  info:  (msg: string, fields?: Fields) => log('info',  msg, fields),
  warn:  (msg: string, fields?: Fields) => log('warn',  msg, fields),
  error: (msg: string, fields?: Fields) => log('error', msg, fields),
};
```

```ts
// Usage — correlation ID threaded through, PII redacted
import { logger } from '@/lib/logger';
import * as Sentry from '@sentry/react-native';
import { randomUUID } from 'expo-crypto';

async function placeOrder(userId: string, cartId: string): Promise<Order> {
  const traceId = randomUUID(); // ponytail: expo-crypto already installed; no extra dep
  logger.info('order.place.start', { traceId, userId, cartId });

  try {
    const order = await api.post('/orders', { cartId });
    logger.info('order.place.success', { traceId, userId, orderId: order.id }); // no PII, no payload dump
    return order;
  } catch (e) {
    logger.error('order.place.failed', { traceId, userId, cartId });
    Sentry.captureException(e, { tags: { traceId }, extra: { userId, cartId } });
    throw e; // propagate — never swallow
  }
}
```

### Wiring a metric counter + crash reporter at app entry

```ts
// app/_layout.tsx (Expo Router) or App.tsx
import * as Sentry from '@sentry/react-native';

// Initialize before root component renders
Sentry.init({
  dsn: process.env.EXPO_PUBLIC_SENTRY_DSN,
  environment: process.env.EXPO_PUBLIC_ENV ?? 'production',
  tracesSampleRate: 0.2,
  // ponytail: sample rate tunable in ctx/ per project
});

// Minimal metric helper using Sentry's custom metrics (GA as of SDK v5)
import { metrics } from '@sentry/react-native';

export function incrementCounter(name: string, tags?: Record<string, string>): void {
  metrics.increment(name, 1, { tags });
}

export function recordTiming(name: string, durationMs: number, tags?: Record<string, string>): void {
  metrics.distribution(name, durationMs, { unit: 'millisecond', tags });
}
```

```ts
// In a critical path — auth example
async function signIn(email: string, password: string): Promise<Session> {
  const t0 = Date.now();
  try {
    const session = await authClient.signIn({ email, password });
    incrementCounter('auth.signin.success');
    recordTiming('auth.signin.duration_ms', Date.now() - t0);
    logger.info('auth.signin.success', { userId: session.userId });
    return session;
  } catch (e) {
    incrementCounter('auth.signin.failure', { reason: classifyAuthError(e) });
    logger.error('auth.signin.failed', { reason: classifyAuthError(e) });
    Sentry.captureException(e, { extra: { step: 'signIn' } }); // no email logged
    throw e;
  }
}
```

---

## Rule-by-rule bad → good pairs

### 1. Debug print left in prod

```ts
// ❌ console.log everywhere — unstructured, ships to device syslog in release
async function fetchProfile(userId: string) {
  console.log('fetching profile for', userId);
  const data = await api.get(`/users/${userId}`);
  console.log('got profile', data);
  return data;
}
```

```ts
// ✅ shared logger; console.*  stripped from release by babel-plugin-transform-remove-console
// babel.config.js: env.production.plugins: [['transform-remove-console', { exclude: ['error'] }]]
import { logger } from '@/lib/logger';

async function fetchProfile(userId: string) {
  logger.debug('profile.fetch.start', { userId });
  const data = await api.get(`/users/${userId}`);
  logger.debug('profile.fetch.done', { userId });
  return data;
}
```

### 2. PII / secrets in logs

```ts
// ❌ full user object → email, phone, hashed password all logged
// ❌ Axios error config contains the Authorization header — forwarded raw to Sentry
logger.info('login success', { user });           // user = { email, phone, passwordHash, ... }
logger.error('api error', { error });             // error.config.headers.Authorization = 'Bearer sk-...'
Sentry.captureException(error);                   // error.config still has the token
```

```ts
// ✅ log only non-sensitive IDs; scrub Axios config before capturing
logger.info('auth.login.success', { userId: user.id, role: user.role }); // email/phone never logged

// Sanitize before capture — remove auth headers from Axios error
function captureApiError(e: unknown, context: Record<string, unknown>): void {
  if (isAxiosError(e) && e.config?.headers) {
    delete e.config.headers['Authorization'];
    delete e.config.headers['Cookie'];
  }
  Sentry.captureException(e, { extra: context });
}
captureApiError(error, { endpoint: '/login', userId: user?.id });
```

See [rn-security](../rn-security/SKILL.md) for the full PII/secrets policy.

### 3. Unstructured logging

```ts
// ❌ dynamic data embedded in the message string — unsearchable in any log aggregator
logger.info('User ' + userId + ' placed order ' + orderId + ' for $' + amount);
logger.warn(`Retry attempt ${attempt} for request ${requestId} after ${delay}ms`);
```

```ts
// ✅ message is a static event name; dynamic data is in the fields object
logger.info('order.placed', { userId, orderId, amountCents: amount });
logger.warn('api.retry', { attempt, requestId, delayMs: delay });
// Querying in Datadog/Kibana: filter by orderId="xyz" → instant; substring search on a string → not possible
```

### 4. Missing correlation / trace ID

```ts
// ❌ three log lines, all anonymous — impossible to reconstruct one user's checkout flow
async function checkout(cart: Cart) {
  logger.info('Starting checkout');
  const payment = await processPayment(cart);
  logger.info('Payment done');
  const order = await createOrder(cart, payment);
  logger.info('Order created');
}
```

```ts
// ✅ traceId generated once, threaded through every log line and error report
import { randomUUID } from 'expo-crypto';

async function checkout(cart: Cart) {
  const traceId = randomUUID();
  logger.info('checkout.start', { traceId, cartId: cart.id, userId: cart.userId });
  try {
    const payment = await processPayment(cart, traceId);
    logger.info('checkout.payment.done', { traceId, paymentId: payment.id });
    const order = await createOrder(cart, payment, traceId);
    logger.info('checkout.order.created', { traceId, orderId: order.id });
  } catch (e) {
    logger.error('checkout.failed', { traceId, cartId: cart.id });
    Sentry.captureException(e, { tags: { traceId } });
    throw e;
  }
}
```

### 5. Wrong log level

```ts
// ❌ error level for a 404 (expected outcome); info level for a real payment failure
logger.error('Product not found', { productId });   // 404 is expected — not an error
logger.info('Payment declined', { orderId });        // declined payment is a real failure worth alerting on
logger.error('User opted out of notifications');     // user action — definitely not error
```

```ts
// ✅ level matches actual severity
logger.info('product.not_found', { productId });     // expected; informational
logger.error('payment.declined', { orderId, reason: result.declineCode }); // real failure
logger.info('notifications.opt_out', { userId });    // user action — info

// Level guide:
// debug → verbose dev detail (stripped in prod)
// info  → normal business milestone
// warn  → degraded but recovered (retry succeeded, fallback used)
// error → actual failure that needs attention (alert-worthy)
```

### 6. Swallowed error

```ts
// ❌ empty catch — the failure happened and no one will ever know
try {
  await syncUserData(userId);
} catch {}

// ❌ catch logs a string, drops the stack and root cause
try {
  await processWebhook(payload);
} catch (e) {
  console.log('webhook failed');  // e is gone; stack is gone
}
```

```ts
// ✅ catch always logs the exception object (preserves stack) and reports if significant
try {
  await syncUserData(userId);
} catch (e) {
  // recoverable background sync — warn + report, don't rethrow
  logger.warn('sync.user_data.failed', { userId });
  Sentry.captureException(e, { extra: { userId, operation: 'syncUserData' } });
}

// ✅ critical path — log, report, rethrow so callers can handle
try {
  await processWebhook(payload);
} catch (e) {
  logger.error('webhook.process.failed', { webhookId: payload.id });
  Sentry.captureException(e, { extra: { webhookId: payload.id } });
  throw e;
}
```

### 7. Logging in hot path / loop

```ts
// ❌ per-item log inside FlatList renderItem — fires for every visible row on every re-render
const renderItem = ({ item }: { item: Product }) => {
  logger.debug('rendering product', { productId: item.id }); // 50 products = 50 log calls per render
  return <ProductCard product={item} />;
};

// ❌ per-frame log inside animation callback
const onFrame = () => {
  logger.debug('frame tick', { ts: Date.now() }); // 60fps = 60 calls/sec
  requestAnimationFrame(onFrame);
};
```

```ts
// ✅ log once at list load, not per item
useEffect(() => {
  logger.debug('product_list.rendered', { count: products.length });
}, [products.length]);

const renderItem = ({ item }: { item: Product }) => <ProductCard product={item} />;

// ✅ animation — sample or log only on state transitions, not every frame
const onFrame = () => {
  // no log here; instrument only on start/stop/error events
  requestAnimationFrame(onFrame);
};
```

### 8. No metrics (logs only)

```ts
// ❌ detailed logs, zero metrics — no alert possible on failure-rate spike
async function chargeCard(orderId: string, amountCents: number): Promise<Receipt> {
  logger.info('charge.start', { orderId, amountCents });
  try {
    const receipt = await stripe.charge({ orderId, amountCents });
    logger.info('charge.success', { orderId, receiptId: receipt.id });
    return receipt;
  } catch (e) {
    logger.error('charge.failed', { orderId });
    throw e;
  }
}
```

```ts
// ✅ counter + timing on the critical path — now alertable
import { incrementCounter, recordTiming } from '@/lib/metrics'; // thin wrapper from the entry-point example

async function chargeCard(orderId: string, amountCents: number): Promise<Receipt> {
  const t0 = Date.now();
  logger.info('charge.start', { orderId, amountCents });
  try {
    const receipt = await stripe.charge({ orderId, amountCents });
    incrementCounter('payment.charge.success');
    recordTiming('payment.charge.duration_ms', Date.now() - t0);
    logger.info('charge.success', { orderId, receiptId: receipt.id });
    return receipt;
  } catch (e) {
    incrementCounter('payment.charge.failure', { type: classifyError(e) });
    logger.error('charge.failed', { orderId });
    Sentry.captureException(e, { extra: { orderId } });
    throw e;
  }
}
```

### 9. Missing crash / error reporting

```ts
// ❌ No crash reporter initialized — all native crashes and unhandled JS rejections are silent
// App.tsx with no Sentry.init / Crashlytics call anywhere

// ❌ Handled error console.error'd and forgotten — never reaches Sentry
try {
  await submitPayment(order);
} catch (e) {
  console.error('Payment failed', e); // visible in Metro; invisible in production
  showToast('Payment failed. Please try again.');
}
```

```ts
// ✅ Sentry initialized at app entry, before any component mounts
// app/_layout.tsx
import * as Sentry from '@sentry/react-native';

Sentry.init({
  dsn: process.env.EXPO_PUBLIC_SENTRY_DSN,
  environment: process.env.EXPO_PUBLIC_ENV ?? 'production',
  tracesSampleRate: 0.1,
});

export default function RootLayout() { /* ... */ }

// ✅ Handled failures in critical paths forwarded explicitly
try {
  await submitPayment(order);
} catch (e) {
  logger.error('payment.submit.failed', { orderId: order.id });
  Sentry.captureException(e, {
    tags: { flow: 'checkout' },
    extra: { orderId: order.id, amountCents: order.total },
  });
  showToast('Payment failed. Please try again.');
}
```

### 10. Non-actionable message

```ts
// ❌ bare strings — useless to an on-call engineer at 3am
logger.error('Request failed');
logger.error('Something went wrong');
Sentry.captureException(e); // no context attached
logger.warn('Error'); // not even a level-appropriate message
```

```ts
// ✅ every log/report answers: what failed, which entity, what state, what next
logger.error('api.request.failed', {
  endpoint: '/api/v2/orders',
  method: 'POST',
  statusCode: 503,
  orderId,
  userId,
  retryable: true,
});

Sentry.captureException(e, {
  tags: { flow: 'order-creation', endpoint: '/api/v2/orders' },
  user: { id: userId },           // Sentry user context — no PII beyond ID
  extra: { orderId, statusCode: 503, retryable: true },
});

// On-call can now answer: which endpoint, which order, which user, whether to retry.
```

---

## Official references

- Sentry React Native: https://docs.sentry.io/platforms/react-native/
- Sentry custom metrics: https://docs.sentry.io/product/metrics/
- Firebase Crashlytics (RN via rnfirebase.io): https://rnfirebase.io/crashlytics/usage
- babel-plugin-transform-remove-console: https://babeljs.io/docs/babel-plugin-transform-remove-console
- expo-crypto (randomUUID): https://docs.expo.dev/versions/latest/sdk/crypto/
- React Native performance: https://reactnative.dev/docs/performance
- OWASP A09 — Security Logging and Monitoring Failures: https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/
- Team baseline: [../../guidance.md](../../guidance.md)
- Security guard (PII/secrets depth): [rn-security](../rn-security/SKILL.md)

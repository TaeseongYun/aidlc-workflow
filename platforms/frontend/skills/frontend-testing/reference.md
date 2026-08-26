# frontend-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per guard
rule, plus Mode-A generation examples. TypeScript + React / Vitest /
`@testing-library/react` / MSW. Decision criteria live in `SKILL.md`.

---

## Mode A — Generation examples

### Good unit test: injected clock + faked network

```tsx
// src/components/CountdownBanner.test.tsx
import { render, screen } from '@testing-library/react';
import { server } from '../mocks/server';              // MSW node server
import { http, HttpResponse } from 'msw';
import { CountdownBanner } from './CountdownBanner';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('CountdownBanner', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    // Pin "now" to a known instant so the countdown is deterministic
    vi.setSystemTime(new Date('2025-01-01T00:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  it('shows the remaining days until the deadline', async () => {
    server.use(
      http.get('/api/campaign', () =>
        HttpResponse.json({ deadline: '2025-01-08T00:00:00Z' }),
      ),
    );

    render(<CountdownBanner />);

    // waitFor handles the async data fetch
    expect(await screen.findByRole('status')).toHaveTextContent('7 days left');
  });

  it('shows "Expired" when the deadline has passed', async () => {
    server.use(
      http.get('/api/campaign', () =>
        HttpResponse.json({ deadline: '2024-12-31T00:00:00Z' }),
      ),
    );

    render(<CountdownBanner />);

    expect(await screen.findByRole('status')).toHaveTextContent('Expired');
  });
});
```

### Good error-path test: network failure + loading state

```tsx
// src/components/UserProfile.test.tsx
import { render, screen } from '@testing-library/react';
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';
import { UserProfile } from './UserProfile';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('UserProfile', () => {
  it('renders the loading skeleton while fetching', () => {
    // Server never responds during this synchronous assertion
    server.use(http.get('/api/user/:id', () => new Promise(() => {})));

    render(<UserProfile userId="42" />);

    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('shows an error message when the request fails', async () => {
    server.use(
      http.get('/api/user/:id', () =>
        HttpResponse.json({ message: 'Not found' }, { status: 404 }),
      ),
    );

    render(<UserProfile userId="42" />);

    expect(
      await screen.findByRole('alert'),
    ).toHaveTextContent('Failed to load profile');
  });

  it('renders the user name on success', async () => {
    server.use(
      http.get('/api/user/:id', () =>
        HttpResponse.json({ name: 'Alice', email: 'alice@example.com' }),
      ),
    );

    render(<UserProfile userId="42" />);

    expect(await screen.findByRole('heading', { name: 'Alice' })).toBeInTheDocument();
  });
});
```

---

## Guard rules — bad → good

### 1. Assertion-free test

```tsx
// ❌ Renders the component, calls the handler — asserts nothing
it('submits the form', async () => {
  const user = userEvent.setup();
  render(<LoginForm />);
  await user.type(screen.getByLabelText('Email'), 'a@b.com');
  await user.click(screen.getByRole('button', { name: 'Sign in' }));
  // no expect — this test always passes, proves nothing
});

// ✅ Asserts the observable outcome of the submit
it('navigates to /dashboard after successful sign-in', async () => {
  const user = userEvent.setup();
  server.use(
    http.post('/api/auth/login', () => HttpResponse.json({ ok: true })),
  );
  render(<LoginForm />, { wrapper: RouterWrapper });
  await user.type(screen.getByLabelText('Email'), 'a@b.com');
  await user.type(screen.getByLabelText('Password'), 'secret');
  await user.click(screen.getByRole('button', { name: 'Sign in' }));

  expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
});
```

---

### 2. Mock-echo / tautological

```ts
// ❌ Asserts the mock returns what it was told to return — tests nothing
import { getUser } from './userService';
vi.mock('./userService');

it('returns user data', async () => {
  vi.mocked(getUser).mockResolvedValue({ id: 1, name: 'Alice' });
  const result = await getUser(1);
  expect(result).toEqual({ id: 1, name: 'Alice' }); // tautology
});

// ✅ Test the code that CALLS getUser; mock the service, assert the component output
import { render, screen } from '@testing-library/react';
import { UserCard } from './UserCard';
import { getUser } from './userService';
vi.mock('./userService');

it('displays the user name fetched from the service', async () => {
  vi.mocked(getUser).mockResolvedValue({ id: 1, name: 'Alice' });
  render(<UserCard userId={1} />);
  expect(await screen.findByText('Alice')).toBeInTheDocument();
  // Asserts the component correctly consumes the service response
});
```

---

### 3. Over-mocking / mocking the SUT

```tsx
// ❌ Mocks the very component being tested — the test exercises nothing
vi.mock('./SearchInput');  // file: SearchInput.test.tsx

it('renders SearchInput', () => {
  vi.mocked(SearchInput).mockReturnValue(<div>mocked</div>);
  render(<SearchInput />);
  expect(screen.getByText('mocked')).toBeInTheDocument(); // tests the mock itself
});

// ✅ Render SearchInput directly; mock only its external dependencies
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';

it('shows suggestions after typing', async () => {
  const user = userEvent.setup();
  server.use(
    http.get('/api/search', () =>
      HttpResponse.json(['apple', 'apricot']),
    ),
  );
  render(<SearchInput />);
  await user.type(screen.getByRole('searchbox'), 'ap');

  expect(await screen.findByRole('listbox')).toBeInTheDocument();
  expect(screen.getAllByRole('option')).toHaveLength(2);
});
```

---

### 4. Implementation-detail coupling

```tsx
// ❌ Asserts internal call order / spy on private helper
import * as utils from './dateUtils';

it('formats the date correctly', () => {
  const spy = vi.spyOn(utils, '_parseRaw'); // private helper
  render(<EventCard date="2025-06-01" />);
  expect(spy).toHaveBeenCalledWith('2025-06-01'); // internal detail
});

// ✅ Assert what the user sees — the rendered output
it('displays the formatted date', () => {
  render(<EventCard date="2025-06-01" />);
  // Observable: the text the user reads, not how it was computed
  expect(screen.getByText('June 1, 2025')).toBeInTheDocument();
});
```

---

### 5. Non-determinism / flakiness

```ts
// ❌ Real clock — fails in a different timezone, on Jan 1, or in 2026
it('shows the correct year in the footer', () => {
  render(<Footer />);
  expect(screen.getByText(String(new Date().getFullYear()))).toBeInTheDocument();
});

// ❌ Real sleep — slow, order-dependent, still flaky under load
it('hides the toast after 3 seconds', async () => {
  render(<Toast message="Saved" />);
  await new Promise((r) => setTimeout(r, 3100)); // real wall-clock wait
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
});

// ✅ Fake timers — deterministic, instant
it('shows the year 2025 in the footer', () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2025-03-15'));
  render(<Footer />);
  expect(screen.getByText('2025')).toBeInTheDocument();
  vi.useRealTimers();
});

it('hides the toast after the auto-dismiss delay', () => {
  vi.useFakeTimers();
  render(<Toast message="Saved" durationMs={3000} />);
  expect(screen.getByRole('status')).toBeInTheDocument();
  vi.advanceTimersByTime(3000);
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
  vi.useRealTimers();
});
```

---

### 6. Happy-path only

```tsx
// ❌ Only the success case — ignores the error + loading branches
it('renders the product list', async () => {
  server.use(
    http.get('/api/products', () =>
      HttpResponse.json([{ id: 1, name: 'Widget' }]),
    ),
  );
  render(<ProductList />);
  expect(await screen.findByText('Widget')).toBeInTheDocument();
});

// ✅ Also cover loading, error, and empty states
it('shows a skeleton while loading', () => {
  server.use(http.get('/api/products', () => new Promise(() => {})));
  render(<ProductList />);
  expect(screen.getByRole('progressbar')).toBeInTheDocument();
});

it('shows an error alert when the request fails', async () => {
  server.use(
    http.get('/api/products', () =>
      HttpResponse.json({ message: 'Server error' }, { status: 500 }),
    ),
  );
  render(<ProductList />);
  expect(await screen.findByRole('alert')).toHaveTextContent('Failed to load products');
});

it('shows an empty-state message when no products exist', async () => {
  server.use(http.get('/api/products', () => HttpResponse.json([])));
  render(<ProductList />);
  expect(await screen.findByText('No products found')).toBeInTheDocument();
});
```

---

### 7. Snapshot abuse

```tsx
// ❌ Giant snapshot as the only assertion — any markup change breaks CI,
//    and the reviewer auto-updates without reading
it('renders the checkout page', () => {
  const { container } = render(<CheckoutPage cart={mockCart} />);
  expect(container).toMatchSnapshot(); // 400-line snapshot, sole assertion
});

// ✅ Small snapshot on a stable, narrow fragment + behavioral assertions
it('renders the order total', () => {
  render(<OrderSummary subtotal={99.99} tax={8.5} />);
  // Behavioral assertion — what the user reads
  expect(screen.getByText('$108.49')).toBeInTheDocument();
});

it('formats the order summary label correctly', () => {
  // Snapshot only for a small, pure formatting output
  expect(formatOrderLabel({ subtotal: 99.99, tax: 8.5 })).toMatchInlineSnapshot(
    `"Subtotal $99.99 + Tax $8.50 = $108.49"`,
  );
});
```

---

### 8. Smuggled skip / disable

```tsx
// ❌ Skip with no explanation — silently removes test coverage
it.skip('submits the form when Enter is pressed', async () => {
  // ...
});

xdescribe('PaymentForm edge cases', () => {
  // all tests in here silently disabled
});

// ✅ Skip with a reason and a ticket so it can be un-skipped
it.skip(
  'submits the form when Enter is pressed',
  // TODO(#1234): flaky in CI due to jsdom focus model — re-enable after Playwright migration
  async () => {
    // ...
  },
);
```

---

### 9. Copy-paste clone

```tsx
// ❌ Different names, identical bodies — one scenario covered, one name lying
it('shows an error for an invalid email', async () => {
  const user = userEvent.setup();
  render(<SignupForm />);
  await user.type(screen.getByLabelText('Email'), 'not-an-email');
  await user.click(screen.getByRole('button', { name: 'Sign up' }));
  expect(await screen.findByRole('alert')).toBeInTheDocument();
});

it('shows an error for a missing password', async () => {
  const user = userEvent.setup();
  render(<SignupForm />);
  await user.type(screen.getByLabelText('Email'), 'not-an-email'); // ← copy-paste, still email input
  await user.click(screen.getByRole('button', { name: 'Sign up' }));
  expect(await screen.findByRole('alert')).toBeInTheDocument(); // same assert
});

// ✅ Each test exercises its own distinct scenario
it('shows a validation error for an invalid email format', async () => {
  const user = userEvent.setup();
  render(<SignupForm />);
  await user.type(screen.getByLabelText('Email'), 'not-an-email');
  await user.click(screen.getByRole('button', { name: 'Sign up' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email');
});

it('shows a validation error when password is empty', async () => {
  const user = userEvent.setup();
  render(<SignupForm />);
  await user.type(screen.getByLabelText('Email'), 'alice@example.com');
  // Password field intentionally left empty
  await user.click(screen.getByRole('button', { name: 'Sign up' }));
  expect(await screen.findByRole('alert')).toHaveTextContent('Password is required');
});
```

---

### 10. Coverage theater

```tsx
// ❌ Exercises the import path, inflates line coverage, asserts nothing meaningful
it('does not throw', () => {
  expect(() => render(<DataTable rows={[]} />)).not.toThrow();
  // 100% line coverage on DataTable, zero behavioral value
});

// ❌ toBeDefined on a trivially-defined export
import { formatCurrency } from './formatCurrency';
it('formatCurrency is defined', () => {
  expect(formatCurrency).toBeDefined(); // no behavior tested
});

// ✅ Assert observable behavior — output that could realistically differ
import { formatCurrency } from './formatCurrency';

it('formats a positive amount with two decimal places', () => {
  expect(formatCurrency(1234.5, 'USD')).toBe('$1,234.50');
});

it('formats zero as $0.00', () => {
  expect(formatCurrency(0, 'USD')).toBe('$0.00');
});

it('renders DataTable with a row for each item', () => {
  render(<DataTable rows={[{ id: 1, name: 'Alpha' }, { id: 2, name: 'Beta' }]} />);
  expect(screen.getAllByRole('row')).toHaveLength(3); // 2 data rows + header
  expect(screen.getByRole('cell', { name: 'Alpha' })).toBeInTheDocument();
});
```

---

## MSW setup boilerplate (reference)

```ts
// src/mocks/server.ts
import { setupServer } from 'msw/node';
export const server = setupServer();

// src/mocks/handlers.ts  — default handlers (happy-path baseline)
import { http, HttpResponse } from 'msw';
export const handlers = [
  http.get('/api/user/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, name: 'Alice' }),
  ),
];

// vitest.setup.ts
import { server } from './src/mocks/server';
import { handlers } from './src/mocks/handlers';
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
beforeEach(() => server.use(...handlers));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: 'error'` ensures no test silently reaches the real network.

---

## Official references

- Testing Library — query priority: https://testing-library.com/docs/queries/about#priority
- user-event v14: https://testing-library.com/docs/user-event/intro
- MSW v2: https://mswjs.io/docs/
- Vitest fake timers: https://vitest.dev/guide/mocking#timers
- Playwright: https://playwright.dev/docs/intro
- Team baseline: [../../guidance.md](../../guidance.md)

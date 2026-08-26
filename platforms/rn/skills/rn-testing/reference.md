# rn-testing — Reference

Deep-dive material for `SKILL.md`. **Bad (❌) vs good (✅)** code samples per
guard rule, plus Mode A generation examples. TypeScript + React Native,
using Jest, `@testing-library/react-native`, and MSW. Decision criteria live
in `SKILL.md`.

---

## Guard rules — bad → good pairs

### Rule 1 — Assertion-free test

```tsx
// ❌ Renders, calls nothing, asserts nothing real
it('renders UserCard', () => {
  render(<UserCard user={{ id: 1, name: 'Alice' }} />);
  // no expect — this test will always pass regardless of what is rendered
});

// ✅ Assert what the user actually sees
it('renders the user name', () => {
  render(<UserCard user={{ id: 1, name: 'Alice' }} />);
  expect(screen.getByText('Alice')).toBeTruthy();
});
```

---

### Rule 2 — Mock-echo / tautological assertion

```ts
// ❌ Asserts the stub's own return value — verifies nothing
jest.mock('../api/userApi');
const { fetchUser } = require('../api/userApi');
fetchUser.mockResolvedValue({ id: 1, name: 'Alice' });

it('fetches a user', async () => {
  const result = await fetchUser(1);
  expect(result.name).toBe('Alice'); // just echoes the mock — no real logic tested
});

// ✅ Test the component/hook that USES fetchUser; assert the rendered output
import { renderHook, waitFor } from '@testing-library/react-native';
import { useUser } from '../hooks/useUser';
import { server } from '../mocks/server'; // MSW
import { http, HttpResponse } from 'msw';

it('displays the user name after fetch', async () => {
  server.use(
    http.get('/api/users/1', () => HttpResponse.json({ id: 1, name: 'Alice' }))
  );
  render(<ProfileScreen userId={1} />);
  expect(await screen.findByText('Alice')).toBeTruthy();
  // findByText waits for async render — the assertion is on visible output, not the stub value
});
```

---

### Rule 3 — Over-mocking / mocking the SUT

```tsx
// ❌ Mocks the very component being tested — the test covers a mock, not the component
jest.mock('../components/LoginForm');
const MockLoginForm = require('../components/LoginForm');
MockLoginForm.mockImplementation(() => <View testID="mock-form" />);

it('LoginForm renders', () => {
  render(<LoginForm />);
  expect(screen.getByTestId('mock-form')).toBeTruthy(); // testing the mock, not LoginForm
});

// ✅ Mock only LoginForm's DEPENDENCIES; render the real component
jest.mock('../api/authApi', () => ({
  login: jest.fn(),
}));
import { login } from '../api/authApi';

it('calls login with entered credentials', async () => {
  (login as jest.Mock).mockResolvedValue({ token: 'tok' });
  render(<LoginForm />);
  fireEvent.changeText(screen.getByLabelText('Email'), 'user@example.com');
  fireEvent.changeText(screen.getByLabelText('Password'), 'secret');
  fireEvent.press(screen.getByRole('button', { name: 'Sign in' }));
  await waitFor(() => expect(login).toHaveBeenCalledWith('user@example.com', 'secret'));
});
```

---

### Rule 4 — Implementation-detail coupling

```tsx
// ❌ Spies on a private helper; asserts internal call order
import * as utils from '../utils/formatDate';

it('formats date internally', () => {
  const spy = jest.spyOn(utils, '_formatISO'); // private helper
  render(<EventCard date="2024-01-15" />);
  expect(spy).toHaveBeenCalledWith('2024-01-15'); // brittle: breaks on refactor
});

// ✅ Assert the formatted date visible to the user
it('displays the formatted date', () => {
  render(<EventCard date="2024-01-15" />);
  expect(screen.getByText('Jan 15, 2024')).toBeTruthy();
  // implementation of _formatISO is irrelevant — only the output matters
});
```

---

### Rule 5 — Non-determinism / flakiness

```ts
// ❌ Real Date.now() in the assertion; real setTimeout as a wait
it('shows a timestamp', async () => {
  render(<TimestampLabel />);
  await new Promise((r) => setTimeout(r, 500)); // flaky wait — CI timing varies
  const now = Date.now(); // non-deterministic
  expect(screen.getByText(String(now))).toBeTruthy(); // will never match
});

// ✅ Fake timers; freeze the clock; use waitFor
beforeEach(() => {
  jest.useFakeTimers();
  jest.setSystemTime(new Date('2024-01-15T12:00:00Z'));
});
afterEach(() => {
  jest.useRealTimers();
});

it('shows the frozen timestamp', async () => {
  render(<TimestampLabel />);
  jest.runAllTimers(); // flush any internal setInterval/setTimeout
  await waitFor(() =>
    expect(screen.getByText('Jan 15, 2024, 12:00')).toBeTruthy()
  );
});
```

---

### Rule 6 — Happy-path only

```tsx
// ❌ Only tests the success path; error branch is never exercised
it('shows user profile on success', async () => {
  server.use(http.get('/api/profile', () => HttpResponse.json({ name: 'Alice' })));
  render(<ProfileScreen />);
  expect(await screen.findByText('Alice')).toBeTruthy();
});
// network error? null user? loading state? — none covered

// ✅ Also test error and edge cases
it('shows an error message when the request fails', async () => {
  server.use(http.get('/api/profile', () => HttpResponse.error()));
  render(<ProfileScreen />);
  expect(await screen.findByRole('alert')).toBeTruthy();
  expect(screen.getByText(/failed to load/i)).toBeTruthy();
});

it('shows a loading indicator while fetching', () => {
  // server handler is slow — render immediately and check loading state
  server.use(http.get('/api/profile', async () => {
    await new Promise(() => {}); // never resolves in this test
  }));
  render(<ProfileScreen />);
  expect(screen.getByRole('progressbar')).toBeTruthy();
});
```

---

### Rule 7 — Snapshot abuse

```tsx
// ❌ Entire screen captured as a snapshot — any style change fails the test
it('renders SettingsScreen', () => {
  const tree = render(<SettingsScreen />).toJSON();
  expect(tree).toMatchSnapshot(); // 400-line .snap — unmaintainable
});

// ✅ Assert semantics, not the full tree; keep snapshots for small, stable shapes only
it('renders section headers in SettingsScreen', () => {
  render(<SettingsScreen />);
  expect(screen.getByText('Account')).toBeTruthy();
  expect(screen.getByText('Notifications')).toBeTruthy();
  expect(screen.getByText('Privacy')).toBeTruthy();
});

// If a snapshot IS appropriate (e.g., a small icon component), keep it narrow:
it('matches NotificationBadge snapshot', () => {
  const { toJSON } = render(<NotificationBadge count={3} />);
  expect(toJSON()).toMatchSnapshot(); // ~10 lines, intentionally reviewed
});
```

---

### Rule 8 — Smuggled skip / disable

```ts
// ❌ Silent skip with no reason — hidden failure
it.skip('handles token refresh on 401', async () => {
  // TODO: figure out how to mock this
  // ...
});

// ✅ If you must skip, explain why with a ticket
it.skip('handles token refresh on 401', async () => {
  // ponytail: skipped — MSW v2 interceptor for RN fetch not yet wired
  // Re-enable after: https://github.com/example/repo/issues/432
});
// Better: make it pass before merging, or open the ticket and do not commit the skip
```

---

### Rule 9 — Copy-paste clone

```ts
// ❌ Two tests with identical stubs and assertions under different names
it('returns user data for admin', async () => {
  (fetchUser as jest.Mock).mockResolvedValue({ id: 1, role: 'admin' });
  const result = await fetchUser(1);
  expect(result.role).toBe('admin'); // mock-echo AND a clone of the test below
});

it('returns user data for viewer', async () => {
  (fetchUser as jest.Mock).mockResolvedValue({ id: 1, role: 'admin' }); // forgot to change
  const result = await fetchUser(1);
  expect(result.role).toBe('admin'); // identical — tests nothing different
});

// ✅ Each case stubs and asserts a distinct value
it('navigates to AdminDashboard for admin role', async () => {
  server.use(http.get('/api/me', () => HttpResponse.json({ id: 1, role: 'admin' })));
  render(<AppNavigator />);
  expect(await screen.findByText('Admin Dashboard')).toBeTruthy();
});

it('navigates to Home for viewer role', async () => {
  server.use(http.get('/api/me', () => HttpResponse.json({ id: 2, role: 'viewer' })));
  render(<AppNavigator />);
  expect(await screen.findByText('Home')).toBeTruthy();
});
```

---

### Rule 10 — Coverage theater

```tsx
// ❌ Loops through every status, asserts only toBeTruthy() — inflates coverage, verifies nothing
const statuses = ['pending', 'active', 'suspended'] as const;
statuses.forEach((status) => {
  it(`renders for status ${status}`, () => {
    render(<AccountBadge status={status} />);
    expect(screen.toJSON()).toBeTruthy(); // any output passes — this is theater
  });
});

// ✅ Assert the correct label and color per status
it('shows "Pending review" badge for pending status', () => {
  render(<AccountBadge status="pending" />);
  expect(screen.getByText('Pending review')).toBeTruthy();
  expect(screen.getByRole('status')).toHaveStyle({ backgroundColor: '#FFA500' });
});

it('shows "Active" badge for active status', () => {
  render(<AccountBadge status="active" />);
  expect(screen.getByText('Active')).toBeTruthy();
  expect(screen.getByRole('status')).toHaveStyle({ backgroundColor: '#22C55E' });
});
```

---

## Mode A — Generation examples

### Example 1 — Unit test with injected clock and MSW network

A hook that fetches a greeting and appends a formatted timestamp. Demonstrates
fake timers, MSW for network, and behavior-first RNTL query.

```tsx
// hooks/useGreeting.ts (under test)
export function useGreeting(userId: number) {
  const [greeting, setGreeting] = React.useState<string | null>(null);
  const [error, setError] = React.useState(false);

  React.useEffect(() => {
    fetch(`/api/greeting/${userId}`)
      .then((r) => r.json())
      .then(({ message }) => {
        const stamp = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        setGreeting(`${message} — ${stamp}`);
      })
      .catch(() => setError(true));
  }, [userId]);

  return { greeting, error };
}
```

```tsx
// hooks/useGreeting.test.ts
import { renderHook, waitFor } from '@testing-library/react-native';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server';
import { useGreeting } from './useGreeting';

describe('useGreeting', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-03-05T00:00:00Z')); // freeze: Mar 5, 2024
  });
  afterEach(() => {
    jest.useRealTimers();
  });

  it('returns the greeting with the frozen date appended', async () => {
    server.use(
      http.get('/api/greeting/42', () =>
        HttpResponse.json({ message: 'Hello, Alice' })
      )
    );
    const { result } = renderHook(() => useGreeting(42));
    await waitFor(() => expect(result.current.greeting).not.toBeNull());
    expect(result.current.greeting).toBe('Hello, Alice — Mar 5, 2024');
    // The frozen clock means this assertion is deterministic in any environment.
  });

  it('sets error to true when the request fails', async () => {
    server.use(http.get('/api/greeting/42', () => HttpResponse.error()));
    const { result } = renderHook(() => useGreeting(42));
    await waitFor(() => expect(result.current.error).toBe(true));
    expect(result.current.greeting).toBeNull();
  });
});
```

---

### Example 2 — Component test with native module mock and error path

A screen that reads a value from `expo-secure-store` (a native module) and
displays it. Demonstrates mocking the native module globally, testing both the
happy path and the unavailable-storage error path.

```tsx
// jest.setup.js  — mock once; every test file gets this automatically
jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));
```

```tsx
// screens/TokenDebugScreen.test.tsx
import React from 'react';
import { render, screen, waitFor } from '@testing-library/react-native';
import * as SecureStore from 'expo-secure-store';
import { TokenDebugScreen } from './TokenDebugScreen';

const mockGetItem = SecureStore.getItemAsync as jest.Mock;

describe('TokenDebugScreen', () => {
  beforeEach(() => {
    jest.clearAllMocks(); // reset call history; never carry state between tests
  });

  it('displays the stored token when SecureStore returns a value', async () => {
    mockGetItem.mockResolvedValue('tok_abc123');
    render(<TokenDebugScreen />);
    expect(await screen.findByText('Token: tok_abc123')).toBeTruthy();
  });

  it('displays "No token found" when SecureStore returns null', async () => {
    mockGetItem.mockResolvedValue(null);
    render(<TokenDebugScreen />);
    expect(await screen.findByText('No token found')).toBeTruthy();
  });

  it('displays an error message when SecureStore throws', async () => {
    mockGetItem.mockRejectedValue(new Error('Keychain unavailable'));
    render(<TokenDebugScreen />);
    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(screen.getByText(/could not read token/i)).toBeTruthy();
  });
});
```

---

## MSW server setup (minimal, for reference)

```ts
// mocks/server.ts
import { setupServer } from 'msw/native';
export const server = setupServer();

// jest.setup.js additions:
// import { server } from './mocks/server';
// beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
// afterEach(() => server.resetHandlers());
// afterAll(() => server.close());
```

`onUnhandledRequest: 'error'` ensures any fetch that slips through an unmocked
handler fails the test immediately instead of hanging silently.

---

## Official references

- Testing Library React Native: https://callstack.github.io/react-native-testing-library/
- Jest fake timers: https://jestjs.io/docs/timer-mocks
- MSW React Native integration: https://mswjs.io/docs/integrations/react-native
- Detox: https://wix.github.io/Detox/
- Maestro: https://maestro.mobile.dev/
- Team baseline: [../../guidance.md](../../guidance.md)

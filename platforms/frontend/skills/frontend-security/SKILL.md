---
name: frontend-security
description: Frontend (web) security guard — a safety guard that reviews and blocks the vulnerable patterns that commonly slip into AI-generated web code produced by "vibe coding". Covers XSS via dangerouslySetInnerHTML / unsanitized HTML / javascript: URLs, secrets leaking into the client bundle (NEXT_PUBLIC_/VITE_ are public by definition), auth-token storage in localStorage vs httpOnly cookies, missing CSRF protection / SameSite, open redirects from user-controlled URLs, unsafe postMessage / window.opener, SSRF and injection in server actions & route handlers, prototype pollution / unsafe deserialization, and vulnerable or hallucinated (slopsquatting) npm dependencies. Auto-loads when writing or reviewing web source, config, env, middleware, or route handlers. This is the vibe-coding security guard for AI-generated frontend code.
when_to_use: When reviewing web/TS/React code before merge (especially AI/LLM-generated or quickly pasted), when touching innerHTML/redirects/tokens/env/cookies/postMessage/server actions/route handlers/dependencies, or on requests like "security review", "is this safe", "vibe coding check".
paths: **/*.tsx, **/*.ts, **/*.jsx, **/*.js, **/next.config.*, **/middleware.ts, **/app/**/route.ts, **/app/**/actions.ts, **/.env*
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-security — vibe-coding security guard

AI-generated web code is **fast but frequently vulnerable**, and the frontend runs
in a hostile environment where anything shipped to the browser is inspectable.
Empirical studies find a large share of AI-generated code contains security
flaws, and AI-assisted commits leak secrets more often than human-only ones.
Developers also **overtrust** AI code. This skill is the **review gate**. The rules
here are **safety rules** and must not be relaxed. Project `ctx/` overrides this
document, but the security floor is never lowered.

## Scope

- Targets: web source (TS/JS/React), config (`next.config`, env), `middleware.ts`,
  route handlers / server actions — especially AI-generated or quickly-pasted code.
- What it does: **detect vulnerable patterns → propose safe alternatives** for each
  failure mode below.
- Delegate: response typing/validation → [frontend-api-contract], redirect/route
  handling detail → [frontend-architecture].
- Scope note: these are the **client-side** failure modes — at-rest encryption
  and server-side info-disclosure live in the backend security guard.
- Reality: **the client bundle is public** — any secret, key, or "hidden" logic
  shipped to the browser is readable. Secrets and trust decisions belong on the server.

## Core Rules — by AI-generated-code failure mode (must not be relaxed)

Each item: **rule → the failure AI commonly produces → red-flag**. Code examples in [reference.md](./reference.md).

### 1. XSS — unsanitized HTML / URLs (CWE-79 · OWASP A03)

- **Rule**: never render user/untrusted content as HTML. Avoid
  `dangerouslySetInnerHTML`; if HTML is unavoidable, **sanitize** (DOMPurify) first.
  Block `javascript:`/`data:` in user-supplied `href`/`src`.
- **Common AI failure**: `dangerouslySetInnerHTML={{ __html: userInput }}`,
  `el.innerHTML = value`, putting a user string into `href` unchecked.
- **red-flag**: `dangerouslySetInnerHTML` with non-constant input, `innerHTML =`,
  `href={userValue}` with no scheme check.

### 2. Secrets in the client bundle (CWE-798 · OWASP A02/A05)

- **Rule**: secrets never reach the browser. `NEXT_PUBLIC_`/`VITE_`-prefixed vars
  are **public by definition** — API keys, tokens, DB URLs must stay server-only
  (route handler / server action / server component). Privileged 3rd-party calls
  are proxied server-side.
- **Common AI failure**: `NEXT_PUBLIC_API_SECRET`, calling a private API with a key
  straight from a client component, committing `.env`.
- **red-flag**: a secret behind a `NEXT_PUBLIC_`/`VITE_` name, a key referenced in
  a client component, a tracked `.env`.

### 3. Token storage / session (CWE-522/922 · OWASP A07)

- **Rule**: prefer **httpOnly, Secure, SameSite cookies** for session tokens (not
  reachable by JS → XSS can't steal them). `localStorage` tokens are readable by
  any script; avoid for sensitive tokens.
- **Common AI failure**: `localStorage.setItem('token', jwt)`, storing refresh
  tokens in JS-accessible storage.
- **red-flag**: auth/refresh token in `localStorage`/`sessionStorage`, non-httpOnly
  session cookie.

### 4. CSRF / cookie safety (CWE-352 · OWASP A01)

- **Rule**: state-changing requests using cookie auth need CSRF defense
  (SameSite=Lax/Strict + token, or the framework's built-in protection). Set
  `Secure` + `SameSite` on auth cookies.
- **Common AI failure**: cookie session with no CSRF token and `SameSite=None`,
  mutations over GET.
- **red-flag**: cookie-authed POST with no CSRF protection, `SameSite=None` without
  reason, state change on a GET.

### 5. Open redirect / unsafe navigation (CWE-601 · OWASP A01)

- **Rule**: never redirect to a user-controlled URL without an **allowlist** (or
  restrict to same-origin/relative paths). Applies to `?next=`, `redirect()`,
  `window.location = param`.
- **Common AI failure**: `redirect(searchParams.get('next'))`,
  `window.location.href = returnUrl` from a query param.
- **red-flag**: a redirect target taken directly from user input.

### 6. Unsafe `postMessage` / `window.opener` (CWE-346 · OWASP A05)

- **Rule**: `postMessage` sets a specific `targetOrigin` (never `*` for sensitive
  data) and the receiver **checks `event.origin`**. External `target="_blank"`
  links use `rel="noopener noreferrer"`.
- **Common AI failure**: `postMessage(data, '*')`, a message handler with no origin
  check, `target="_blank"` without `noopener`.
- **red-flag**: `postMessage(..., '*')`, `onmessage` with no `event.origin` check,
  `_blank` without `noopener`.

### 7. SSRF / injection in server code (CWE-918/89/78 · OWASP A03/A10)

- **Rule**: route handlers & server actions are a **trust boundary** — validate all
  input, parameterize DB queries, and for user-supplied URLs use a host allowlist
  + block internal/metadata IPs. Server actions authorize the caller.
- **Common AI failure**: `fetch(userUrl)` in a route handler, string-built SQL in a
  server action, an unauthenticated server action mutating data.
- **red-flag**: user URL fetched server-side unvalidated, string-concatenated query,
  server action with no auth check.

### 8. Prototype pollution / unsafe deserialization (CWE-1321/502)

- **Rule**: don't deep-merge untrusted objects into targets (guard `__proto__`/
  `constructor`/`prototype`), don't `eval`/`Function(userInput)`, parse JSON into
  validated shapes → [frontend-api-contract].
- **Common AI failure**: a naive recursive merge of request data, `eval(userInput)`,
  `JSON.parse` then trusting the shape.
- **red-flag**: deep-merge of untrusted input, `eval(`/`new Function(` on input.

### 9. Vulnerable / hallucinated dependencies — slopsquatting (OWASP A06 · LLM supply chain)

- **Rule**: verify an AI-suggested npm package **actually exists and is the
  legitimate, maintained package** (hallucination/slopsquatting). Pin versions,
  commit the lockfile, run `npm audit`/SCA, watch install/postinstall scripts.
- **Common AI failure**: adding a nonexistent or typo-similar package, an
  abandoned package with a known CVE, a package with a suspicious postinstall.
- **red-flag**: a package name you've never seen · negligible downloads · no recent
  maintenance · an advisory · an unexpected postinstall script.

## Vibe-guard review checklist

For frontend code that AI generated or was pasted in quickly, before merge:

- [ ] No `dangerouslySetInnerHTML`/`innerHTML` with untrusted input (sanitize if unavoidable); no `javascript:` URLs.
- [ ] No secrets in the client bundle; `NEXT_PUBLIC_`/`VITE_` hold non-secrets only; privileged calls proxied server-side.
- [ ] Session tokens in httpOnly+Secure+SameSite cookies, not `localStorage`.
- [ ] Cookie-authed mutations have CSRF protection; auth cookies `Secure`+`SameSite`.
- [ ] Redirect targets allowlisted / same-origin (no open redirect).
- [ ] `postMessage` uses a specific origin and the receiver checks `event.origin`; `_blank` has `noopener`.
- [ ] Route handlers/server actions validate input, authorize the caller, parameterize queries, allowlist outbound URLs.
- [ ] No prototype-pollution merges; no `eval`/`Function` on input; responses validated.
- [ ] Added npm deps are real · legitimate · maintained · version-pinned · CVE-free.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive (vulnerable vs safe code samples): [reference.md](./reference.md)
- Umbrella: [frontend-architecture](../frontend-architecture/SKILL.md)
- Adjacent: [frontend-api-contract](../frontend-api-contract/SKILL.md), [frontend-accessibility](../frontend-accessibility/SKILL.md)
- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- OWASP Cheat Sheets (XSS, CSRF, DOM XSS): https://cheatsheetseries.owasp.org/
- CWE Top 25: https://cwe.mitre.org/top25/

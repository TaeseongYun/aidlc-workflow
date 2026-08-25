# frontend-security — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per
failure mode. TypeScript + React / Next.js. Decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- A large share of AI-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets more often than human-only commits.
- Developers **overtrust** AI code, believing it safer than it is.
- Web twist: **the client bundle is public** — any embedded secret, key, or
  "hidden" logic is readable in the browser. The price of AI speed is a review gate.

## 1. XSS — unsanitized HTML / URLs

```tsx
// ❌ Renders untrusted HTML → script injection
<div dangerouslySetInnerHTML={{ __html: comment.body }} />
el.innerHTML = userValue;

// ✅ Render as text (React escapes by default)
<div>{comment.body}</div>

// ✅ If HTML is truly required, sanitize first
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />

// ✅ Block dangerous URL schemes in user-supplied links
const safeHref = /^https?:\/\//.test(url) ? url : '#'; // no javascript:/data:
```

## 2. Secrets in the client bundle

```ts
// ❌ NEXT_PUBLIC_* / VITE_* ship to the browser — NOT secret
const key = process.env.NEXT_PUBLIC_STRIPE_SECRET; // readable by anyone

// ✅ Secret stays server-only; the browser calls YOUR endpoint
// app/api/charge/route.ts (server):
const key = process.env.STRIPE_SECRET;             // no NEXT_PUBLIC_ prefix
// client: await fetch('/api/charge', { method: 'POST', body })  → proxied server-side
```

- `.env` in `.gitignore`; a committed secret is leaked → rotate.

## 3. Token storage / session

```ts
// ❌ localStorage token — any XSS can read it
localStorage.setItem('access_token', jwt);

// ✅ httpOnly + Secure + SameSite cookie set by the server; JS can't read it
// Set-Cookie: session=...; HttpOnly; Secure; SameSite=Lax; Path=/
// client sends it automatically with credentials: 'include' → frontend-api-contract
```

## 4. CSRF / cookie safety

```ts
// ❌ Cookie session, SameSite=None, no CSRF token → cross-site POST forgeable
// ✅ SameSite=Lax/Strict + anti-CSRF token (or framework built-in), state changes via POST
// Next server action / route handler: verify the CSRF token / origin header on mutations.
```

## 5. Open redirect

```ts
// ❌ redirect target from user input
redirect(searchParams.get('next') ?? '/');            // attacker sets next=//evil.com
window.location.href = params.get('returnUrl')!;

// ✅ allowlist / same-origin only
const next = searchParams.get('next') ?? '/';
redirect(next.startsWith('/') && !next.startsWith('//') ? next : '/'); // relative, not protocol-relative
```

## 6. postMessage / window.opener

```ts
// ❌ broadcast to any origin, no origin check on receive
iframe.contentWindow?.postMessage(data, '*');
window.addEventListener('message', (e) => handle(e.data)); // trusts anyone

// ✅ specific origin + verify sender
target.postMessage(data, 'https://app.example.com');
window.addEventListener('message', (e) => {
  if (e.origin !== 'https://app.example.com') return;   // check origin
  handle(e.data);
});
```

```tsx
// ✅ external new-tab links can't control window.opener
<a href={url} target="_blank" rel="noopener noreferrer">Open</a>
```

## 7. SSRF / injection in server code

```ts
// app/api/fetch/route.ts
// ❌ user URL fetched server-side → SSRF to internal/metadata
const r = await fetch(searchParams.get('url')!);

// ✅ host allowlist + block private/metadata ranges
const u = new URL(input);
if (u.protocol !== 'https:' || !ALLOWED_HOSTS.has(u.host)) return bad();
const { address } = await dns.promises.lookup(u.hostname);              // resolve, then check the real IP
if (isPrivate(address) || address === '169.254.169.254') return bad();  // block private/link-local/metadata (DNS-rebinding)

// ❌ string-built SQL in a server action  →  ✅ parameterized query / ORM binding
// ✅ server actions authorize the caller before mutating
```

## 8. Prototype pollution / unsafe deserialization

```ts
// ❌ naive deep merge of untrusted input pollutes Object.prototype
deepMerge(target, JSON.parse(req.body));
// ❌ eval(userInput) / new Function(userInput)

// ✅ guard dangerous keys, or use a vetted merge; validate the parsed shape
for (const k of Object.keys(src)) {
  if (['__proto__', 'constructor', 'prototype'].includes(k)) continue; // skip pollutant keys
  target[k] = src[k];
}
const data = OrderSchema.parse(JSON.parse(body)); // or validate the parsed shape → frontend-api-contract
```

## 9. Vulnerable / hallucinated dependencies (slopsquatting)

```
- Verify an AI-suggested npm package actually exists and is legitimate (publisher,
  weekly downloads, repo, recent releases). Typo-similar · brand-new · negligible
  downloads → suspect slopsquatting, do not install.
- Pin versions + commit the lockfile. Review install/postinstall scripts.
- Gate on npm audit / Dependabot / Snyk; fix or remove advisories.
```

## Full vibe-guard review checklist

- [ ] No `dangerouslySetInnerHTML`/`innerHTML` on untrusted input; sanitize if unavoidable; no `javascript:` URLs.
- [ ] No secrets in the bundle; `NEXT_PUBLIC_`/`VITE_` are non-secrets; privileged calls proxied.
- [ ] Session tokens in httpOnly+Secure+SameSite cookies, not `localStorage`.
- [ ] Cookie-authed mutations CSRF-protected; auth cookies `Secure`+`SameSite`.
- [ ] Redirect targets allowlisted / same-origin.
- [ ] `postMessage` targets a specific origin; receivers check `event.origin`; `_blank` has `noopener`.
- [ ] Server handlers/actions validate input, authorize the caller, parameterize queries, allowlist outbound URLs.
- [ ] No prototype-pollution merges; no `eval`/`Function` on input; parsed data validated.
- [ ] Deps real · legitimate · maintained · pinned · advisory-free; scripts reviewed.

## Official references

- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- XSS Prevention: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html
- DOM-based XSS Prevention: https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html
- CSRF Prevention: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
- SSRF Prevention: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- CWE Top 25: https://cwe.mitre.org/top25/
- Team baseline: [../../guidance.md](../../guidance.md)

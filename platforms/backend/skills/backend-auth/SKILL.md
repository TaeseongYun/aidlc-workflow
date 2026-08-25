---
name: backend-auth
description: Backend authentication & authorization rules — separate AuthN (session/token/JWT/OAuth2·OIDC) from AuthZ (object-level BOLA · function-level BFLA), place authorization checks in the security layer (filter/interceptor/middleware) while re-verifying ownership in the service. Covers JWT verification (signature · alg allowlist · exp/iss/aud), session/token management, password hashing (bcrypt/argon2/scrypt), least privilege, and no home-rolled authentication. Use when writing or reviewing Security/Auth/Filter/Interceptor/Guard/middleware code or designing/verifying access control. Both Spring Security (Kotlin/Java) and Node/TS (Passport/Nest Guards). Backend authentication & authorization: BOLA/BFLA, JWT verification, sessions, password hashing, least privilege.
when_to_use: When designing or reviewing login/auth flows, authorization/permission checks, JWT/session/token verification, password storage (hashing), roles/permissions (RBAC), resource-ownership checks, or admin-endpoint protection
paths: **/*Security*.kt, **/*Security*.java, **/security/**, **/*Auth*.kt, **/*Auth*.java, **/*Filter.java, **/*Interceptor.kt, **/*Interceptor.java, **/*.guard.ts, **/*.strategy.ts, **/auth/**, **/middleware/**
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-auth — authentication · authorization

The access-control baseline: separate AuthN (who you are) from AuthZ (what you may do), and
**always re-verify on the server**. Maps to OWASP A01 (Broken Access Control) · A07 (Auth Failures),
API1/API5:2023 (BOLA/BFLA). The rules here are **safety rules** and must not be relaxed. Deep dive in
[reference.md](./reference.md).

## Scope

- Targets: auth flows (session/token/JWT/OAuth2·OIDC), authorization (object and function level), password storage,
  roles/permissions, ownership verification.
- Out of scope: attack patterns such as injection → [backend-security-guard], response contract →
  [backend-api-contract], sensitive-data storage/encryption → [backend-data-transactions].

## Core rules (do / don't)

### Separate AuthN vs AuthZ

- **DO** split authentication (identity check) from authorization (permission decision). Authentication in the
  security layer (filter/interceptor/middleware), authorization at both the endpoint and the service.
- **DON'T** substitute authorization with "they're logged in, so it's fine". Authentication ≠ authorization.

### Object-level authorization — BOLA (API1:2023)

- **DO** on resource access, **re-verify ownership/access rights on the server**. Do not allow access just
  because an `id` is in the request. Tie the lookup to the ownership condition
  (`findByIdAndUserId`) or check the owner after loading.
- **DON'T** trust a client-supplied id and fetch/update by it directly (horizontal privilege escalation).

### Function-level authorization — BFLA (API5:2023)

- **DO** admin/privileged function endpoints must **explicitly verify role/permission**
  (`@PreAuthorize("hasRole('ADMIN')")`, Nest `@Roles('admin')` guard).
- **DON'T** assume something is safe because the URL is unknown. Obscurity is not authorization.

### JWT / token verification

- **DO** JWT **signature verification is mandatory**, allowed-algorithm allowlist, verify `exp`/`iss`/`aud`.
  Block symmetric (HS) ↔ asymmetric (RS) confusion. If server-side invalidation is needed, use short expiry + refresh rotation.
- **DON'T** decode without a signature and trust it. No `alg=none`. No hardcoded secret.

### Sessions / passwords

- **DO** reissue the session at login (session-fixation defense), safe cookies (`HttpOnly`,`Secure`,`SameSite`),
  server-side expiry. Hash passwords with **bcrypt/scrypt/argon2** (per-user salt is built into the algorithm).
- **DON'T** store passwords as plaintext · MD5 · SHA1 · (plain) SHA256. Don't design assuming tokens live in
  localStorage.

### No home-rolled implementation · least privilege

- **DO** use the framework's vetted security (Spring Security, Passport/Nest Guards, OAuth2·OIDC
  libraries). Grant permissions under the **least privilege** principle.
- **DON'T** roll your own crypto/auth protocol. Don't omit brute-force protection (rate limit ·
  lockout) → [backend-reliability].

## Authorization checklist

| # | Check | On failure |
|---|-------|------------|
| 1 | Are authentication and authorization separated | Separate them (login ≠ authorization) |
| 2 | Does resource access re-verify ownership (BOLA) | Add owner condition/comparison |
| 3 | Do privileged endpoints verify role (BFLA) | `@PreAuthorize`/roles guard |
| 4 | Does JWT verify signature · alg allowlist · exp/iss/aud | Verify via a verifier |
| 5 | Are passwords hashed with bcrypt/argon2 | Switch to a hash |
| 6 | Are session reissue · safe cookie flags present | Add the config |
| 7 | Is framework security used with no home-rolled impl | Replace with the standard |
| 8 | Is brute-force protection (rate limit/lockout) present | Add it |

## Refactor / red-flag signals

- Fetching/updating by an id from the path/body with no ownership check (BOLA).
- `/admin/*` · privileged functions with no role check (BFLA).
- Decoding a JWT without signature verification, unrestricted `alg`, no exp check.
- Storing passwords as plaintext/MD5/SHA1/plain SHA256.
- No session reissue, cookies without `HttpOnly`/`Secure`/`SameSite`.
- Home-rolled auth/crypto protocol.
- No rate limit/lockout on login · OTP · password reset.

## References

- Team baseline: [../../guidance.md](../../guidance.md) (Trust Boundaries section)
- Deep dive: [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- Adjacent: [backend-security-guard](../backend-security-guard/SKILL.md)
- OWASP API1:2023 (BOLA): https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/
- OWASP API5:2023 (BFLA): https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/
- Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- Authorization Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html

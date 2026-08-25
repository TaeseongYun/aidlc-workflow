# backend-auth — Reference

Deep-dive material for `SKILL.md`. BOLA/BFLA · JWT · session · password-hash samples.
Spring Security first, Node/TS alongside.

## 1. BOLA — object-level authorization (block horizontal privilege escalation)

```kotlin
// ❌ No ownership check — accesses other people's resources
fun getInvoice(id: Long) = invoiceRepo.findById(id).orElseThrow()

// ✅ Reflect ownership in the query, or compare after loading
fun getInvoice(id: Long, principal: UserPrincipal): Invoice {
    val inv = invoiceRepo.findByIdAndOwnerId(id, principal.userId)
        ?: throw NotFoundException()            // missing or someone else's → same response (avoid existence disclosure)
    return inv
}
```

- If only admins get full access, branch on role: only when the caller is the owner or ADMIN.
- Making the id a UUID does not stop BOLA — **authorization is the defense**, not how hard it is to guess.

## 2. BFLA — function-level authorization

```kotlin
// Spring Security: method security
@PreAuthorize("hasRole('ADMIN')")
@DeleteMapping("/admin/users/{id}")
fun deleteUser(@PathVariable id: Long) { ... }

// SecurityFilterChain: path-based
http.authorizeHttpRequests {
    it.requestMatchers("/admin/**").hasRole("ADMIN")
      .requestMatchers("/api/**").authenticated()
      .anyRequest().denyAll()                  // deny by default
}
```

```typescript
// Nest: RolesGuard
@Roles('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Delete('admin/users/:id')
deleteUser(@Param('id') id: string) { ... }
```

- Default is **deny**. Use `anyRequest().denyAll()` or be explicit so a new endpoint isn't opened without a rule.

## 3. JWT verification

```kotlin
// ✅ Signature + alg allowlist + standard claims
val verifier: JWTVerifier = JWT.require(Algorithm.HMAC256(secret))  // allow HS256 only
    .withIssuer("https://auth.example.com")
    .withAudience("example-api")
    .acceptLeeway(5)                            // clock skew
    .build()
val jwt = verifier.verify(token)                // verify signature · exp · iss · aud. Throws on failure
val userId = jwt.subject
```

Watch-outs:
- Reject `alg=none`. Allow only the algorithm the server expects (don't trust the library default).
- When using asymmetric (RS/ES), **verify with the public key** but block the confusion attack where the attacker
  switches alg to HS and uses the public key as the HMAC secret (fix the algorithm).
- If logout/invalidation is needed, use short access + refresh token rotation, or server-side sessions.

## 4. Sessions / cookies

```kotlin
// Safe cookies + session-fixation defense (reissue the session at login)
http.sessionManagement {
    it.sessionFixation().newSession()           // new session ID at login
}
// server.servlet.session.cookie: http-only: true, secure: true, same-site: strict
```

## 5. Password hashing

```kotlin
// ✅ Spring Security
@Bean fun passwordEncoder() = BCryptPasswordEncoder(12)   // or Argon2PasswordEncoder
val hash = encoder.encode(rawPassword)
val ok = encoder.matches(rawPassword, storedHash)
```

```typescript
const hash = await bcrypt.hash(raw, 12);        // or argon2.hash(raw)
const ok = await bcrypt.compare(raw, hash);
```

- No MD5/SHA1/plain SHA256 (fast hash = mass cracking). bcrypt/scrypt/argon2 are designed to be slow.
- Comparison is constant-time (`matches`/`compare` handles it). No direct `==` comparison.

## 6. Brute-force protection

- Login · OTP · password reset get a rate limit + backoff/lockout after a failure threshold → [backend-reliability].
- Don't leak whether an account exists through the response (same message · same delay).

## 7. Review checklist

- [ ] Resource access re-verifies ownership (BOLA). No trusting the id.
- [ ] Privileged endpoints verify role (BFLA). Deny by default.
- [ ] JWT signature · fixed alg · exp/iss/aud verification. Reject `alg=none`.
- [ ] Passwords bcrypt/argon2. No plaintext/MD5/SHA.
- [ ] Session reissue + `HttpOnly`/`Secure`/`SameSite`.
- [ ] Framework security used, no home-rolled auth/crypto.
- [ ] Rate limit · lockout on login/OTP.

## Official references

- OWASP API1:2023 (BOLA): https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/
- OWASP API5:2023 (BFLA): https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/
- Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- Authorization Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html
- JWT for Java Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html
- Password Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- Spring Security: https://docs.spring.io/spring-security/reference/
- Team baseline: [../../guidance.md](../../guidance.md)

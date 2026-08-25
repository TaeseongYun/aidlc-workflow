# backend-security-guard — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per failure mode.
Spring Boot/JPA (Kotlin/Java) first, Node/TS alongside. The decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- About 40% of Copilot-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets ~2x as often as human-only commits (repo 6.4% vs 4.6%,
  commit 3.2% vs 1.5%).
- Stanford study: AI-assisted developers write "less secure code" and **overtrust** it as safe.
- Bottom line: the price of AI speed is a review gate. This guard is that gate.

## 1. Hardcoded secrets

```kotlin
// ❌ Common AI failure
val apiKey = "sk-live-abcd1234"
spring.datasource.password=admin

// ✅ Environment variable / secret manager
@Value("\${payment.api-key}") lateinit var apiKey: String   // value from env/secret manager
// application.yml: payment.api-key: ${PAYMENT_API_KEY}
```

```typescript
// ❌ const apiKey = "sk-live-...";
// ✅ const apiKey = process.env.PAYMENT_API_KEY; if (!apiKey) throw new Error("missing secret");
```

- `.env` goes in `.gitignore`. A committed secret is treated as leaked → rotate it. No Dockerfile `ENV SECRET=`.

## 2. SQL / ORM injection

```kotlin
// ❌ String concatenation
val q = "SELECT * FROM users WHERE email = '$email'"
em.createNativeQuery(q).resultList

// ✅ Bound parameters (JPQL named / native positional)
@Query("select u from User u where u.email = :email")
fun findByEmail(@Param("email") email: String): User?
// native: em.createNativeQuery("... where email = ?1").setParameter(1, email)
```

```typescript
// ❌ prisma.$queryRawUnsafe(`SELECT * FROM users WHERE email='${email}'`)
// ✅ Parameter binding
await prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;   // tagged template = safe
await repo.findOne({ where: { email } });                            // query builder
```

- **Identifiers** like the sort column/direction can't be bound → map them via an allowlist (never concatenate input verbatim).

## 3. Command / path traversal

```kotlin
// ❌ Runtime.getRuntime().exec("convert " + userFile)
// ✅ Argument array + allowlist, no shell
ProcessBuilder("convert", safeInput, "out.png").start()

// ❌ File(baseDir, userPath)              // can escape via ../
// ✅ Normalize, then verify it stays inside the base directory
val resolved = baseDir.toPath().resolve(userPath).normalize()
require(resolved.startsWith(baseDir.toPath())) { "path traversal" }
```

## 4. SSRF

```kotlin
// ❌ restTemplate.getForObject(userUrl, String::class.java)
// ✅ host allowlist + block private/metadata IPs + limit redirects
private val ALLOWED = setOf("api.partner.com")
fun fetch(userUrl: String): String {
    val uri = URI(userUrl)
    require(uri.scheme == "https" && uri.host in ALLOWED) { "host not allowed" }
    val addr = InetAddress.getByName(uri.host)
    require(!addr.isSiteLocalAddress && !addr.isLoopbackAddress &&
            addr.hostAddress != "169.254.169.254") { "blocked address" }   // block cloud metadata
    return client.get(uri)
}
```

```typescript
// ✅ Node: URL host allowlist + block private ranges after dns lookup. Manually verify redirects.
```

## 5. Unsafe deserialization

```java
// ❌ new ObjectInputStream(in).readObject();                 // remote code execution vector
// ❌ Jackson: mapper.enableDefaultTyping();                   // polymorphic gadget
// ❌ SnakeYaml: new Yaml().load(untrusted);
// ✅ Deserialize into fixed DTOs only
Order o = objectMapper.readValue(json, Order.class);          // known type
// YAML: new Yaml(new SafeConstructor(new LoaderOptions())).load(input);
```

```python
# ❌ pickle.loads(untrusted)  →  ✅ json.loads(untrusted) (validated against a fixed schema)
```

## 6. Access control — BOLA / BFLA

```kotlin
// ❌ BOLA: fetch by id with no owner check
@GetMapping("/orders/{id}")
fun get(@PathVariable id: Long) = orderRepo.findById(id)     // returns other people's orders too

// ✅ Re-verify ownership for the authenticated principal
@GetMapping("/orders/{id}")
fun get(@PathVariable id: Long, auth: Principal): OrderResponse {
    val order = orderRepo.findByIdAndUserId(id, auth.userId)  // ownership reflected in the query/check
        ?: throw NotFoundException()
    return order.toResponse()
}
// BFLA: /admin/* verifies the role (@PreAuthorize("hasRole('ADMIN')")) → backend-auth
```

## 7. JWT verification

```kotlin
// ❌ Decode without verifying the signature / unrestricted alg
val claims = JWT.decode(token)                                // this is NOT verification!
// ✅ Signature + alg allowlist + exp/iss/aud
val verifier = JWT.require(Algorithm.HMAC256(secret))         // symmetric key → allow HS only
    .withIssuer("example").withAudience("api").build()
val decoded = verifier.verify(token)                          // verify signature · exp
```

- Reject `alg=none`, prevent HS↔RS confusion (attack using the public key as an HMAC key). Passwords use bcrypt/argon2 → backend-auth.

## 8. Weak crypto / randomness

```kotlin
// ❌ MessageDigest.getInstance("MD5") / "SHA-1" (passwords), "AES/ECB/PKCS5Padding", Math.random() token
// ✅ passwords: BCryptPasswordEncoder(); symmetric: AES/GCM + SecureRandom IV; tokens: SecureRandom
val token = ByteArray(32).also { SecureRandom().nextBytes(it) }
    .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }
```

```typescript
// ❌ crypto.createHash('md5'); Math.random()
// ✅ await bcrypt.hash(pw, 12); crypto.randomBytes(32).toString('base64url');
```

## 9. Disabled security

```kotlin
// ❌ AI turns it off "to make it work"
http.csrf().disable().authorizeHttpRequests { it.anyRequest().permitAll() }
// Trust-all TrustManager, actuator "*" exposed unauthenticated

// ✅ Explicit minimal allow + authenticate the rest
http.authorizeHttpRequests {
    it.requestMatchers("/health", "/login").permitAll()
      .anyRequest().authenticated()
}
// CSRF: for a stateless token API you may legitimately disable it (record the reason); for cookie sessions, keep it on.
```

```typescript
// ❌ new https.Agent({ rejectUnauthorized: false })  // do not defeat TLS verification
// ❌ axios ... { httpsAgent: agent }  with rejectUnauthorized:false
```

- Put actuator/debug endpoints behind authentication. Do not open `management.endpoints.web.exposure.include` to `*`.

## 10. Information disclosure

```kotlin
// ❌ catch (e) { return ResponseEntity.status(500).body(e.stackTraceToString()) }
// ✅ Generalized message + traceId, details only in logs → backend-api-contract §1
// ❌ log.info("login token={}", jwt)  →  ✅ never log tokens/passwords/full PII → backend-reliability
```

## 11. Vulnerable / hallucinated dependencies (slopsquatting)

```
- Verify an AI-suggested package actually exists and is legitimate (official org/downloads/maintenance).
  Typo-similar · recently created · negligible downloads → suspect slopsquatting, do not install.
- Pin versions + commit the lockfile. Gate on SCA (OWASP Dependency-Check / npm audit / Snyk).
```
Details → [backend-reliability].

## Full vibe-guard review checklist

- [ ] No hardcoded secrets · default credentials (including .env/Dockerfile).
- [ ] All queries use parameter binding. Identifiers via allowlist.
- [ ] No unvalidated input in commands/paths/expressions.
- [ ] User-URL fetch has an allowlist + blocks private/metadata IPs.
- [ ] No untrusted deserialization (fixed DTOs / Safe loader).
- [ ] Resource access re-verifies ownership/role (BOLA/BFLA).
- [ ] JWT signature · alg allowlist · exp verification. Passwords bcrypt/argon2.
- [ ] No MD5/SHA1 (passwords) · ECB · fixed IV · `Math.random` (security). `SecureRandom` used.
- [ ] No permitAll abuse / blanket CSRF off / TLS-verification bypass / open actuator.
- [ ] No stack traces · secrets in responses/logs.
- [ ] Dependencies real · legitimate · version-pinned · CVE-free.

## Official references

- OWASP Top 10 2021: https://owasp.org/Top10/
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
- SQL Injection Prevention: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
- SSRF Prevention: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- Deserialization: https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html
- Secrets Management: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
- Team baseline: [../../guidance.md](../../guidance.md)

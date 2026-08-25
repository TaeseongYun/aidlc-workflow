# backend-reliability — Reference

Deep-dive material for `SKILL.md`. Logging hygiene · resilience · rate limiting · dependency/supply-chain samples.

## 1. Logging hygiene (mask sensitive data)

```kotlin
// ❌ Whole-body / sensitive logging
log.info("login req={}", request)              // may include password · token
log.info("card={}", cardNumber)

// ✅ Field selection + masking + correlation ID
log.info("login attempt userId={} ip={} traceId={}", userId, maskIp(ip), traceId)
fun maskCard(c: String) = "****" + c.takeLast(4)
```

- Inject a `traceId` per request via MDC/filter. Correlate in the log aggregator.
- Mask targets: passwords · tokens · API keys · cards · national-ID/passport · full email · auth headers.

## 2. Security audit logs

```
Login success/failure, permission denied (403), password change, admin actions (delete/grant), payment events
→ log who / what / when / result / traceId to a separate audit log. Tamper-resistant storage recommended.
```

## 3. Outbound-call resilience

```kotlin
// Timeout is mandatory
val client = WebClient.builder()
    .clientConnector(ReactorClientHttpConnector(HttpClient.create()
        .responseTimeout(Duration.ofSeconds(3))))     // connect/read timeout
    .build()

// Resilience4j: retry (exponential backoff) on idempotent operations only + circuit breaker
@Retry(name = "partner") @CircuitBreaker(name = "partner", fallbackMethod = "fallback")
fun fetchQuote(id: String): Quote = partnerAdapter.quote(id)
fun fallback(id: String, e: Throwable): Quote = Quote.unavailable()
```

```typescript
// Node: AbortController timeout + p-retry (idempotent only). Circuit: opossum
const ac = new AbortController();
const t = setTimeout(() => ac.abort(), 3000);
try { return await fetch(url, { signal: ac.signal }); } finally { clearTimeout(t); }
```

- Retry **idempotent operations only** (GET/PUT/POST with an idempotency key). Beware payment duplication → backend-data-transactions.
- Add jitter to the backoff to avoid a thundering herd.

## 4. Rate limiting / resource caps

```kotlin
// Bucket4j / Spring Cloud Gateway / at the API gateway level
// Principle: cap public · expensive · authenticated endpoints. Return 429 + Retry-After.
// Payload caps: spring.servlet.multipart.max-file-size, body size limit.
```

- Login/OTP/password reset: failure backoff keyed on IP+account → backend-auth.
- Lists get a page-size cap (coerceIn) → backend-api-contract.

## 5. Health checks / actuator exposure

```yaml
# actuator: expose only health/info, the rest behind authentication
management:
  endpoints.web.exposure.include: health,info      # no "*"
  endpoint.health.probes.enabled: true             # liveness/readiness
server.shutdown: graceful                           # finish in-flight, then terminate
```

## 6. Dependencies / supply chain

```
- Pin versions + commit the lockfile (gradle.lockfile / package-lock.json / poetry.lock).
- SCA as a CI gate: OWASP Dependency-Check, `npm audit`, Snyk, GitHub Dependabot.
- Verify new packages (hallucination/slopsquatting):
    · does it actually exist in the official org/registry
    · are downloads · maintenance · stars normal (recently thrown-together · typo-similar = suspect)
    · is the name one character off a well-known package (typosquat)
- Generate an SBOM (CycloneDX/Syft) to make components visible.
```

```gradle
// Version catalog + locking
dependencyLocking { lockAllConfigurations() }        // generates gradle.lockfile
```

## 7. Review checklist

- [ ] No secrets/tokens/full PII in logs (mask/select). Correlation ID present.
- [ ] Security-event audit logs.
- [ ] Outbound-call timeout + (idempotent) retry backoff + circuit breaker.
- [ ] Rate limit + payload caps on expensive/public endpoints.
- [ ] Expose only actuator health/info, the rest authenticated. Graceful shutdown.
- [ ] Dependencies version-pinned + lockfile + SCA-passing.
- [ ] New packages verified real · legitimate (not hallucinated). SBOM recommended.
- [ ] No secrets hardcoded in image/config.

## Official references

- OWASP A06 (Vulnerable and Outdated Components): https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/
- OWASP A09 (Logging & Monitoring Failures): https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/
- OWASP API4:2023 (Unrestricted Resource Consumption): https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/
- Logging Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- OWASP Dependency-Check: https://owasp.org/www-project-dependency-check/
- NIST SSDF: https://csrc.nist.gov/projects/ssdf
- Resilience4j: https://resilience4j.readme.io/
- Team baseline: [../../guidance.md](../../guidance.md)

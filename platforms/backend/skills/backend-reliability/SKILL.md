---
name: backend-reliability
description: Backend reliability · observability · supply-chain rules — structured logging (never log sensitive data · secrets · tokens · full PII) and correlation IDs, security/audit logs, outbound-call resilience (timeout · retry with backoff · circuit breaker), rate limiting/brute-force protection (unrestricted resource consumption API4:2023), health checks · graceful shutdown, vulnerable/outdated dependency management (SCA · version pinning · lockfile), and supply chain (hallucinated/slopsquatting packages · SBOM). Use when writing or reviewing config · logging · external clients · build manifests (build.gradle/pom.xml/package.json), or designing resilience · observability · dependencies. Backend reliability, observability, logging hygiene, resilience, rate limiting, dependency & supply-chain security.
when_to_use: When designing or reviewing logging/observability config, outbound-call timeouts · retries · circuit breakers, rate limiting, health checks, dependency additions · version pinning · SCA, secret-management wiring, or actuator/monitoring exposure
paths: **/*Config*.kt, **/*Config*.java, **/logback*.xml, **/log4j2*.xml, **/*Client*.kt, **/*Client*.java, **/build.gradle, **/build.gradle.kts, **/pom.xml, **/package.json, **/resilience*, **/application*.yml
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# backend-reliability — reliability · observability · supply chain

The baseline that keeps a service standing under load · failure · time: logging hygiene, outbound-call resilience,
rate limiting, dependencies/supply chain. Maps to OWASP A06 (Vulnerable/Outdated Components) · A09 (Logging/Monitoring Failures) ·
API4:2023 (Resource Consumption). Deep dive in [reference.md](./reference.md).

## Scope

- Targets: logging/audit, correlation IDs, outbound-call resilience, rate limiting, health checks/shutdown,
  dependency management · SCA, supply chain (hallucinated packages · SBOM), secret wiring.
- Out of scope: attack patterns themselves → [backend-security-guard], authN/authZ → [backend-auth],
  response contract → [backend-api-contract].

## Core rules (do / don't)

### Logging hygiene (never log sensitive data — safety rule)

- **DO** structured logging + **correlation ID (traceId)**. Exceptions go to the server log in detail, the client
  gets a generalized message → [backend-api-contract].
- **DO** log security events (login success/failure, permission denied, admin actions) as audit logs.
- **DON'T** leave secrets · tokens · passwords · full card/national-ID numbers · full PII in logs.
  No dumping whole request bodies (mask / select fields).

### Outbound-call resilience

- **DO** a **timeout** on every outbound call. Retries use exponential backoff + jitter, **idempotent operations only**.
  A circuit breaker for repeated failures. Handled in the adapter → [backend-architecture].
- **DON'T** call without a timeout, retry infinitely/immediately (amplifies outages), blindly retry non-idempotent operations.

### Rate limiting / resource caps

- **DO** rate limit public · expensive · authenticated endpoints. Cap payload/page size
  (API4:2023 resource consumption). Login etc. use failure-based backoff → [backend-auth].
- **DON'T** leave unbounded list returns · unbounded uploads · unbounded requests unchecked.

### Health checks / shutdown / exposure

- **DO** liveness/readiness health checks, graceful shutdown (finish in-flight, then terminate).
  Put actuator/monitoring/debug behind authentication.
- **DON'T** expose actuator as `*` unauthenticated (leaks env · heapdump).

### Dependencies · supply chain

- **DO** **pin** versions + commit the lockfile. Gate on SCA (Dependency-Check/npm audit/Snyk) to
  block known CVEs. Verify a new package is **real · legitimate** (hallucination/slopsquatting). SBOM generation recommended.
- **DON'T** leave versions unpinned (`latest`) · add without a lockfile · install a package the AI invented ·
  keep a known-vulnerable version.

### Secret wiring

- **DO** inject secrets from environment variables/secret manager, bind them via typed config
  → [backend-security-guard].
- **DON'T** bake secrets into code · VCS · image layers.

## Reliability checklist

| # | Check | On failure |
|---|-------|------------|
| 1 | Are there no secrets/tokens/full PII in logs | Mask / select fields |
| 2 | Is there structured logging + correlation ID | Add it |
| 3 | Are security-event audit logs present | Add them |
| 4 | Do outbound calls have timeout · (idempotent) retry · circuit breaker | Add to the adapter |
| 5 | Do expensive/public endpoints have rate limit · caps | Add them |
| 6 | Are actuator/debug behind authentication | Protect them |
| 7 | Are dependencies version-pinned · lockfile · SCA-passing | Pin · scan |
| 8 | Is a new package real · legitimate (not hallucinated) | Verify before install |

## Refactor / red-flag signals

- Dumping whole request/response bodies to logs, tokens · passwords in logs.
- Outbound calls without a timeout, infinite/immediate retry, non-idempotent retry.
- Missing rate limit · payload caps (resource-consumption vulnerable).
- actuator/debug endpoints exposed unauthenticated.
- Dependency version `latest`/unpinned, missing lockfile, known-CVE version.
- A never-before-seen · typo-similar package (suspect slopsquatting).
- A secret hardcoded in an image layer/config file.

## References

- Team baseline: [../../guidance.md](../../guidance.md)
- Deep dive: [reference.md](./reference.md)
- Umbrella: [backend-architecture](../backend-architecture/SKILL.md)
- Adjacent: [backend-security-guard](../backend-security-guard/SKILL.md)
- OWASP A06 (Vulnerable and Outdated Components): https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/
- OWASP A09 (Logging & Monitoring Failures): https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/
- Logging Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- NIST SSDF: https://csrc.nist.gov/projects/ssdf

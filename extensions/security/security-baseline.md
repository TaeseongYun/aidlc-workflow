# Security Baseline

The complete set of rules for the 11 production security items.
This file is loaded only when the user opts in.

## Application Rules

- On opt-in, every item is treated as a **blocking constraint**.
- FAIL items must be resolved within the corresponding UOW.
- The artifact is generated at `aidlc-docs/features/<feature-slug>/extensions/security-baseline.md`.

---

## SECURITY-01. Encryption at Rest

**Evaluation criteria**:
- PASS: Sensitive data is stored encrypted with AES-256 or stronger. A key management service (KMS) is used.
- FAIL: Stored in plaintext, weak encryption, hardcoded keys.
- N/A: A feature that does not store sensitive data.

**Typical action**: DB field encryption, enable SSE for file storage, establish a key rotation policy.
**Brownfield consideration**: Migration plan for existing plaintext data, confirm backward compatibility.

## SECURITY-02. Encryption in Transit

**Evaluation criteria**:
- PASS: All external/internal communication uses TLS 1.2 or higher. Certificates are valid.
- FAIL: Plaintext HTTP communication present, self-signed certificates used in production.
- N/A: A feature with no network communication.

**Typical action**: Enforce HTTPS, review mTLS between internal services, automatic certificate renewal.
**Brownfield consideration**: Migration of legacy HTTP endpoints, client compatibility.

## SECURITY-03. Network Intermediary Access Logging

**Evaluation criteria**:
- PASS: Access logging is enabled at the load balancer/WAF/proxy level. A retention period is defined.
- FAIL: Access logging not enabled, retention period not defined.
- N/A: A local-only feature with no network intermediary.

**Typical action**: Enable ALB/CloudFront access logs, S3/CloudWatch retention policy.
**Brownfield consideration**: Integration with the existing log pipeline, log format compatibility.

## SECURITY-04. Application-Level Logging

**Evaluation criteria**:
- PASS: Authentication/authorization events, data changes, and errors are recorded as structured logs. Sensitive data is masked.
- FAIL: No logging, sensitive data logged in plaintext, unstructured logs.
- N/A: A pure computation feature with no user interaction.

**Typical action**: Structured logging framework, PII masking middleware, separate audit logs.
**Brownfield consideration**: Maintain consistency with existing logging patterns, log level policy.

## SECURITY-05. HTTP Security Headers

**Evaluation criteria**:
- PASS: CSP, X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security, and Referrer-Policy are set.
- FAIL: Security headers not set or set permissively.
- N/A: A feature that does not return HTTP responses (batch, event processing, etc.).

**Typical action**: Set security headers at the middleware/proxy level, establish a CSP policy.
**Brownfield consideration**: CSP compatibility with the existing frontend, inline script dependencies.

## SECURITY-06. Input Validation

**Evaluation criteria**:
- PASS: All external inputs are validated for type/range/format. SQL Injection, XSS, and Command Injection are defended against.
- FAIL: Validation missing, client-side-only validation, blacklist approach only.
- N/A: A feature that does not accept external input.

**Typical action**: Server-side whitelist validation, parameter binding, output escaping.
**Brownfield consideration**: Check existing APIs' validation patterns, strengthen while maintaining backward compatibility.

## SECURITY-07. Least-Privilege Access Control

**Evaluation criteria**:
- PASS: IAM roles/policies follow the principle of least privilege. Service accounts are separated. Temporary credentials are used.
- FAIL: Wildcard permissions, shared service accounts, long-lived credentials.
- N/A: A feature with no infrastructure access.

**Typical action**: Fine-grained IAM policies, use AssumeRole, periodic permission audits.
**Brownfield consideration**: Gradually reduce excessive permissions of existing roles.

## SECURITY-08. Restrictive Network Configuration

**Evaluation criteria**:
- PASS: VPC/subnet separation, minimal Security Group openings, NAT gateway, private subnets.
- FAIL: DB placed in a public subnet, 0.0.0.0/0 inbound, unnecessary ports open.
- N/A: A feature with no network changes.

**Typical action**: Use private subnets, review Security Groups, VPC endpoints.
**Brownfield consideration**: Analyze impact on the existing network topology, gradual migration.

## SECURITY-09. Application-Level Access Control

**Evaluation criteria**:
- PASS: RBAC/ABAC implemented, permission checks per API endpoint, horizontal privilege escalation prevented.
- FAIL: Access control missing, URL-based control only, horizontal privilege escalation possible.
- N/A: A public feature that does not need authentication/authorization.

**Typical action**: Permission checks at the middleware level, verify resource ownership, permission caching strategy.
**Brownfield consideration**: Consistency with the existing permission model, migration path.

## SECURITY-10. Security Hardening

**Evaluation criteria**:
- PASS: Debug mode disabled, default accounts/passwords changed, unnecessary services removed, error messages do not expose internal information.
- FAIL: Debug mode enabled in production, default credentials, stack traces exposed.
- N/A: A feature that does not change the deployment environment.

**Typical action**: Separate per-environment configuration, custom error pages, remove unnecessary endpoints.
**Brownfield consideration**: Check existing error handling patterns, gradual hardening.

## SECURITY-11. Software Supply Chain Security

**Evaluation criteria**:
- PASS: Dependency vulnerability scanning automated, licenses checked, lock files used, trusted registries.
- FAIL: No vulnerability scanning, unverified dependencies, lock files not used.
- N/A: A feature that adds no new dependencies.

**Typical action**: Set up Dependabot/Snyk, commit lock files, review private registries.
**Brownfield consideration**: Identify existing vulnerable dependencies, analyze upgrade impact.

---

## Artifact Format

```markdown
# Security Baseline

> **Request Anchor**: {summary of the initial request}

## Security Checklist

| ID | Item | Status | Notes |
|----|------|------|------|
| SECURITY-01 | Encryption at rest | PASS / FAIL / N/A | |
| ... | ... | ... | |

## Findings

### SECURITY-{NN}. {item name}
- Status: PASS / FAIL / N/A
- Current state: {current application status}
- Action required: {required action or "none"}
- Related UOW: UOW-{N} / not applicable

## Summary
- Total items: 11
- PASS: {N}
- FAIL: {N}
- N/A: {N}
- If any item is FAIL, it must be resolved during the implementation of the corresponding UOW.
```

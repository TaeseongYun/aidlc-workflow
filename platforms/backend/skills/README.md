# Backend Detailed Skills

**Reference-knowledge skills** that expand `guidance.md` (the team backend baseline) into 6 topics. Each skill
follows the official skills format (`SKILL.md` + `reference.md`), auto-loads via `paths` when you touch the
relevant files, and can also be invoked manually as `/backend-*`. Deep-dive material lives in each skill's `reference.md`.

Consistency: these skills are a detailed expansion of `../guidance.md` and reference it by relative path.
When project `ctx/` conflicts, the project CTX wins (same precedence as the guidance).
However, **the security floor (safety rules) is never lowered.**

Stack: Kotlin/Java + Spring Boot + JPA first, with Node/TypeScript (Express/Nest) shown alongside
on the key rules.

| Skill | Purpose | Auto-load (paths) |
|-------|---------|-------------------|
| [backend-architecture](backend-architecture/SKILL.md) | Server architecture skeleton — dependency flow · layer responsibilities · transaction boundary · Feature Slice. The umbrella that ties the other 5 together | (none — description keywords · manual · cross-links) |
| [backend-api-contract](backend-api-contract/SKILL.md) | Response schema lock · error envelope · versioning · input-validation boundary · CORS · pagination | `**/*Controller.*`, `**/controller/**`, `**/routes/**`, `**/*.controller.ts`, `**/openapi*.yaml` |
| [backend-data-transactions](backend-data-transactions/SKILL.md) | Transaction boundary · N+1 · idempotency · excessive sensitive-data exposure · money/time · migrations | `**/*Repository.*`, `**/entity/**`, `**/domain/**`, `**/db/migration/**`, `**/*.entity.ts` |
| [backend-security-guard](backend-security-guard/SKILL.md) | **Vibe-coding security guard** — blocks vulnerable patterns in AI-generated code (secrets · SQLi · SSRF · deserialization · BOLA/BFLA · weak crypto · disabled security · hallucinated dependencies) | `**/*.java`, `**/*.kt`, `**/*.ts`, `**/*.py`, `**/application*.yml`, `**/.env*`, `**/Dockerfile` |
| [backend-auth](backend-auth/SKILL.md) | AuthN/AuthZ — BOLA (object) · BFLA (function) · JWT verification · sessions · password hashing · least privilege | `**/*Security*`, `**/*Auth*`, `**/security/**`, `**/*Filter.java`, `**/*.guard.ts`, `**/middleware/**` |
| [backend-reliability](backend-reliability/SKILL.md) | Reliability · observability — logging hygiene (no sensitive data) · resilience (timeout/retry/circuit) · rate limiting · dependency/supply-chain (SCA · hallucinated packages · SBOM) | `**/*Config*`, `**/logback*.xml`, `**/*Client*`, `**/build.gradle*`, `**/pom.xml`, `**/package.json` |

## Vibe-guard gist

AI-generated backend code is fast but frequently vulnerable (empirically ~40% of Copilot code has a
security flaw, and AI-assisted commits leak secrets ~2x as often as humans'). `backend-security-guard` fills that
gap as a **pre-merge review guard** — it auto-loads when you touch server source · config · Dockerfile and catches
the most common vulnerable patterns. The other 5 skills are the deep rules this guard references.

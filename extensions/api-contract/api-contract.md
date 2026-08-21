# API Contract

The complete set of rules for the 5 API contract items.
This file is loaded only when the user opts in.

## Application Rules

- On opt-in, every item is treated as a **blocking constraint**.
- FAIL items must be resolved within the corresponding UOW.
- The artifact is generated at `aidlc-docs/features/<feature-slug>/extensions/api-contract.md`.

---

## API-01. API Versioning Strategy

**Evaluation criteria**:
- PASS: A versioning strategy is specified (one of URL path, header, or query param). Versions for new/changed APIs are defined.
- FAIL: No versioning strategy defined; possibility of version conflict with existing APIs.
- N/A: Internal-only API with no need for versioning.

**Typical action**: URL path versioning (`/v1/`, `/v2/`) recommended; define the criteria for bumping versions (on breaking changes).
**Brownfield consideration**: Consistency with the existing versioning scheme, client migration plan.

## API-02. Request/Response Schema Definition

**Evaluation criteria**:
- PASS: The request/response schema for every API is explicitly defined. Required/optional fields, data types, and constraints are included.
- FAIL: Schema not defined, unclear field types, missing constraints.
- N/A: Event-based communication with no schema.

**Typical action**: Write an OpenAPI/Swagger spec, auto-generate docs from DTO classes, validate with JSON Schema.
**Brownfield consideration**: Consistency with existing API schemas, adherence to field naming conventions.

## API-03. Error Response Standard

**Evaluation criteria**:
- PASS: The error response format is consistent (error code, message, detail). HTTP status codes are used according to their meaning. Business error codes are defined.
- FAIL: Inconsistent error format, misused status codes (500 for all errors), error codes not defined.
- N/A: Read-only API with no errors.

**Typical action**: Define a standard error response format, a business error code table, prevent exposure of internal information.
**Brownfield consideration**: Consistency with the existing error format, impact on client error handling.

## API-04. Backward Compatibility

**Evaluation criteria**:
- PASS: Backward compatibility is reviewed when changing existing APIs. If there is a breaking change, a migration plan is established. A deprecation policy is specified.
- FAIL: Backward compatibility not reviewed, breaking changes applied without a plan, impact on existing clients not analyzed.
- N/A: Only new APIs added (no changes to existing ones).

**Typical action**: Allow field additions; bump the version for field removals/changes; announce a deprecation period (at least 2 weeks).
**Brownfield consideration**: Identify the list of existing clients, analyze the scope of impact, gradual migration.

## API-05. API Documentation

**Evaluation criteria**:
- PASS: OpenAPI/Swagger or equivalent documentation is written. Example requests/responses are included. Authentication/authorization requirements are specified.
- FAIL: Documentation not written, examples not included, authentication requirements missing.
- N/A: Internal event-based communication with no need for API documentation.

**Typical action**: Auto-generate OpenAPI from code, provide Swagger UI, verify doc synchronization when the API changes.
**Brownfield consideration**: Integration with existing documentation tools, identifying undocumented APIs.

---

## Artifact Format

```markdown
# API Contract

> **Request Anchor**: {summary of the initial request}

## API Contract Checklist

| ID | Item | Status | Notes |
|----|------|------|------|
| API-01 | Versioning strategy | PASS / FAIL / N/A | |
| API-02 | Request/response schema | PASS / FAIL / N/A | |
| API-03 | Error response standard | PASS / FAIL / N/A | |
| API-04 | Backward compatibility | PASS / FAIL / N/A | |
| API-05 | API documentation | PASS / FAIL / N/A | |

## Findings

### API-{NN}. {item name}
- Status: PASS / FAIL / N/A
- Current state: {current application status}
- Action required: {required action or "none"}
- Related UOW: UOW-{N} / not applicable

## Summary
- Total items: 5
- PASS: {N}
- FAIL: {N}
- N/A: {N}
- If any item is FAIL, it must be resolved during the implementation of the corresponding UOW.
```

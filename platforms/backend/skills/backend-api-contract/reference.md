# backend-api-contract — Reference

Deeper material for `SKILL.md`. Error envelope · validation · versioning · CORS ·
pagination samples.

## 1. Error envelope (single format, no stack traces)

Map exception→status code→envelope in one global handler.

```kotlin
// Spring: @RestControllerAdvice — stack trace to logs only, generalized to the client
data class ApiError(
    val code: String,           // "VALIDATION_FAILED", "NOT_FOUND" ...
    val message: String,        // user-safe message (no internal info)
    val fieldErrors: List<FieldError> = emptyList(),
    val traceId: String,        // correlates with server logs (instead of a stack trace)
)

@RestControllerAdvice
class GlobalExceptionHandler {
    private val log = LoggerFactory.getLogger(javaClass)

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun onValidation(e: MethodArgumentNotValidException): ResponseEntity<ApiError> =
        ResponseEntity.badRequest().body(
            ApiError("VALIDATION_FAILED", "The request is invalid",
                e.bindingResult.fieldErrors.map { FieldError(it.field, it.defaultMessage ?: "") },
                traceId())
        )

    @ExceptionHandler(Exception::class)               // last line of defense: never expose a stack trace
    fun onUnexpected(e: Exception): ResponseEntity<ApiError> {
        val id = traceId()
        log.error("unhandled traceId={}", id, e)      // details to the server log only
        return ResponseEntity.status(500)
            .body(ApiError("INTERNAL", "A temporary error occurred", traceId = id))
    }
}
```

```typescript
// Nest: global ExceptionFilter — same principle
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(err: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    const traceId = randomUUID();
    if (err instanceof HttpException) {
      res.status(err.getStatus()).json({ code: err.name, message: err.message, traceId });
    } else {
      this.logger.error({ traceId, err });            // details to the log only
      res.status(500).json({ code: 'INTERNAL', message: 'A temporary error occurred', traceId });
    }
  }
}
```

## 2. Input validation — controller boundary

```kotlin
data class CreateOrderRequest(
    @field:NotBlank val sku: String,
    @field:Min(1) @field:Max(999) val quantity: Int,
    // note: do not put internal fields like userId/role/status on the request DTO (over-binding)
)

@PostMapping("/orders")
fun create(@Valid @RequestBody req: CreateOrderRequest, auth: Principal): OrderResponse =
    orderService.place(auth.userId, req.sku, req.quantity).toResponse()
    // userId comes from the authenticated principal, not the request body (never trust the request body)
```

```typescript
// Node: boundary validation with zod + whitelist parsing
const CreateOrder = z.object({ sku: z.string().min(1), quantity: z.number().int().min(1).max(999) });
// zod drops fields outside the schema, so it also helps prevent over-binding
const body = CreateOrder.parse(req.body);
```

## 3. Versioning / backward compatibility

| Change | Compatibility | Handling |
|--------|---------------|----------|
| Add field (optional) | compatible | deploy as-is |
| Remove field | breaking | new version or deprecation cycle + approval |
| Retype/change field meaning | breaking | new version + approval |
| Add enum value | potentially breaking | verify client handles unknown |

- For a public API with consumers, **additive-only** is the default. Breaking changes
  go in `/v2` or an explicit deprecation.
- When opting in to the option, follow the `extensions/api-contract/` rules.

## 4. CORS (no wildcard + credentials)

```kotlin
@Bean
fun corsConfigurationSource(): CorsConfigurationSource {
    val cfg = CorsConfiguration().apply {
        allowedOrigins = listOf("https://app.example.com")   // allowlist, no "*"
        allowedMethods = listOf("GET", "POST", "PUT", "DELETE")
        allowCredentials = true                              // with credentials, origin "*" is not allowed
    }
    return UrlBasedCorsConfigurationSource().apply { registerCorsConfiguration("/**", cfg) }
}
```

- `allowCredentials = true` and `allowedOrigins = ["*"]` cannot be used together (the
  browser rejects it). Always use an explicit origin allowlist.

## 5. Pagination (no unbounded returns)

```kotlin
@GetMapping("/orders")
fun list(@RequestParam(defaultValue = "0") page: Int,
         @RequestParam(defaultValue = "20") size: Int): Page<OrderResponse> {
    val capped = size.coerceIn(1, 100)                       // enforce a cap (API4:2023 resource consumption)
    return orderService.list(PageRequest.of(page, capped)).map { it.toResponse() }
}
```

## 6. Review checklist

- [ ] Response is a DTO, not an entity.
- [ ] Request DTO accepts only allowed fields (over-binding prevention). userId/role from the authenticated principal.
- [ ] Input validation present at the controller boundary.
- [ ] Single error envelope + global handler. No stack-trace/internal-info exposure.
- [ ] Status-code convention followed (400/401/403/404/409/429).
- [ ] Change is additive. If breaking, version/approval.
- [ ] CORS origin allowlist (no wildcard + credentials).
- [ ] Pagination/cap on lists.
- [ ] Contract recorded in the technical design.

## Official references

- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- REST Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html
- Mass Assignment Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html
- Error Handling Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html
- Spring Validation: https://docs.spring.io/spring-framework/reference/core/validation/beanvalidation.html
- Team baseline: [../../guidance.md](../../guidance.md)

# kmp-navigation-platform — Reference

Deep-dive for `SKILL.md`. Compose Navigation config, deep-link validation,
expect/actual adapter patterns. Decision criteria live in `SKILL.md`.

## 1. Destinations as data (Compose Navigation multiplatform)

```kotlin
// Centralized, type-safe destinations — screens navigate by destination type, not ad-hoc.
@Serializable object HomeDestination
@Serializable data class OrderDestination(val id: Int)
@Serializable object NotFoundDestination

// NavHost wires destinations centrally
@Composable
fun AppNavHost(navController: NavHostController) {
    NavHost(navController = navController, startDestination = HomeDestination) {
        composable<HomeDestination> { HomeScreen(navController) }
        composable<OrderDestination> { backStackEntry ->
            val dest = backStackEntry.toRoute<OrderDestination>()
            val id = parseOrderId(dest.id) // validate → below
            if (id == null) navController.navigate(NotFoundDestination)
            else OrderScreen(id = id, navController = navController)
        }
    }
}

// ❌ elsewhere: navController.navigate("order/$rawId") with no validation
// ✅ navController.navigate(OrderDestination(id = validatedId))
```

## 2. Deep-link parameter validation (untrusted input)

```kotlin
// External links are untrusted. Parse, type-check, reject — never pass raw to a repo.
fun parseOrderId(raw: Int?): OrderId? {
    if (raw == null || raw <= 0) return null  // reject bad input → caller navigates to NotFound
    return OrderId(raw)
}

// Redirect targets from a link must be allowlisted — do not honor an arbitrary next= URL
fun safeRedirect(next: String?): String? {
    val allowed = setOf("/home", "/orders", "/profile")
    return if (next != null && next in allowed) next else null // else fall back to default
}
```

- Do not trust a deep link to name an internal route or an external URL directly
  (open-redirect / unauthorized navigation) → [kmp-security](../kmp-security/SKILL.md).

## 3. expect/actual platform adapter (the KMP platform boundary)

```kotlin
// commonMain — expect declaration: domain language. commonMain depends only on this.
expect class ShareService {
    suspend fun shareText(text: String)
}

// androidMain — actual for Android
actual class ShareService {
    actual suspend fun shareText(text: String) {
        // Android Intent lives here, invisible to commonMain
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        try {
            appContext.startActivity(Intent.createChooser(intent, null))
        } catch (e: ActivityNotFoundException) {
            throw ShareFailure.NoApp  // platform error → domain failure
        }
    }
}

// iosMain — actual for iOS
actual class ShareService {
    actual suspend fun shareText(text: String) {
        // UIActivityViewController lives here, invisible to commonMain
        suspendCoroutine { cont ->
            val controller = UIActivityViewController(listOf(text), null)
            UIApplication.sharedApplication.keyWindow?.rootViewController
                ?.presentViewController(controller, true) { cont.resume(Unit) }
                ?: cont.resumeWithException(ShareFailure.NoViewController)
        }
    }
}
```

```kotlin
// ❌ Anti-pattern: platform API called directly from commonMain Composable
Button(onClick = {
    // This won't compile in commonMain — and if it did, it would be wrong
    Intent(Intent.ACTION_SEND) // android.* import in commonMain = build error
})

// ❌ Anti-pattern: platform branch in commonMain feature code
if (getPlatform().name.contains("android")) { /* ... */ } // scattered, not an adapter
```

## 4. Voyager navigation (alternative)

```kotlin
// Destinations are Screen objects — same "centralized, typed" principle.
class HomeScreen : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        HomeContent(
            onOrderClick = { id ->
                val validated = parseOrderId(id)
                if (validated != null) navigator.push(OrderScreen(validated))
                else navigator.push(NotFoundScreen())
            }
        )
    }
}
```

- Same rules: validate before navigating, no scattered nav calls, one system only.

## 5. Navigation / platform review checklist

- [ ] All navigation goes through the project's chosen solution (no scattered ad-hoc nav calls).
- [ ] Deep-link/external params validated/typed before mapping to a destination.
- [ ] Redirect targets from links are allowlisted (no open redirect).
- [ ] Platform API calls only inside `actual` implementations, never in `commonMain`.
- [ ] Platform decision made once in `actual`, not in `commonMain` Composables.
- [ ] Platform errors mapped to domain failures at the `actual` boundary.
- [ ] One navigation system in the app (Compose Navigation or Decompose or Voyager).

## Official references

- Compose Multiplatform Navigation: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-navigation-routing.html
- Type-safe navigation: https://developer.android.com/guide/navigation/design/type-safety
- Decompose: https://arkivanov.github.io/Decompose/
- Voyager: https://voyager.adriel.cafe/
- expect/actual: https://kotlinlang.org/docs/multiplatform-expect-actual.html
- Team baseline: [../../guidance.md](../../guidance.md)

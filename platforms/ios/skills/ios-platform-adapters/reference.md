# ios-platform-adapters — Reference

Deep-dive for `SKILL.md`. Protocol adapters, permission state, repository
mapping, storage placement. Decision criteria live in `SKILL.md`.

## 1. Platform framework behind a protocol adapter

```swift
// Protocol: domain language. Callers depend on this, not CoreLocation.
protocol LocationProviding: Sendable {
    func current() async throws -> Coordinate
}

// Adapter: the ONLY place CoreLocation is imported. Injected into callers.
import CoreLocation
final class CoreLocationAdapter: NSObject, LocationProviding {
    func current() async throws -> Coordinate {
        switch manager.authorizationStatus {
        case .denied, .restricted: throw LocationError.permissionDenied   // typed, designed
        case .notDetermined:       // request, then continue
            break
        default: break
        }
        let loc = try await requestOnce()
        return Coordinate(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude) // → domain
    }
}

// ❌ a ViewModel importing CoreLocation and holding a CLLocationManager directly
```

## 2. Permission-denied is a designed state

```swift
enum LocationPermission { case undetermined, granted, denied }

// The ViewModel maps permission to state; the View renders a path per case (→ ios-state-concurrency)
switch permission {
case .undetermined: RequestPrompt(onTap: request)
case .denied:       PermissionDeniedView(onOpenSettings: openSettings)  // not an error toast
case .granted:      MapView(...)
}
```

## 3. Repository returns domain, maps DTO + errors

```swift
// DTO↔domain mapping in the data layer; domain has no SwiftUI/UIKit.
struct OrderDTO: Decodable { let id: Int; let total_cents: Int }
struct Order { let id: OrderID; let total: Money }   // pure domain

final class OrderRepository {
    private let client: HTTPClient
    func order(_ id: OrderID) async throws -> Order {
        do {
            let dto = try await client.get("/orders/\(id.value)", as: OrderDTO.self)
            return Order(id: OrderID(dto.id), total: Money(minorUnits: dto.total_cents)) // map
        } catch let e as URLError {
            throw OrderFailure.network(e.code)       // typed failure, not raw NSError
        }
    }
}
```

## 4. Storage placement: UserDefaults vs repository vs Keychain

```swift
// ✅ small preference behind an adapter
protocol Preferences { var hasOnboarded: Bool { get set } }
struct UserDefaultsPreferences: Preferences {
    var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: "hasOnboarded") }
        set { UserDefaults.standard.set(newValue, forKey: "hasOnboarded") }
    }
}

// ✅ secret in Keychain — NEVER UserDefaults → ios-security
try Keychain.set(token, for: "auth_token")

// ❌ UserDefaults.standard.set(jwt, forKey: "token")   // secret in cleartext plist
// structured data → the repository/persistence layer, not UserDefaults
```

## 5. Inject the protocol; test with a fake

```swift
// ✅ fake conforms to the protocol — no device framework in tests
struct FakeLocation: LocationProviding { func current() async throws -> Coordinate { .init(lat: 1, lng: 2) } }
let vm = NearbyViewModel(location: FakeLocation())
// ❌ mocking CLLocationManager directly — brittle, needs the framework
```

## 6. Review checklist

- [ ] System frameworks wrapped in a project-owned protocol adapter, injected.
- [ ] Permission-denied is a designed UI state (not an error/crash).
- [ ] Repositories return domain models; DTO↔domain mapped in the data layer.
- [ ] Domain models import no SwiftUI/UIKit.
- [ ] Native/system errors mapped to typed failures at the boundary.
- [ ] Small prefs via a `UserDefaults` adapter; structured data via the repository.
- [ ] Secrets in Keychain, never `UserDefaults`.
- [ ] Tests inject a protocol fake, not the concrete framework.

## Official references

- CoreLocation authorization: https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services
- Keychain services: https://developer.apple.com/documentation/security/keychain-services
- UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
- Protocols & dependency injection: https://developer.apple.com/documentation/swift/adopting-common-protocols
- Team baseline: [../../guidance.md](../../guidance.md)

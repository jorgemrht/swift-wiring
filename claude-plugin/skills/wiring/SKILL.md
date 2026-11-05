---
name: wiring
description: Guide to Wiring, a lightweight main-actor dependency injection library for Swift and SwiftUI. Use it whenever code imports Wiring, declares providers in `extension Container`, uses `@Injected(\.…)`, `Provider<…>`, `Container.current`, `Container.withIsolatedContainer`, `Container.preview`, the `.container` preview trait, `unimplemented()`, lifetimes (`.unique`, `.cached`, `.session`, `.shared`), `register`/`unregister`/`reset`, or `onResolve`; when writing or fixing tests or SwiftUI previews of stores that use Wiring; or when the user asks how to inject, mock or reset a dependency in a project that depends on swift-wiring.
---

# Wiring

Wiring declares each dependency once, as a computed property on `Container` with a default factory, and hands it out on demand. There is no registration step at launch, so "not registered" never fails at runtime. Everything is isolated to the main actor. The authoritative documentation is the package README and the DocC catalog at `Sources/Wiring/Wiring.docc/`.

## Mental model

- **Container**: where dependencies are declared and where kept instances live.
- **Provider**: the entry point for one dependency, a property on `Container`.
- **Factory**: the closure that builds the dependency. The one in the declaration is the *default factory*; one set with `register` is a *registration* and wins over the default.
- **Current container**: `Container.current` is the root container in the app, and the isolated container inside `Container.withIsolatedContainer`.

## Declare

```swift
import Wiring

extension Container {
    var authRepository: Provider<any AuthRepository> {
        self { AuthRepositoryImpl() }                 // .unique: new instance every time
    }

    var networkClient: Provider<any NetworkClient> {
        self(.cached) { URLSessionNetworkClient() }   // one per container
    }

    var sessionStore: Provider<SessionStore> {
        self(.session) { SessionStore() }             // discarded by reset(.session)
    }

    var syncEngine: Provider<SyncEngine> {
        self { SyncEngine(network: self.networkClient()) }   // dependencies of a non-main-actor type
    }
}
```

The default lifetime is `.unique`. Pass the lifetime as the first argument; there are no modifiers after the closure.

## Use

```swift
@Observable @MainActor
final class LoginStore {
    @ObservationIgnored @Injected(\.authRepository) private var authRepository
}
```

- `@Injected` resolves on first read and keeps the value; creating the store resolves nothing.
- Inside `@Observable`, `@ObservationIgnored` is mandatory. There is no way around it.
- Outside a property wrapper: `Container.current.authRepository()`.
- A store that must use a specific container takes it in its initializer: `_service = Injected(\.service, container: container)`.

## Replace and reset

| Call | Effect |
|---|---|
| `provider.register { … }` | Replaces the factory. The last registration wins. Discards the kept instance. |
| `provider.unregister()` | Back to the default factory. Discards the instance it built. |
| `provider.reset()` | Discards the kept instance only. |
| `container.reset(.cached)` / `.session` / `.shared` | Discards instances with that lifetime only. |

`.shared` keeps one instance while something holds it (the stores of a flow share a cart) and builds a new one once nothing does. Classes only: in DEBUG a value type stops with a message.
| `container.reset()` | Discards every registration and every instance. |

## Tests

```swift
@Test @MainActor
func aSuccessfulLoginLogsIn() async {
    await Container.withIsolatedContainer {
        Container.current.authRepository.register { AuthRepositoryMock() }
        let store = LoginStore()
        await store.login()
        #expect(store.isLoggedIn)
    }
}
```

Each test gets its own empty container, so tests run in parallel. The swift-wiring-mocks package offers the same as a trait, `@Test(.isolatedContainer { $0.x.register { … } })`, also on a `@Suite`. With `.isolatedContainer(strict: true) { … }`, a test fails when it resolves anything it did not register, or when it resolves from the root container while it runs (escaping work such as `Task.detached`). In a strict test, register even the dependencies that are safe to use for real. XCTest has no traits: call `Container.current.reset()` in `setUp` and keep the tests serial.

## Previews

```swift
#Preview(traits: .container { $0.authRepository.register { AuthRepositoryMock(isSignedIn: true) } }) {
    LoginView()
}
```

The `.container` trait (a `PreviewModifier`, iOS 18 / macOS 15 and later) resets the root container and applies the registrations before the views read them; previews share the root container, so every preview should use it. On iOS 17, write `Container.preview { … }` as the first line of the preview instead.

## Modules and windows

- A module that cannot see the implementation declares `public var paymentService: Provider<any PaymentService> { unimplemented(.cached) }` and the app registers it at launch.
- Multiple windows: one `Container()` per window, passed to stores as `windowContainer`; common dependencies come from `Container.current`.

## Common gotchas

- **Missing `@ObservationIgnored`** on `@Injected` inside `@Observable`: compile error "property wrapper cannot be applied to a computed property".
- **Registering too late**: a store that already read its `@Injected` property keeps the old value. Register before the first read.
- **Dependencies built from a value**: declare `var user: ParameterProvider<User.ID, User> { self(.cached) { id in User(id: id) } }` and resolve `container.user(id)`; each value keeps its own instance. A function returning `Provider` ignores its arguments in the key, so with `.cached` every id would get the first instance.
- **`Task.detached`, GCD, Combine, `NotificationCenter` callbacks** do not inherit the isolated container; `Container.current` there is the root even in tests. Use `@Injected`, which captures its container at creation.
- **Resolving off the main actor** does not compile. Do not wrap it in `MainActor.assumeIsolated`; pass the dependency as an initializer parameter instead.
- **Storing a `Provider`** in a property keeps its container alive; resolve it instead.
- **Two copies of Wiring** (linked into several targets of one app): registrations vanish between them. Link Wiring into one target; DEBUG prints a warning.
- **`unimplemented()` without a registration** stops the app with "Container.<name> has no implementation"; register it at launch, in the test or in the preview.
- **A factory returning `nil`** is never kept; the next resolution, or the next read of `@Injected`, tries again.
- **Circular dependencies** stop in every build with their path, such as `a → b → a`.

## Diagnostics

`container.onResolve = { print($0.path.joined(separator: " → "), $0.source) }` reports every factory run with its path and whether it came from a registration, the default factory or an unimplemented provider.

## What Wiring does not have

No contexts (`onTest`, `onPreview`), no auto-registration, no singleton/graph/time-to-live scopes, no async factories and no SwiftUI property wrappers for views. Do not suggest them as Wiring APIs.

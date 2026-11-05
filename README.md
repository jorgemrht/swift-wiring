# swift-wiring
Lightweight dependency injection for Swift: a container with providers, lifetimes and @Injected, built for Swift 6 concurrency, SwiftUI and Swift Testing.

- One module, no dependencies.
- Dependencies are declared with a default, so "not registered" never fails at runtime.
- Isolated to the main actor: resolving from a background thread is a compile error, not a crash.
- Parallel tests, each with its own container, and previews that start from a clean state.

## Installation

Wiring requires Swift 6.4 and iOS 17, macOS 14, tvOS 17, watchOS 10 or visionOS 1.

In Xcode, choose **File › Add Package Dependencies…** and enter `https://github.com/jorgemrht/swift-wiring`. In a package:

```swift
dependencies: [
    .package(url: "https://github.com/jorgemrht/swift-wiring", from: "1.0.0-beta.1"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "Wiring", package: "swift-wiring")]),
]
```

Prereleases are only used when the requirement names one, as above. Once `1.0.0` is out, `from: "1.0.0"` is enough.

Two companion packages are installed only if you want them, and Wiring never depends on either. Each one includes the one before, so you add only the package for the level you want:

| Package | Adds |
|---|---|
| [swift-wiring-mocks](https://github.com/jorgemrht/swift-wiring-mocks) | A Swift Testing trait with an isolated container and a strict mode, and mocks generated from your protocols |
| [swift-wiring-snapshot](https://github.com/jorgemrht/swift-wiring-snapshot) | Everything in swift-wiring-mocks, plus snapshot testing for SwiftUI, UIKit and AppKit |

## Why a container?

You can inject everything through initializers, and for small types you should. In an app it stops scaling: every layer has to receive and forward dependencies it does not use itself, just to pass them further down. SwiftUI's environment does not solve it either, because it can only be read inside a view, not in the initializer of an `@Observable` store.

A **container** is the single place that knows how to build each dependency and hands it out on demand. In Wiring it also decides how long an instance lives: built fresh every time, or kept and shared.

## How Wiring works

Wiring has three pieces:

| Piece | What it is |
|---|---|
| `Container` | Where dependencies are declared and where kept instances live. |
| `Provider` | The entry point for one dependency, declared as a property on the container. |
| `@Injected` | A property wrapper that obtains a dependency from the container. |

### 1. Declare a dependency

Add a property to `Container` that returns a `Provider`. The closure is the **factory**: how to build the dependency.

```swift
import Wiring

extension Container {
    var authRepository: Provider<any AuthRepository> {
        self { AuthRepositoryImpl() }
    }
}
```

That is the whole declaration. There is no registration step at launch: if the property exists, the dependency can be resolved.

### 2. Use it

```swift
@Observable @MainActor
final class LoginStore {
    var email = ""
    var password = ""
    private(set) var isLoggedIn = false
    @ObservationIgnored @Injected(\.authRepository) private var authRepository

    func login() async {
        isLoggedIn = (try? await authRepository.login(email: email, password: password)) != nil
    }
}
```

`@Injected` does nothing when the store is created. It builds the dependency the first time the property is read, and keeps it from then on, unless it is `nil`. This matters in SwiftUI, where a view's initializer runs every time its parent's body is evaluated: a store created there, or in a `@State` property that is not `private`, is built again each time and thrown away, so creating a store must be cheap.

Inside `@Observable`, `@ObservationIgnored` is required: the macro turns every stored property into a tracked one, and a property wrapper cannot be applied to a tracked property. A dependency is not state the view observes, so ignoring it is also what it means.

Outside a property wrapper, call the provider directly:

```swift
let authRepository = Container.current.authRepository()
```

### 3. Replace it when you need to

`register` replaces the factory of a provider. Use it to configure the app at launch, or to substitute a mock in tests and previews:

```swift
@main
struct MyApp: App {
    init() {
        Container.current.environment.register { .production }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```

A provider has at most one registration at a time: registering again replaces the previous one, and the last registration wins. This lets you register defaults first and specialize one afterwards:

```swift
Container.current.authRepository.register { AuthRepositoryMock() }
Container.current.authRepository.register { AuthRepositoryMock(isSignedIn: true) }   // this one wins
```

`unregister()` removes the registration and goes back to the factory declared in step 1:

```swift
Container.current.authRepository.unregister()
```

Registering or unregistering also discards the instance the previous factory had kept, so the next resolution always uses the factory now in effect.

## Lifetimes

**By default, every resolution builds a new instance.** To share one, say so in the declaration:

```swift
extension Container {
    var networkClient: Provider<any NetworkClient> {
        self(.cached) { URLSessionNetworkClient() }
    }

    var sessionStore: Provider<SessionStore> {
        self(.session) { SessionStore() }
    }
}
```

| Lifetime | Instances |
|---|---|
| `.unique` (default) | A new instance on every resolution. |
| `.cached` | One per container, kept until it is reset. |
| `.session` | Like `.cached`, but discarded on its own by `reset(.session)`, for example on logout. |
| `.shared` | One while something else holds it, such as the stores of a flow; a new one once nothing does. Classes only. |

The stores that use a dependency never change when its lifetime does. A factory that returns `nil` is never kept, so the next resolution tries again; `@Injected` does the same.

### Sharing an instance while something uses it

`.shared` keeps one instance while something else holds it, and builds a new one once nothing does. The stores of a checkout flow get the same cart while their screens are alive; when the flow closes and its stores are released, the cart goes away with them, and the next flow starts with a new one.

```swift
extension Container {
    var cart: Provider<any Cart> {
        self(.shared) { ShoppingCart() }
    }
}
```

The container keeps a weak reference, so whoever holds the instance decides how long it lives: a store's `@Injected` property holds it for as long as the store exists. Only classes can be shared; in DEBUG, a factory that returns a value type stops with a message, because a weak reference cannot hold it and every resolution would build a new one.

When one object already lives for the whole flow, such as the store of its first screen, passing the cart from it is simpler and needs no lifetime.

### Resetting

`reset` discards instances; `unregister` undoes a registration.

| Call | What it discards |
|---|---|
| `Container.current.reset()` | Everything: every registration and every kept instance. The container is back to its initial state. |
| `Container.current.reset(.cached)` | Every `.cached` instance. Registrations stay. |
| `Container.current.reset(.session)` | Every `.session` instance. Registrations stay. |
| `Container.current.reset(.shared)` | Every `.shared` instance, even while something still holds it. Registrations stay. |
| `Container.current.networkClient.reset()` | The kept instance of that one provider. Its registration stays. |
| `Container.current.environment.unregister()` | The registration of that one provider, and the instance it built. |

Stores that already read an `@Injected` property keep the value they have; a reset affects the next resolution.

## The current container

`Container.current` answers one question: *which container should this code use right now?*

- **In the app** it is always the same one, the **root container**. That is what makes a registration in `MyApp.init` visible to every store, and what makes `.cached` instances shared across the app.
- **Inside an isolated container** it is a fresh, empty container that belongs to that piece of work only, typically one test.

The name follows Apple's convention: `URLSession.shared` is always the same object, while `Locale.current` or `Calendar.current` is the one in effect for the current context. The container belongs to the second group.

## Testing

Run each test inside an isolated container. Tests run in parallel, and each one sees its own `Container.current`:

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

The isolated container lives in a task local, so the `@Injected` inside `LoginStore` picks it up without any change to production code. When the operation ends, `Container.current` is the root container again.

With swift-wiring-mocks, the same test is a trait, `@Test(.isolatedContainer { $0.authRepository.register { AuthRepositoryMock() } })`, and a strict mode fails the test if it reaches a real implementation.

## Previews

Previews in the same canvas share the root container, so a registration made by one preview would leak into the next. Give each preview the `.container` trait, which resets the container and applies your registrations before the preview's views read their dependencies:

```swift
#Preview("Wrong password", traits: .container { $0.authRepository.register { AuthRepositoryMock(error: .invalidCredentials) } }) {
    LoginView()
}
```

The trait is a `PreviewModifier`, the mechanism SwiftUI uses for preview setup since iOS 18, macOS 15, tvOS 18, watchOS 11 and visionOS 2. On iOS 17, start the preview with `Container.preview { … }` instead, which does the same as its first line.

In DEBUG, both print a warning in the console whenever the preview resolves a dependency with its default factory, which usually means the preview is about to reach the network.

## Modules without the implementation

A module that declares a protocol often cannot see its implementation. Declare the provider as `unimplemented()` and register the implementation at launch:

```swift
// Payments module
extension Container {
    public var paymentService: Provider<any PaymentService> {
        unimplemented(.cached)
    }
}

// App
Container.current.paymentService.register { StripePaymentService() }
```

Resolving it without a registration stops the app with a message that names what is missing: *Container.paymentService has no implementation. Register one at launch (Payments/Container+Payments.swift).*

## Creating your own container

`Container.current` is a convenience, not a requirement. You can create a container and pass it explicitly:

```swift
@Observable @MainActor
final class CheckoutStore {
    @ObservationIgnored @Injected private var paymentService: any PaymentService

    init(container: Container = .current) {
        _paymentService = Injected(\.paymentService, container: container)
    }
}

let container = Container()
container.paymentService.register { PaymentServiceMock() }
let store = CheckoutStore(container: container)
```

A container you create starts empty: no registrations and no kept instances. It sees every provider declared in your `Container` extensions, because declarations belong to the type, not to an instance.

| | `Container.current` | A container you create |
|---|---|---|
| Who uses it | `@Injected`, and any code that asks for it | Only the code you pass it to |
| In the app | The root container, one for the whole app | A separate container with its own registrations and instances |
| In an isolated container | That isolated container | Unaffected |

## Multiple windows

In an app with several windows or scenes, some dependencies are common to the whole app (the network client, the database) and others belong to one window (its navigation, a draft being written). Use the current container for the common ones and create one container per window for the rest. Each store says, property by property, where a dependency comes from:

```swift
struct WindowRoot: View {
    @State private var windowContainer = Container()      // one per window

    var body: some View {
        InboxView(windowContainer: windowContainer)
    }
}

@Observable @MainActor
final class InboxStore {
    @ObservationIgnored @Injected private var database: Database
    @ObservationIgnored @Injected private var draftStore: DraftStore

    init(container: Container = .current, windowContainer: Container) {
        _database = Injected(\.database, container: container)              // common to every window
        _draftStore = Injected(\.draftStore, container: windowContainer)    // this window only
    }
}
```

With two windows open, both share the same `database`, and each has its own `draftStore`, even though both are declared `.cached`: each window container keeps its own instances.

## The main actor

`Container`, `Provider` and `@Injected` are isolated to the main actor, where stores and views already live, so the compiler rejects a resolution from a background thread instead of letting it fail at runtime. A type that does not live on the main actor receives its dependencies as initializer parameters, resolved inside its factory:

```swift
extension Container {
    var syncEngine: Provider<SyncEngine> {
        self { SyncEngine(network: self.networkClient()) }
    }
}
```

## Diagnostics

- **Circular dependencies.** A dependency that needs itself stops with its path, in every build: *Circular dependency: cycleA → cycleB → cycleA.* Without that, it would recurse until the stack overflows.
- **Two copies of Wiring.** If two targets each link their own copy of Wiring into the same app, registrations made in one copy are invisible to the other. In DEBUG, Wiring prints a warning when it detects a second copy. Link Wiring into a single target per binary.
- **`onResolve`.** Every time a factory runs, the container reports what was resolved, the path that led to it and whether the factory was a registration, the default or unimplemented:

```swift
Container.current.onResolve = { resolution in
    print(resolution.path.joined(separator: " → "), resolution.source)
}
```

## Recipes

### Date, UUID and clocks

A store that calls `Date()` or `UUID()` cannot be tested. Declare them as dependencies:

```swift
extension Container {
    var now: Provider<() -> Date> {
        self { Date.init }
    }

    var uuid: Provider<() -> UUID> {
        self { UUID.init }
    }

    var clock: Provider<any Clock<Duration>> {
        self { ContinuousClock() }
    }
}

// In a test
Container.current.now.register { { Date(timeIntervalSince1970: 0) } }
```

### Logout

```swift
func logout() async {
    await authRepository.logout()
    Container.current.reset(.session)
}
```

### App environment

```swift
extension Container {
    var environment: Provider<AppEnvironment> {
        self(.cached) { .production }
    }
}

// MyApp.init
#if DEBUG
Container.current.environment.register { .staging }
#endif
```

### Providers with parameters

A dependency built from a value, such as the repository of one user, is a `ParameterProvider`. Its factory receives the value, and the lifetime applies to each value: with `.cached`, every `id` keeps its own instance.

```swift
extension Container {
    var userRepository: ParameterProvider<User.ID, UserRepository> {
        self(.cached) { id in UserRepository(id: id) }
    }
}

let repository = Container.current.userRepository(user.id)
```

A registration replaces the factory for every value, `Container.current.userRepository.register { id in UserRepositoryMock(id: id) }`, and `reset()` discards the instances of every value. `@Injected` cannot pass a value, so resolve it where the value is known, usually in the store's initializer.

Do not write a function that returns a `Provider` instead: its key ignores the arguments, so with `.cached` every `id` would get the first instance.

### Work that escapes the task

An isolated container lives in a task local. `Task {}` inherits it, but `Task.detached`, GCD, Combine and `NotificationCenter` callbacks do not: inside them, `Container.current` is the root container even during a test. Read dependencies through `@Injected`, which captures its container when it is created, or resolve them before the work escapes.

### Do not keep a `Provider`

A `Provider` holds its container. Resolve it instead of storing it in a property; a provider stored inside an instance the container keeps would never be released.

### XCTest

XCTest has no traits. Reset the root container before each test, and do not run the tests in parallel inside one process:

```swift
final class LoginStoreTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run { Container.current.reset() }
    }
}
```

## Claude Code

The repository is also a Claude Code marketplace with a `wiring` skill that teaches Claude how to declare, use, test and preview dependencies with Wiring, and the mistakes to avoid. In a Claude Code session:

```
/plugin install wiring --marketplace jorgemrht/swift-wiring
```

On versions before 2.1.275, add the marketplace first with `/plugin marketplace add jorgemrht/swift-wiring`, then run `/plugin install wiring@swift-wiring`.

## License

MIT. See [LICENSE](LICENSE).

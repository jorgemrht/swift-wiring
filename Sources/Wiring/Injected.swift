/// A dependency resolved the first time it is read and kept from then on. A `nil` is not kept: the next read resolves again.
@MainActor @propertyWrapper
public final class Injected<Value> {
    private let container: Container
    private let keyPath: KeyPath<Container, Provider<Value>>
    private var resolved: Value?

    /// Captures `container` without resolving anything. Inside `@Observable`, mark the property `@ObservationIgnored`.
    public init(_ keyPath: KeyPath<Container, Provider<Value>>, container: Container = .current) {
        self.container = container
        self.keyPath = keyPath
    }

    /// The dependency, resolved on first access.
    public var wrappedValue: Value {
        if let resolved {
            return resolved
        }
        let value = container[keyPath: keyPath]()
        if !isNone(value) {
            resolved = value
        }
        return value
    }
}

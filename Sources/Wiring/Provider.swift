/// The entry point for one dependency, declared as a property on ``Container``.
@MainActor
public struct Provider<Value> {
    let container: Container
    let key: ProviderKey
    let lifetime: Lifetime
    let source: Resolution.Source
    let factory: () -> Value

    /// Resolves the dependency.
    public func callAsFunction() -> Value {
        container.resolve(self)
    }

    /// Replaces the factory. The last registration wins, and the kept instance is discarded.
    public func register(_ factory: @escaping () -> Value) {
        container.register(factory, for: key)
    }

    /// Removes the registration, going back to the declared factory, and discards the kept instance.
    public func unregister() {
        container.unregister(key)
    }

    /// Discards the kept instance. The registration stays.
    public func reset() {
        container.discardInstance(for: key)
    }
}

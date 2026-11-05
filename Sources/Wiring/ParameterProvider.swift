/// The entry point for a dependency built from a parameter, such as the repository of one user, declared as a property on ``Container``.
///
/// The lifetime applies to each parameter value: with ``Lifetime/cached``, every value keeps its own instance.
@MainActor
public struct ParameterProvider<Parameter: Hashable, Value> {
    let container: Container
    let key: ProviderKey
    let lifetime: Lifetime
    let factory: (Parameter) -> Value

    /// Resolves the dependency for `parameter`.
    public func callAsFunction(_ parameter: Parameter) -> Value {
        container.resolve(self, parameter: parameter)
    }

    /// Replaces the factory for every parameter value. The last registration wins, and the kept instances are discarded.
    public func register(_ factory: @escaping (Parameter) -> Value) {
        container.register(factory, for: key)
    }

    /// Removes the registration, going back to the declared factory, and discards the kept instances.
    public func unregister() {
        container.unregister(key)
    }

    /// Discards the kept instances of every parameter value. The registration stays.
    public func reset() {
        container.discardInstance(for: key)
    }
}

/// The place where dependencies are declared and where kept instances live.
@MainActor
public final class Container {
    nonisolated static let root: Container = {
        #if DEBUG && canImport(ObjectiveC)
        LoadedCopies.check()
        #endif
        return Container()
    }()

    nonisolated static let isolated = TaskLocal<Container?>(wrappedValue: nil)

    /// The container in effect: the isolated container inside ``withIsolatedContainer(_:)``, otherwise the root container.
    public static var current: Container {
        isolated.get() ?? root
    }

    /// Called every time a factory runs, with what was resolved and where its factory comes from.
    public var onResolve: ((Resolution) -> Void)?

    private var registrations: [ProviderKey: Any] = [:]
    private var instances: [ProviderKey: CachedInstance] = [:]
    private var parameterInstances: [ProviderKey: [AnyHashable: CachedInstance]] = [:]
    private var resolutionPath: [ProviderKey] = []
    private var parametersBeingResolved: [ProviderKey: [AnyHashable]] = [:]

    /// Creates an empty container.
    public nonisolated init() {}

    /// Declares a provider whose default factory is `factory`.
    public func callAsFunction<Value>(
        _ lifetime: Lifetime = .unique,
        name: StaticString = #function,
        file: StaticString = #fileID,
        factory: @escaping () -> Value
    ) -> Provider<Value> {
        Provider(
            container: self,
            key: ProviderKey(Value.self, name: name, file: file),
            lifetime: lifetime,
            source: .defaultFactory,
            factory: factory
        )
    }

    /// Declares a provider whose default factory builds the dependency from a parameter, such as `self(.cached) { id in UserRepository(id: id) }`.
    public func callAsFunction<Parameter: Hashable, Value>(
        _ lifetime: Lifetime = .unique,
        name: StaticString = #function,
        file: StaticString = #fileID,
        factory: @escaping (Parameter) -> Value
    ) -> ParameterProvider<Parameter, Value> {
        ParameterProvider(
            container: self,
            key: ProviderKey(Value.self, name: name, file: file),
            lifetime: lifetime,
            factory: factory
        )
    }

    /// Declares a provider without an implementation. It stops the app if it is resolved before receiving a registration.
    public func unimplemented<Value>(
        _ lifetime: Lifetime = .unique,
        name: StaticString = #function,
        file: StaticString = #fileID
    ) -> Provider<Value> {
        Provider(
            container: self,
            key: ProviderKey(Value.self, name: name, file: file),
            lifetime: lifetime,
            source: .unimplemented,
            factory: { fatalError("Container.\(name) has no implementation. Register one at launch (\(file)).") }
        )
    }

    /// Discards every registration and every kept instance.
    public func reset() {
        registrations.removeAll()
        instances.removeAll()
        parameterInstances.removeAll()
    }

    /// Discards the kept instances with `lifetime`. Registrations stay.
    public func reset(_ lifetime: Lifetime) {
        instances = instances.filter { $0.value.lifetime != lifetime }
        parameterInstances = parameterInstances.mapValues { $0.filter { $0.value.lifetime != lifetime } }
    }

    /// Runs `operation` with a new, empty container as ``current``.
    public nonisolated static func withIsolatedContainer<Output>(
        _ operation: nonisolated(nonsending) () async throws -> Output
    ) async rethrows -> Output {
        try await isolated.withValue(Container()) {
            try await operation()
        }
    }

    func resolve<Value>(_ provider: Provider<Value>) -> Value {
        let key = provider.key
        if provider.lifetime != .unique, let instance = instances[key], let value = instance.value as? Value {
            return value
        }
        if resolutionPath.contains(key) {
            stopOnCycle(at: key)
        }
        resolutionPath.append(key)
        defer { resolutionPath.removeLast() }
        let registration = registrations[key] as? () -> Value
        report(key, source: registration == nil ? provider.source : .registration)
        let value = (registration ?? provider.factory)()
        if provider.lifetime != .unique, !isNone(value) {
            #if DEBUG
            checkCanBeShared(value, lifetime: provider.lifetime, key: key)
            #endif
            instances[key] = CachedInstance(lifetime: provider.lifetime, value: value)
        }
        return value
    }

    func resolve<Parameter, Value>(_ provider: ParameterProvider<Parameter, Value>, parameter: Parameter) -> Value {
        let key = provider.key
        let argument = AnyHashable(parameter)
        if provider.lifetime != .unique, let instance = parameterInstances[key]?[argument], let value = instance.value as? Value {
            return value
        }
        if parametersBeingResolved[key, default: []].contains(argument) {
            stopOnCycle(at: key)
        }
        resolutionPath.append(key)
        parametersBeingResolved[key, default: []].append(argument)
        defer {
            resolutionPath.removeLast()
            parametersBeingResolved[key]?.removeLast()
        }
        let registration = registrations[key] as? (Parameter) -> Value
        report(key, source: registration == nil ? .defaultFactory : .registration)
        let value = (registration ?? provider.factory)(parameter)
        if provider.lifetime != .unique, !isNone(value) {
            #if DEBUG
            checkCanBeShared(value, lifetime: provider.lifetime, key: key)
            #endif
            parameterInstances[key, default: [:]][argument] = CachedInstance(lifetime: provider.lifetime, value: value)
        }
        return value
    }

    func register(_ factory: Any, for key: ProviderKey) {
        registrations[key] = factory
        discardInstance(for: key)
    }

    func unregister(_ key: ProviderKey) {
        registrations[key] = nil
        discardInstance(for: key)
    }

    func discardInstance(for key: ProviderKey) {
        instances[key] = nil
        parameterInstances[key] = nil
    }

    private func report(_ key: ProviderKey, source: Resolution.Source) {
        onResolve?(Resolution(
            name: "\(key.name)",
            file: "\(key.file)",
            path: resolutionPath.map { "\($0.name)" },
            source: source
        ))
    }

    private func checkCanBeShared<Value>(_ value: Value, lifetime: Lifetime, key: ProviderKey) {
        if lifetime == .shared, !(type(of: value as Any) is AnyClass) {
            fatalError("Container.\(key.name) is .shared, but its factory returned \(type(of: value as Any)), which is not a class. Only classes can be shared (\(key.file)).")
        }
    }

    private func stopOnCycle(at key: ProviderKey) -> Never {
        let cycle = (resolutionPath.drop { $0 != key } + [key]).map { "\($0.name)" }
        resolutionPath.removeAll()
        fatalError("Circular dependency: \(cycle.joined(separator: " → "))")
    }
}

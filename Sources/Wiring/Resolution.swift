/// A factory that ran, as reported to ``Container/onResolve``.
public struct Resolution: Sendable, Equatable {
    /// Where the factory that ran comes from.
    public enum Source: Sendable, Equatable {
        /// A factory set with ``Provider/register(_:)``.
        case registration
        /// The factory declared with the provider.
        case defaultFactory
        /// A provider declared with ``Container/unimplemented(_:name:file:)`` that has no registration.
        case unimplemented
    }

    /// The provider's name, such as `authRepository`.
    public let name: String
    /// The file that declares the provider, such as `App/Container+Repositories.swift`.
    public let file: String
    /// The providers being resolved, outermost first, ending with this one.
    public let path: [String]
    /// Where the factory that ran comes from.
    public let source: Source
}

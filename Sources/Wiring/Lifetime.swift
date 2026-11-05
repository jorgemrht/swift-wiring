/// How long a resolved instance is kept.
public enum Lifetime: Sendable {
    /// A new instance on every resolution. The default.
    case unique
    /// One instance per container, kept until it is reset.
    case cached
    /// Like ``cached``, but discarded by `reset(.session)`, for example on logout.
    case session
    /// One instance while something else holds it, such as the stores of a flow; once nothing does, the next resolution builds a new one. Only classes can be shared.
    case shared
}

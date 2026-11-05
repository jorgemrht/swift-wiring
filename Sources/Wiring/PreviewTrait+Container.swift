#if canImport(SwiftUI)
public import SwiftUI

@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
extension PreviewTrait where T == Preview.ViewTraits {
    /// Resets the current container and applies `configure` before the preview's views read their dependencies.
    ///
    /// ```swift
    /// #Preview(traits: .container { $0.authRepository.register { AuthRepositoryMock() } }) {
    ///     LoginView()
    /// }
    /// ```
    ///
    /// In DEBUG, it prints a warning whenever the preview resolves a provider with its default factory.
    public static func container(_ configure: @escaping @MainActor (Container) -> Void) -> PreviewTrait<T> {
        .modifier(ContainerPreviewModifier(configure: configure))
    }
}
#endif

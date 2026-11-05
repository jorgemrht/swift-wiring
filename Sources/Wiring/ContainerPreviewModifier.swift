#if canImport(SwiftUI)
public import SwiftUI

/// The preview modifier behind the ``DeveloperToolsSupport/PreviewTrait/container(_:)`` trait.
@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
public struct ContainerPreviewModifier: PreviewModifier {
    let configure: @MainActor (Container) -> Void

    /// Prepares the current container, then shows the preview's content.
    public func body(content: Content, context: Void) -> some View {
        Container.current.prepareForPreview(configure)
        return content
    }
}
#endif

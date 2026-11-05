#if canImport(SwiftUI)
public import SwiftUI

extension Container {
    /// Resets the current container and applies `configure`, as the first line of a `#Preview`.
    ///
    /// On iOS 18, macOS 15, tvOS 18, watchOS 11 and visionOS 2, prefer the ``DeveloperToolsSupport/PreviewTrait/container(_:)`` trait.
    /// In DEBUG, it prints a warning whenever the preview resolves a provider with its default factory.
    @discardableResult
    public static func preview(_ configure: (Container) -> Void) -> EmptyView {
        Container.current.prepareForPreview(configure)
        return EmptyView()
    }

    func prepareForPreview(_ configure: (Container) -> Void) {
        reset()
        configure(self)
        #if DEBUG
        onResolve = { resolution in
            if resolution.source != .registration {
                print("Wiring: this preview resolved \(resolution.name) with its default factory (\(resolution.file)).")
            }
        }
        #endif
    }
}
#endif

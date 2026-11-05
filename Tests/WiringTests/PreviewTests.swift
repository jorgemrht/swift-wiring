#if canImport(SwiftUI)
import SwiftUI
import Testing
import Wiring

@MainActor
struct PreviewTests {
    @Test func aPreviewStartsFromAnEmptyContainerWithItsRegistrations() async {
        await Container.withIsolatedContainer {
            Container.current.greeting.register { "from another preview" }
            let cached = Container.current.cachedService()

            Container.preview { $0.uniqueService.register { Service(name: "preview") } }

            #expect(Container.current.greeting() == "default")
            #expect(Container.current.cachedService() !== cached)
            #expect(Container.current.uniqueService().name == "preview")
        }
    }

    #if DEBUG
    @Test func aPreviewWarnsWhenItReachesADefaultFactory() async {
        await Container.withIsolatedContainer {
            Container.preview { $0.greeting.register { "preview" } }

            #expect(Container.current.onResolve != nil)
        }
    }
    #endif
}

#Preview {
    Container.preview { $0.greeting.register { "Hello" } }
    Text(Container.current.greeting())
}

@available(iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, *)
#Preview(traits: .container { $0.greeting.register { "Hello" } }) {
    Text(Container.current.greeting())
}
#endif

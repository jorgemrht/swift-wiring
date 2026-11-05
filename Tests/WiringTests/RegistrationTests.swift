import Testing
import Wiring

@MainActor
struct RegistrationTests {
    @Test func registerReplacesTheFactoryAndDiscardsTheKeptInstance() {
        let container = Container()
        let original = container.cachedService()

        container.cachedService.register { Service(name: "registered") }

        let registered = container.cachedService()
        #expect(registered !== original)
        #expect(registered.name == "registered")
        #expect(container.cachedService() === registered)
    }

    @Test func theLastRegistrationWins() {
        let container = Container()
        container.greeting.register { "first" }
        container.greeting.register { "second" }

        #expect(container.greeting() == "second")
    }

    @Test func unregisterGoesBackToTheDefaultFactory() {
        let container = Container()
        container.cachedService.register { Service(name: "registered") }
        let registered = container.cachedService()

        container.cachedService.unregister()

        let restored = container.cachedService()
        #expect(restored !== registered)
        #expect(restored.name == "default")
    }

    @Test func resettingAProviderDiscardsItsInstanceAndKeepsItsRegistration() {
        let container = Container()
        container.cachedService.register { Service(name: "registered") }
        let first = container.cachedService()

        container.cachedService.reset()

        let second = container.cachedService()
        #expect(second !== first)
        #expect(second.name == "registered")
    }

    @Test func resettingTheContainerDiscardsEveryRegistrationAndInstance() {
        let container = Container()
        container.greeting.register { "registered" }
        let cached = container.cachedService()
        let session = container.sessionService()

        container.reset()

        #expect(container.greeting() == "default")
        #expect(container.cachedService() !== cached)
        #expect(container.sessionService() !== session)
    }
}

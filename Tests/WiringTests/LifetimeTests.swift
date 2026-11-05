import Testing
import Wiring

@MainActor
struct LifetimeTests {
    @Test func uniqueBuildsANewInstanceOnEveryResolution() {
        let container = Container()
        #expect(container.uniqueService() !== container.uniqueService())
    }

    @Test func cachedKeepsOneInstancePerContainer() {
        let container = Container()
        #expect(container.cachedService() === container.cachedService())
        #expect(container.cachedService() !== Container().cachedService())
    }

    @Test func resettingTheSessionDiscardsSessionInstancesOnly() {
        let container = Container()
        let session = container.sessionService()
        let cached = container.cachedService()

        container.reset(.session)

        #expect(container.sessionService() !== session)
        #expect(container.cachedService() === cached)
    }

    @Test func resettingCachedDiscardsCachedInstancesOnly() {
        let container = Container()
        let session = container.sessionService()
        let cached = container.cachedService()

        container.reset(.cached)

        #expect(container.cachedService() !== cached)
        #expect(container.sessionService() === session)
    }

    @Test func nilIsNeverCached() {
        let container = Container()
        var runs = 0
        container.optionalName.register {
            runs += 1
            return runs == 1 ? nil : "Eva"
        }

        #expect(container.optionalName() == nil)
        #expect(container.optionalName() == "Eva")
        #expect(container.optionalName() == "Eva")
        #expect(runs == 2)
    }

    @Test func anOptionalHoldingNilIsCached() {
        let container = Container()
        var runs = 0
        container.nestedOptionalName.register {
            runs += 1
            return .some(nil)
        }

        _ = container.nestedOptionalName()
        _ = container.nestedOptionalName()

        #expect(runs == 1)
    }
}

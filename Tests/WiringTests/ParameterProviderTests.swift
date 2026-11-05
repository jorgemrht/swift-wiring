import Testing
import Wiring

@MainActor
struct ParameterProviderTests {
    @Test func eachParameterValueKeepsItsOwnCachedInstance() {
        let container = Container()

        let eva = container.cachedProfile("eva")
        let leo = container.cachedProfile("leo")

        #expect(eva.name == "eva")
        #expect(leo.name == "leo")
        #expect(container.cachedProfile("eva") === eva)
        #expect(container.cachedProfile("leo") === leo)
    }

    @Test func uniqueBuildsANewInstanceEveryTime() {
        let container = Container()

        #expect(container.uniqueProfile("eva") !== container.uniqueProfile("eva"))
    }

    @Test func aRegistrationReplacesTheFactoryForEveryValueAndDiscardsTheKeptInstances() {
        let container = Container()
        let original = container.cachedProfile("eva")

        container.cachedProfile.register { name in Service(name: "registered \(name)") }

        let registered = container.cachedProfile("eva")
        #expect(registered !== original)
        #expect(registered.name == "registered eva")
        #expect(container.cachedProfile("leo").name == "registered leo")
        #expect(container.cachedProfile("eva") === registered)
    }

    @Test func unregisterGoesBackToTheDefaultFactory() {
        let container = Container()
        container.cachedProfile.register { _ in Service(name: "registered") }
        _ = container.cachedProfile("eva")

        container.cachedProfile.unregister()

        #expect(container.cachedProfile("eva").name == "eva")
    }

    @Test func resettingDiscardsTheInstancesOfEveryValueAndNothingElse() {
        let container = Container()
        let eva = container.cachedProfile("eva")
        let leo = container.cachedProfile("leo")
        let service = container.cachedService()

        container.cachedProfile.reset()

        #expect(container.cachedProfile("eva") !== eva)
        #expect(container.cachedProfile("leo") !== leo)
        #expect(container.cachedService() === service)
    }

    @Test func resettingALifetimeReachesTheInstancesOfEveryValue() {
        let container = Container()
        let session = container.sessionProfile("eva")
        let cached = container.cachedProfile("eva")

        container.reset(.session)

        #expect(container.sessionProfile("eva") !== session)
        #expect(container.cachedProfile("eva") === cached)
    }

    @Test func aNilIsNotKept() {
        let container = Container()
        var runs = 0
        container.optionalProfile.register { _ in
            runs += 1
            return runs == 1 ? nil : "Eva"
        }

        #expect(container.optionalProfile("eva") == nil)
        #expect(container.optionalProfile("eva") == "Eva")
        #expect(container.optionalProfile("eva") == "Eva")
        #expect(runs == 2)
    }

    @Test func aRegistrationInAnIsolatedContainerStaysThere() async {
        let root = Container.current
        await Container.withIsolatedContainer {
            Container.current.cachedProfile.register { _ in Service(name: "isolated") }
            #expect(Container.current.cachedProfile("eva").name == "isolated")
        }
        #expect(root.cachedProfile("eva").name == "eva")
    }

    @Test func aProviderCanResolveItselfWithAnotherValue() {
        let container = Container()

        #expect(container.category(3) == [0, 1, 2, 3])
    }

    @Test func eachResolutionIsReported() {
        let container = Container()
        var resolutions: [Resolution] = []
        container.onResolve = { resolutions.append($0) }

        _ = container.cachedProfile("eva")
        _ = container.cachedProfile("eva")
        _ = container.cachedProfile("leo")

        #expect(resolutions.map(\.name) == ["cachedProfile", "cachedProfile"])
        #expect(resolutions.allSatisfy { $0.source == .defaultFactory })
    }
}

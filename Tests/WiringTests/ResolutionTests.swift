import Testing
import Wiring

@MainActor
struct ResolutionTests {
    @Test func everyFactoryRunIsReportedWithItsPathAndSource() {
        let container = Container()
        var resolutions: [Resolution] = []
        container.onResolve = { resolutions.append($0) }
        container.uniqueService.register { Service(name: "registered") }

        _ = container.pair()

        #expect(resolutions.map(\.name) == ["pair", "uniqueService"])
        #expect(resolutions.map(\.path) == [["pair"], ["pair", "uniqueService"]])
        #expect(resolutions.map(\.source) == [.defaultFactory, .registration])
        #expect(resolutions.allSatisfy { $0.file == "WiringTests/Container+Fixtures.swift" })
    }

    @Test func keptInstancesAreNotReported() {
        let container = Container()
        var factoryRuns = 0
        container.onResolve = { _ in factoryRuns += 1 }

        _ = container.cachedService()
        _ = container.cachedService()

        #expect(factoryRuns == 1)
    }
}

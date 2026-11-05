import Testing
import Wiring

@MainActor
struct ProviderKeyTests {
    @Test func providersWithTheSameNameAndDifferentTypesKeepSeparateInstances() {
        let container = Container()
        var factoryRuns = 0
        container.onResolve = { _ in factoryRuns += 1 }

        _ = container.box(of: Int.self)()
        _ = container.box(of: String.self)()
        _ = container.box(of: Int.self)()

        #expect(factoryRuns == 2)
    }

    @Test func providersWithTheSameNameInDifferentFilesAreDifferentProviders() {
        let container = Container()
        let payments = container(.cached, name: "client", file: "Payments/Container+Payments.swift") { Service(name: "payments") }
        let profile = container(.cached, name: "client", file: "Profile/Container+Profile.swift") { Service(name: "profile") }

        #expect(payments().name == "payments")
        #expect(profile().name == "profile")
        #expect(payments() !== profile())
    }
}

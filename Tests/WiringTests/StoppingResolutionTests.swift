#if os(macOS)
import Testing
import Wiring

struct StoppingResolutionTests {
    @Test func aCircularDependencyStopsWithItsPath() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run { _ = Container().cycleA() }
        }

        let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(output.contains("Circular dependency: cycleA → cycleB → cycleA"))
    }

    @Test func aParameterProviderAskingForItselfWithTheSameValueStops() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run { _ = Container().cyclicCategory(3) }
        }

        let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(output.contains("Circular dependency: cyclicCategory → cyclicCategory"))
    }

    #if DEBUG
    @Test func aSharedFactoryReturningAValueTypeStops() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run { _ = Container().sharedNumber() }
        }

        let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(output.contains("Container.sharedNumber is .shared, but its factory returned Int, which is not a class. Only classes can be shared (WiringTests/Container+Fixtures.swift)."))
    }
    #endif

    @Test func anUnimplementedProviderStopsWithWhatIsMissing() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            await MainActor.run { _ = Container().missingService() }
        }

        let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(output.contains("Container.missingService has no implementation. Register one at launch (WiringTests/Container+Fixtures.swift)."))
    }

    @Test @MainActor func anUnimplementedProviderWorksOnceRegistered() {
        let container = Container()
        container.missingService.register { Service(name: "registered") }

        #expect(container.missingService().name == "registered")
    }
}
#endif

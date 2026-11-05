#if DEBUG && canImport(ObjectiveC)
import Testing
@testable import Wiring

struct LoadedCopiesTests {
    @Test func aSecondCopyIsDetected() {
        let name = "WiringLoadedCopiesTests"

        #expect(LoadedCopies.register(1, under: name) == nil)
        #expect(LoadedCopies.register(1, under: name) == nil)
        #expect(LoadedCopies.register(2, under: name) == 1)
    }
}
#endif

import Observation
import Testing
import Wiring

final class Clock {}

extension Container {
    var clock: Provider<Clock> {
        self(.cached) { Clock() }
    }
}

@Observable
final class ClockStore {
    @ObservationIgnored @Injected(\.clock) var clock
}

struct DefaultIsolationTests {
    @Test func theAPIWorksWithMainActorAsTheDefaultIsolation() async {
        await Container.withIsolatedContainer {
            let store = ClockStore()
            #expect(store.clock === Container.current.clock())
        }
    }
}

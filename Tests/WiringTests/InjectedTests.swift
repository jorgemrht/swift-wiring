import Observation
import Testing
import Wiring

@MainActor
struct InjectedTests {
    @Test func creatingItResolvesNothing() {
        let container = Container()
        var factoryRuns = 0
        container.onResolve = { _ in factoryRuns += 1 }

        _ = Injected(\.uniqueService, container: container)

        #expect(factoryRuns == 0)
    }

    @Test func itResolvesOnceAndKeepsTheValue() {
        let container = Container()
        var factoryRuns = 0
        container.onResolve = { _ in factoryRuns += 1 }
        let injected = Injected(\.uniqueService, container: container)

        let first = injected.wrappedValue
        let second = injected.wrappedValue

        #expect(first === second)
        #expect(factoryRuns == 1)
    }

    @Test func aNilIsNotKeptSoTheNextReadResolvesAgain() {
        let container = Container()
        var name: String?
        container.optionalName.register { name }
        let injected = Injected(\.optionalName, container: container)

        #expect(injected.wrappedValue == nil)
        name = "Eva"
        #expect(injected.wrappedValue == "Eva")
        name = nil
        #expect(injected.wrappedValue == "Eva")
    }

    @Test func itUsesTheContainerThatWasCurrentWhenItWasCreated() async {
        let injected = await Container.withIsolatedContainer {
            Container.current.uniqueService.register { Service(name: "isolated") }
            return Injected(\.uniqueService)
        }

        #expect(injected.wrappedValue.name == "isolated")
    }

    @Test func anObservableStoreResolvesOnFirstRead() async {
        await Container.withIsolatedContainer {
            Container.current.uniqueService.register { Service(name: "registered") }
            let store = LoginStore()
            Container.current.uniqueService.register { Service(name: "too late") }

            #expect(store.serviceName == "too late")
            #expect(store.serviceName == "too late")
        }
    }

    @Test func aStoreCanReceiveItsContainer() {
        let windowContainer = Container()
        windowContainer.uniqueService.register { Service(name: "window") }

        let store = WindowStore(windowContainer: windowContainer)

        #expect(store.serviceName == "window")
    }
}

@Observable @MainActor
private final class LoginStore {
    @ObservationIgnored @Injected(\.uniqueService) private var service

    var serviceName: String { service.name }
}

@Observable @MainActor
private final class WindowStore {
    @ObservationIgnored @Injected private var service: Service

    init(windowContainer: Container) {
        _service = Injected(\.uniqueService, container: windowContainer)
    }

    var serviceName: String { service.name }
}

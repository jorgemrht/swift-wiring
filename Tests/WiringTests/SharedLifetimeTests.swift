import Testing
import Wiring

@MainActor
struct SharedLifetimeTests {
    @Test func whileSomethingHoldsItEveryResolutionGetsTheSameInstance() {
        let container = Container()
        let first = container.sharedService()

        #expect(container.sharedService() === first)
    }

    @Test func onceNothingHoldsItTheNextResolutionBuildsANewOne() {
        let container = Container()
        var factoryRuns = 0
        container.onResolve = { _ in factoryRuns += 1 }
        weak var released: Service?
        do {
            let first = container.sharedService()
            released = first
            #expect(container.sharedService() === first)
        }

        #expect(released == nil)
        _ = container.sharedService()
        #expect(factoryRuns == 2)
    }

    @Test func theStoresOfAFlowShareItWhileTheyLive() {
        let container = Container()
        weak var releasedCart: any Cart?
        do {
            let cartStore = Injected(\.cart, container: container)
            let paymentStore = Injected(\.cart, container: container)
            cartStore.wrappedValue.items.append("book")

            #expect(paymentStore.wrappedValue.items == ["book"])
            releasedCart = paymentStore.wrappedValue
        }

        #expect(releasedCart == nil)
        #expect(Injected(\.cart, container: container).wrappedValue.items.isEmpty)
    }

    @Test func resettingTheProviderDiscardsItEvenWhileItIsHeld() {
        let container = Container()
        let first = container.sharedService()

        container.sharedService.reset()

        #expect(container.sharedService() !== first)
    }

    @Test func resettingTheSharedLifetimeDiscardsItAndOtherLifetimesDoNot() {
        let container = Container()
        let shared = container.sharedService()

        container.reset(.session)
        #expect(container.sharedService() === shared)

        container.reset(.shared)
        #expect(container.sharedService() !== shared)
    }

    @Test func aRegistrationIsSharedTooAndDiscardsTheInstance() {
        let container = Container()
        let original = container.sharedService()

        container.sharedService.register { Service(name: "registered") }

        let registered = container.sharedService()
        #expect(registered !== original)
        #expect(registered.name == "registered")
        #expect(container.sharedService() === registered)
    }

    @Test func eachParameterValueSharesItsOwnInstance() {
        let container = Container()
        let eva = container.sharedProfile("eva")
        let leo = container.sharedProfile("leo")

        #expect(container.sharedProfile("eva") === eva)
        #expect(container.sharedProfile("leo") === leo)
        #expect(eva !== leo)
    }
}

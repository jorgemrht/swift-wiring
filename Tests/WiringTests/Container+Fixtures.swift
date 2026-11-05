import Wiring

extension Container {
    var uniqueService: Provider<Service> {
        self { Service() }
    }

    var cachedService: Provider<Service> {
        self(.cached) { Service() }
    }

    var sessionService: Provider<Service> {
        self(.session) { Service() }
    }

    var sharedService: Provider<Service> {
        self(.shared) { Service() }
    }

    var cart: Provider<any Cart> {
        self(.shared) { ShoppingCart() }
    }

    var sharedProfile: ParameterProvider<String, Service> {
        self(.shared) { name in Service(name: name) }
    }

    var sharedNumber: Provider<Int> {
        self(.shared) { 7 }
    }

    var greeting: Provider<String> {
        self { "default" }
    }

    var optionalName: Provider<String?> {
        self(.cached) { nil }
    }

    var nestedOptionalName: Provider<String??> {
        self(.cached) { nil }
    }

    var uniqueProfile: ParameterProvider<String, Service> {
        self { name in Service(name: name) }
    }

    var cachedProfile: ParameterProvider<String, Service> {
        self(.cached) { name in Service(name: name) }
    }

    var sessionProfile: ParameterProvider<String, Service> {
        self(.session) { name in Service(name: name) }
    }

    var optionalProfile: ParameterProvider<String, String?> {
        self(.cached) { _ in nil }
    }

    var category: ParameterProvider<Int, [Int]> {
        self { depth in depth == 0 ? [0] : self.category(depth - 1) + [depth] }
    }

    var cyclicCategory: ParameterProvider<Int, [Int]> {
        self { depth in self.cyclicCategory(depth) }
    }

    var pair: Provider<Pair> {
        self { Pair(child: self.uniqueService()) }
    }

    var missingService: Provider<Service> {
        unimplemented()
    }

    var cycleA: Provider<Service> {
        self {
            _ = self.cycleB()
            return Service()
        }
    }

    var cycleB: Provider<Service> {
        self {
            _ = self.cycleA()
            return Service()
        }
    }

    func box<Content>(of content: Content.Type) -> Provider<Box<Content>> {
        self(.cached) { Box<Content>() }
    }
}

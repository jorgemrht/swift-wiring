protocol Cart: AnyObject {
    var items: [String] { get set }
}

final class ShoppingCart: Cart {
    var items: [String] = []
}

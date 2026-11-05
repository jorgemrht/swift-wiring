final class WeakReference {
    weak let object: AnyObject?

    init(_ object: AnyObject) {
        self.object = object
    }
}

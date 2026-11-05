struct CachedInstance {
    let lifetime: Lifetime
    let stored: Any

    init(lifetime: Lifetime, value: Any) {
        self.lifetime = lifetime
        stored = lifetime == .shared ? WeakReference(value as AnyObject) : value
    }

    var value: Any {
        lifetime == .shared ? (stored as? WeakReference)?.object as Any : stored
    }
}

protocol OptionalValue {
    var isNone: Bool { get }
}

extension Optional: OptionalValue {
    var isNone: Bool {
        self == nil
    }
}

func isNone<Value>(_ value: Value) -> Bool {
    (value as? any OptionalValue)?.isNone ?? false
}

struct ProviderKey: Hashable {
    let type: ObjectIdentifier
    let name: StaticString
    let file: StaticString

    init<Value>(_: Value.Type, name: StaticString, file: StaticString) {
        type = ObjectIdentifier(Value.self)
        self.name = name
        self.file = file
    }

    static func == (lhs: ProviderKey, rhs: ProviderKey) -> Bool {
        lhs.type == rhs.type && equal(lhs.name, rhs.name) && equal(lhs.file, rhs.file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        name.withUTF8Buffer { unsafe hasher.combine(bytes: UnsafeRawBufferPointer($0)) }
    }

    private static func equal(_ lhs: StaticString, _ rhs: StaticString) -> Bool {
        lhs.withUTF8Buffer { lhsBytes in
            rhs.withUTF8Buffer { rhsBytes in
                unsafe lhsBytes.count == rhsBytes.count && (lhsBytes.baseAddress == rhsBytes.baseAddress || lhsBytes.elementsEqual(rhsBytes))
            }
        }
    }
}

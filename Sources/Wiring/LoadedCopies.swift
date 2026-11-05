#if DEBUG && canImport(ObjectiveC)
import Foundation
import ObjectiveC

enum LoadedCopies {
    static func check() {
        if register(UInt(bitPattern: ObjectIdentifier(Container.self)), under: "WiringLoadedCopy") != nil {
            print("Wiring: two copies of Wiring are loaded in this process; registrations made in one are invisible to the other. Link Wiring into a single target.")
        }
    }

    static func register(_ copy: UInt, under name: String) -> UInt? {
        let key = unsafe unsafeBitCast(sel_registerName(name), to: UnsafeRawPointer.self)
        let process = ProcessInfo.processInfo
        if let existing = unsafe objc_getAssociatedObject(process, key) as? NSNumber, existing.uintValue != copy {
            return existing.uintValue
        }
        unsafe objc_setAssociatedObject(process, key, NSNumber(value: copy), .OBJC_ASSOCIATION_RETAIN)
        return nil
    }
}
#endif

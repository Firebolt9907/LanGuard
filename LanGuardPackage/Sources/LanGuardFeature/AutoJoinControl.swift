import Foundation
import ObjectiveC
import Darwin

/// Uses CoreWiFi's current control; the older CoreWLAN pause API is rejected on
/// recent macOS. Only restore a pause introduced by LanGuard. Journal ownership
/// before changing macOS so a subsequent launch can recover after a crash.
final class AutoJoinControl {
    struct Dependencies {
        var isDisabled: () -> Bool
        var setDisabled: (Bool) throws -> Void
        var loadOwned: () -> Bool
        var saveOwned: (Bool) -> Void
    }
    private let deps: Dependencies
    private let cleanup: () -> Void
    init(dependencies: Dependencies, cleanup: @escaping () -> Void = {}) {
        deps = dependencies
        self.cleanup = cleanup
    }
    deinit { cleanup() }

    @discardableResult
    func renew() throws -> Bool {
        guard !deps.isDisabled() else { return false }
        let alreadyOwned = deps.loadOwned()
        deps.saveOwned(true)
        do {
            try deps.setDisabled(true)
            guard deps.isDisabled() else { throw ControlError.failed }
            return true
        } catch {
            if !alreadyOwned && !deps.isDisabled() { deps.saveOwned(false) }
            throw error
        }
    }

    func release() throws {
        guard deps.loadOwned() else { return }
        if deps.isDisabled() {
            try deps.setDisabled(false)
            guard !deps.isDisabled() else { throw ControlError.failed }
        }
        deps.saveOwned(false)
    }

    private static let framework = dlopen("/System/Library/PrivateFrameworks/CoreWiFi.framework/CoreWiFi", RTLD_NOW)

    static func system(interfaces: [String]? = nil, client supplied: NSObject? = nil,
                       defaults: UserDefaults = .standard) throws -> AutoJoinControl {
        let client: NSObject
        if let supplied { client = supplied }
        else {
            guard framework != nil, let cls = NSClassFromString("CWFInterface") as? NSObject.Type else {
                throw ControlError.unsupported
            }
            client = cls.init()
        }
        func method(_ name: String, result: String, arguments: [String]) throws -> Method {
            let selector = NSSelectorFromString(name)
            guard client.responds(to: selector),
                  let method = class_getInstanceMethod(Swift.type(of: client), selector),
                  method_getNumberOfArguments(method) == arguments.count + 2 else { throw ControlError.unsupported }
            func encoding(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
                guard let pointer else { return "" }
                defer { free(pointer) }
                return String(cString: pointer)
            }
            func matches(_ actual: String, _ expected: String) -> Bool {
                actual == expected || (expected == "B" && actual == "c")
            }
            guard matches(encoding(method_copyReturnType(method)), result) else { throw ControlError.unsupported }
            for (index, expected) in arguments.enumerated() {
                guard matches(encoding(method_copyArgumentType(method, UInt32(index + 2))), expected) else {
                    throw ControlError.unsupported
                }
            }
            return method
        }
        typealias ReadBool = @convention(c) (AnyObject, Selector) -> ObjCBool
        typealias ReadObject = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        // NSError ** must be autoreleasing, not a pointer to Swift strong storage.
        typealias SetBool = @convention(c) (AnyObject, Selector, ObjCBool, AutoreleasingUnsafeMutablePointer<NSError?>) -> ObjCBool
        typealias Action = @convention(c) (AnyObject, Selector) -> Void
        let read = try method("userAutoJoinDisabled", result: "B", arguments: [])
        let write = try method("setUserAutoJoinDisabled:error:", result: "B", arguments: ["B", "^@"])
        let nameMethod = try method("interfaceName", result: "@", arguments: [])
        let activate = try method("activate", result: "v", arguments: [])
        let invalidate = try method("invalidate", result: "v", arguments: [])
        let cleanup = {
            unsafeBitCast(method_getImplementation(invalidate), to: Action.self)(client, method_getName(invalidate))
        }
        unsafeBitCast(method_getImplementation(activate), to: Action.self)(client, method_getName(activate))
        guard let name = unsafeBitCast(method_getImplementation(nameMethod), to: ReadObject.self)(client, method_getName(nameMethod))?.takeUnretainedValue() as? String,
              interfaces == nil || interfaces == [name] else {
            cleanup()
            throw ControlError.interfaceUnsupported
        }
        let key = "disconnectModeOwnsAutoJoinPause.\(name)"
        return AutoJoinControl(dependencies: .init(
            isDisabled: { unsafeBitCast(method_getImplementation(read), to: ReadBool.self)(client, method_getName(read)).boolValue },
            setDisabled: { disabled in
                var error: NSError?
                guard unsafeBitCast(method_getImplementation(write), to: SetBool.self)(client, method_getName(write), ObjCBool(disabled), &error).boolValue else {
                    throw error ?? ControlError.failed as NSError
                }
            },
            loadOwned: { defaults.bool(forKey: key) },
            saveOwned: { defaults.set($0, forKey: key); defaults.synchronize() }
        ), cleanup: cleanup)
    }

    enum ControlError: LocalizedError {
        case unsupported, interfaceUnsupported, failed
        var errorDescription: String? {
            switch self {
            case .unsupported: return "This macOS version does not support Wi-Fi auto-join control."
            case .interfaceUnsupported: return "AirDrop mode currently supports only the primary Wi-Fi adapter. Select only that adapter in Controlled Wi-Fi."
            case .failed: return "macOS could not change Wi-Fi auto-join."
            }
        }
    }
}

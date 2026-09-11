import Foundation
import Combine

/// Owns the primary Wi-Fi adapter's auto-join pause for the opt-in mode.
final class DisconnectMode: ObservableObject {
    @Published private(set) var errorMessage: String?
    private(set) var pause: AutoJoinControl?
    private var interfaces: [String] = []
    private let makeControl: ([String]) throws -> AutoJoinControl

    var isActive: Bool { pause != nil }

    init(makeControl: @escaping ([String]) throws -> AutoJoinControl = { try AutoJoinControl.system(interfaces: $0) }) {
        self.makeControl = makeControl
    }

    @discardableResult
    func begin(interfaces: [String]) throws -> Bool {
        guard !interfaces.isEmpty else { stop(); return false }
        let wasActive = isActive
        self.interfaces = interfaces
        do {
            if pause == nil { pause = try makeControl(interfaces) }
            try WiFiController.disconnect(interfaces: interfaces) { [weak self] in
                _ = try self?.pause?.renew()
            }
            errorMessage = nil
            return !wasActive
        } catch {
            stop()
            report(error)
            throw error
        }
    }

    func stop() {
        interfaces = []
        defer { pause = nil }
        do {
            try pause?.release()
            errorMessage = nil
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        let native = error as NSError
        if native.domain == "com.apple.wifi.request.error" {
            errorMessage = "macOS rejected automatic Wi-Fi disconnection mode (error \(native.code)). The auto-join pause could not be applied."
        } else {
            errorMessage = error.localizedDescription
        }
        Log.write("Disconnect mode: \(native.domain) \(native.code): \(error.localizedDescription)")
    }

    func recover() {
        guard UserDefaults.standard.dictionaryRepresentation().contains(where: {
            $0.key.hasPrefix("disconnectModeOwnsAutoJoinPause.") && ($0.value as? Bool == true)
        }) else { return }
        do { try AutoJoinControl.system().release() }
        catch { report(error) }
    }
}

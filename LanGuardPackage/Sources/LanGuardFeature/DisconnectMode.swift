import Foundation
import Combine

/// Owns the primary Wi-Fi adapter's auto-join pause for the opt-in mode.
final class DisconnectMode: ObservableObject {
    @Published private(set) var errorMessage: String?
    private var pause: AutoJoinControl?
    private var timer: Timer?
    private var interfaces: [String] = []

    func begin(interfaces: [String]) {
        guard !interfaces.isEmpty else { stop(); return }
        self.interfaces = interfaces
        do {
            if pause == nil { pause = try AutoJoinControl.system(interfaces: interfaces) }
            try WiFiController.disconnect(interfaces: interfaces) { _ = try pause?.renew() }
            errorMessage = nil
            if timer == nil {
                let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.renew() }
                RunLoop.main.add(timer, forMode: .common)
                self.timer = timer
            }
        } catch {
            stop()
            report(error)
        }
    }

    private func renew() {
        do {
            if try pause?.renew() == true {
                // Reapply after macOS resets the pause, for example at wake.
                // Normal checks leave manual connections alone.
                try WiFiController.disconnect(interfaces: interfaces) { _ = try pause?.renew() }
            }
            errorMessage = nil
        }
        catch { report(error) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        interfaces = []
        do {
            try pause?.release()
            pause = nil
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

import Foundation
import Combine
import AppKit

/// Top-level app state: wires Settings + NetworkMonitor + WiFiController into the
/// ToggleEngine, owns lifecycle, and exposes view-facing helpers.
public final class AppModel: ObservableObject {

    public static let shared = AppModel()

    public let settings: AppSettings
    public let monitor: NetworkMonitor
    public let engine: ToggleEngine

    private let disconnectMode: DisconnectMode

    private var bag = Set<AnyCancellable>()

    public init() {
        let settings = AppSettings()
        let monitor = NetworkMonitor()
        self.settings = settings
        self.monitor = monitor
        let disconnectMode = DisconnectMode()
        self.disconnectMode = disconnectMode

        let deps = ToggleEngine.Dependencies(
            activeWiredNames: { [monitor] in
                InterfaceCatalog.wired()
                    .filter { settings.wiredEnabled($0) }
                    .map(\.bsdName)
                    .filter { monitor.linkActive($0) }
            },
            wifiTargets: {
                InterfaceCatalog.wifi()
                    .map(\.bsdName)
                    .filter { settings.wifiEnabled($0) }
            },
            setWiFiPower: { on, names in
                if !on && settings.keepWiFiOn {
                    do {
                        let changed = try disconnectMode.begin(interfaces: names)
                        Log.write("disconnectMode.begin succeeded for \(names)")
                        guard settings.notificationsEnabled && changed else { return }
                        let trigger = InterfaceCatalog.wired()
                            .first { settings.wiredEnabled($0) && monitor.linkActive($0.bsdName) }
                        let label = trigger?.displayName ?? "Wired LAN"
                        Notifier.post(title: "Wi-Fi disconnected",
                                      body: "\(label) connected — Wi-Fi disconnected (AirDrop on).")
                        return
                    } catch {
                        Log.write("disconnectMode.begin failed: \(error.localizedDescription) — falling back to power off")
                        // Fall through to power off fallback below
                    }
                }
                let wasDisconnectActive = disconnectMode.isActive
                disconnectMode.stop()
                // Only touch interfaces whose power actually differs, and only
                // notify if something really changed — no redundant banners.
                let toChange = names.filter { WiFiController.isPoweredOn($0) != on }
                Log.write("setWiFiPower(on: \(on)) targets=\(names) changing=\(toChange)")
                if !toChange.isEmpty {
                    WiFiController.setPower(on, interfaces: toChange)
                }
                guard settings.notificationsEnabled else { return }
                if on {
                    if !toChange.isEmpty {
                        Notifier.post(title: "Wi-Fi on",
                                      body: "Wired LAN disconnected — Wi-Fi turned back on.")
                    } else if wasDisconnectActive {
                        Notifier.post(title: "Wi-Fi on",
                                      body: "Wired LAN disconnected — Wi-Fi auto-join restored.")
                    }
                } else if !toChange.isEmpty {
                    let trigger = InterfaceCatalog.wired()
                        .first { settings.wiredEnabled($0) && monitor.linkActive($0.bsdName) }
                    let label = trigger?.displayName ?? "Wired LAN"
                    Notifier.post(title: "Wi-Fi off",
                                  body: "\(label) connected — Wi-Fi turned off.")
                }
            },
            anyWiFiOn: {
                InterfaceCatalog.wifi()
                    .map(\.bsdName)
                    .filter { settings.wifiEnabled($0) }
                    .contains { WiFiController.isPoweredOn($0) }
            },
            autoEnabled: { settings.autoEnabled },
            saveLastWired: { value in
                UserDefaults.standard.set(value.map { $0 ? 1 : 0 } ?? -1, forKey: "lastWired")
            },
            loadLastWired: {
                guard let raw = UserDefaults.standard.object(forKey: "lastWired") as? Int, raw >= 0
                else { return nil }
                return raw == 1
            }
        )
        self.engine = ToggleEngine(dependencies: deps)

        // Re-publish child changes so views observing AppModel refresh.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        disconnectMode.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    /// Called once at launch.
    public func start() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        Log.write("=== LanGuard \(version) start (debug logging on) ===")
        LegacyCleanup.run()
        Notifier.requestAuthorization()

        // Auto-register the login item for the current bundle path every launch.
        // Self-heals after a move; prompts the user if macOS needs approval.
        switch LoginItem.ensureRegistered() {
        case .reRegisterMoved:
            LoginItem.notifyReRegisteredAfterMove()
        case .register, .none:
            LoginItem.promptForApprovalIfNeeded()
        }

        disconnectMode.recover()
        monitor.onWake = { [weak self] in
            guard let self, self.settings.keepWiFiOn else { return }
            Log.write("onWake: re-enforcing disconnect mode after wake settle")
            self.disconnectMode.stop()
            self.engine.reapply()
        }
        monitor.onChange = { [weak self] in self?.engine.evaluate() }
        monitor.start()
        if settings.keepWiFiOn { engine.reapply() } else { engine.evaluate() }
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.disconnectMode.stop() }
            .store(in: &bag)
    }

    // MARK: - View-facing helpers

    public func setAuto(_ on: Bool) {
        settings.autoEnabled = on
        if !on { disconnectMode.stop() }
        if on { engine.reapply() } else { engine.evaluate() }
    }

    /// Call after the user changes which interfaces are selected.
    public func selectionChanged() {
        disconnectMode.stop()
        engine.reapply()
    }

    public func setKeepWiFiOn(_ on: Bool) {
        disconnectMode.stop()
        settings.keepWiFiOn = on
        engine.reapply()
    }

    public var disconnectModeError: String? { disconnectMode.errorMessage }

    public func linkActive(_ bsd: String) -> Bool { monitor.linkActive(bsd) }
    public func wifiPoweredOn(_ bsd: String) -> Bool { WiFiController.isPoweredOn(bsd) }

    /// Current state shown in the menu bar (LAN / Wi-Fi / paused).
    public var menuState: MenuState {
        MenuState.from(autoEnabled: settings.autoEnabled, wiredUp: engine.wiredUp)
    }

    public var statusLine: String {
        let wired = engine.wiredUp ? engine.activeWired.joined(separator: ", ") : "none"
        let targets = InterfaceCatalog.wifi().filter { settings.wifiEnabled($0.bsdName) }
        let on = targets.contains { wifiPoweredOn($0.bsdName) }
        let connected = targets.contains { monitor.linkActive($0.bsdName) }
        let wifi = !on ? "off" : connected ? "connected" : "not connected"
        return "Wired: \(wired)  ·  Wi-Fi: \(wifi)"
    }
}

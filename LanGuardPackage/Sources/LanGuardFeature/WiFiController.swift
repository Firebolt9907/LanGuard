import Foundation
import CoreWLAN

/// Reads and sets Wi-Fi interface power via CoreWLAN (no sudo, no shell).
public enum WiFiController {

    /// Keep the radio available to peer-to-peer services such as AirDrop.
    public static func disconnect(interfaces: [String], beforeDisconnect: () throws -> Void) throws {
        let targets = interfaces.compactMap { CWWiFiClient.shared().interface(withName: $0) }
        for iface in targets where !iface.powerOn() { try iface.setPower(true) }
        // Powering on may reset a temporary auto-join pause. Apply it after
        // enabling the radios, immediately before disassociation.
        try beforeDisconnect()
        for iface in targets {
            iface.disassociate()
        }
    }

    /// Set power on/off for the given Wi-Fi BSD names (e.g. ["en0"]).
    public static func setPower(_ on: Bool, interfaces: [String]) {
        let client = CWWiFiClient.shared()
        for name in interfaces {
            guard let iface = client.interface(withName: name) else { continue }
            do {
                try iface.setPower(on)
            } catch {
                NSLog("LanGuard: setPower(\(on)) failed for \(name): \(error)")
            }
        }
    }

    /// True if the named Wi-Fi interface is currently powered on.
    public static func isPoweredOn(_ name: String) -> Bool {
        CWWiFiClient.shared().interface(withName: name)?.powerOn() ?? false
    }
}

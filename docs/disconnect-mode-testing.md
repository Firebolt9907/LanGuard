# Disconnect mode hardware checks

On macOS 26.6.2, the current CoreWiFi `setUserAutoJoinDisabled:error:` call
succeeded outside the sandbox without administrator privileges. With auto-join
disabled, CoreWLAN disassociation left the radio powered and unassociated
(interface mode 0). Restoring auto-join also succeeded. The older CoreWLAN
temporary-pause API was rejected with error 4 and has been removed.

Unit tests cover ownership, crash recovery, Objective-C errors, and setting persistence.
The private macOS API and AirDrop require these additional checks on a real Mac;
they are not validated by the unit tests. Run on both supported Intel and Apple
silicon macOS versions before release.

1. With Ethernet connected and Wi-Fi powered off by LanGuard, enable Settings →
   Keep Wi-Fi on for AirDrop and AirPlay. Confirm Wi-Fi powers on, leaves the access point,
   and the menu reports “not connected.” Keep Bluetooth enabled and transfer a
   file using AirDrop in both directions.
2. Wait at least two minutes with known networks in range. Confirm Wi-Fi stays
   unassociated and Ethernet carries traffic. Verify saved networks and their
   individual Auto-Join preferences are unchanged.
3. Unplug Ethernet. Confirm the pause clears and macOS can auto-join a known
   network. Reconnect Ethernet and verify disconnection without powering off.
4. While wired, separately test pausing automation, disabling the AirDrop option,
   deselecting all Wi-Fi adapters, and quitting normally. Confirm no LanGuard
   auto-join pause remains. Disabling the AirDrop option restores power-off mode.
5. Force quit while the pause is active. Relaunch to recover the saved auto-join
   state. While still wired, verify the mode reapplies; while undocked, verify
   auto-join is restored. This API has no automatic expiry after a force quit.
6. Sleep while docked, then wake docked and undocked. After the settling window,
   confirm the correct state and successful auto-join when undocked.
7. Manually connect while wired. Confirm LanGuard allows the manual connection
   until the next wired transition, explicit reapply, or wake.
8. Select a secondary Wi-Fi adapter. Verify the app reports that only the primary
   Wi-Fi adapter is currently supported and leaves secondary adapters untouched.
9. Check errors on systems that reject the temporary pause API. Confirm an error
   is visible and LanGuard does not report a successful disconnection or power
   Wi-Fi off as a fallback.

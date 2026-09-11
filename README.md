<div align="center">

<img src="docs/social-preview.png" alt="LanGuard — Wi-Fi off when you're wired, back on when you're not. A free, open-source macOS menu-bar app." width="760">

# LanGuard - AirDrop & AirPlay fork

### Prefer Ethernet. Keep Wi-Fi available for AirDrop and AirPlay.

A free, open-source macOS menu-bar app based on
[the original LanGuard by Roy Padina](https://github.com/roypadina/LanGuard/).

This fork adds an optional mode that disconnects Wi-Fi from its network while
keeping the radio on, so it remains available for AirDrop and AirPlay.
Enable **Settings → Keep Wi-Fi on for AirDrop and AirPlay** to use it.
The original Wi-Fi power-off behavior remains the default.

[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Homebrew](https://img.shields.io/badge/brew-roypadina%2Ftap-FBB040?logo=homebrew&logoColor=white)](https://github.com/roypadina/homebrew-tap)
[![Release](https://img.shields.io/github/v/release/roypadina/LanGuard?logo=github&label=release)](https://github.com/roypadina/LanGuard/releases/latest)
[![CI](https://github.com/roypadina/LanGuard/actions/workflows/ci.yml/badge.svg)](https://github.com/roypadina/LanGuard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?logo=opensourceinitiative&logoColor=white)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?logo=github)](CONTRIBUTING.md)
[![Stars](https://img.shields.io/github/stars/roypadina/LanGuard?style=social)](https://github.com/roypadina/LanGuard/stargazers)

<br>

<img src="docs/demo.gif" alt="LanGuard in action: when the wired LAN link goes active the menu-bar indicator flips to LAN and Wi-Fi powers off; when it goes inactive the indicator returns to Wi-Fi and Wi-Fi comes back on." width="720">

<sub><i>Wired link goes up → indicator flips to <b>LAN</b> and Wi-Fi powers off · link goes down → back to <b>Wi-Fi</b>.</i></sub>

</div>

---

## Table of Contents

- [Why this fork?](#why-this-fork)
- [Why](#why)
- [Features](#features)
- [How LanGuard compares](#how-languard-compares)
- [Install](#install)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Is it safe?](#is-it-safe)
- [FAQ](#faq)
- [Uninstall](#uninstall)
- [Reporting a bug](#reporting-a-bug)
- [Contributing](#contributing)
- [Support](#support)
- [License](#license)

## Why this fork?

The original LanGuard turns Wi-Fi off when Ethernet connects and back on when it
disconnects. This fork adds an alternative for people who want to use Ethernet
while keeping the Wi-Fi radio available for AirDrop and AirPlay:

- **Ethernet connects:** Wi-Fi disconnects from its network and automatic joining
  is paused, but the radio stays on.
- **Ethernet disconnects:** LanGuard releases its auto-join pause, allowing Wi-Fi
  to reconnect automatically.
- **Saved networks stay intact:** passwords and per-network Auto-Join preferences
  are unchanged. Existing macOS auto-join pauses are preserved.

The option is **off by default** and currently supports only the **primary Wi-Fi
adapter**. Keep Bluetooth enabled for AirDrop too. Manual Wi-Fi connections remain
possible between wired transitions, and the mode is reapplied after wake.

> [!WARNING]
> This mode relies on an **undocumented, private macOS CoreWiFi API**, so it may
> stop working after a macOS update. If the API is unavailable or an operation
> fails, LanGuard falls back to powering Wi-Fi off and reports an error.
>
> **Before uninstalling, disconnect Ethernet while LanGuard is still running**
> and check that Wi-Fi reconnects. Then quit the app normally before removing it
> or deleting its settings. After a crash or force quit, reopen LanGuard with
> Ethernet disconnected so it can restore auto-join. This pause is separate from
> the per-network Auto-Join setting.

LanGuard also releases its pause when automation is paused, this option or the
adapter selection changes, or the app quits normally. Power-on/disconnected state, auto-join restoration, and AirDrop/AirPlay were tested on macOS 26.6.2.

# Original README.md:

## Why

macOS keeps Wi-Fi on even when you're docked over Ethernet — wasting an IP lease, adding a
second default route, sometimes sending traffic out the wrong interface, and leaving an extra
radio exposed. LanGuard switches Wi-Fi **off** the instant a wired link is active and switches
it back **on** when the cable's gone. It only acts on plug/unplug **transitions**, so if you
manually flip Wi-Fi back on while docked, it stays on until you next unplug.

## Features

| | |
|---|---|
| 🔌 **Edge-based** | Acts only on wired plug/unplug transitions — your manual Wi-Fi changes are respected. |
| 😴 **Wake-aware** | A transition that happened while asleep is detected and corrected on wake. |
| 🎛️ **Per-interface** | Pick which wired adapters trigger and which Wi-Fi adapters are controlled. |
| 🧪 **Ignores virtual NICs** | Bridge / VPN / VM adapters (e.g. VMware `vmnet`) are off by default so they can't pin Wi-Fi off. |
| 🔔 **Notifications** | Optional banner whenever Wi-Fi is toggled. |
| 🧭 **Configurable indicator** | Menu-bar shows `LAN` / `Wi-Fi` / `Off` — icon only, icon + label, or label only. |
| ⏸️ **Master switch** | Pause all automatic toggling from the menu. |
| 🚀 **Start at login** | Self-healing login item — re-registers if the app moves; prompts if macOS needs approval. |
| 🔐 **No admin, no sudo** | Wi-Fi power via CoreWLAN, link state via SystemConfiguration. No network calls of its own. |

> **Menu-bar indicator** (icon + label style):
>
> ![LanGuard menu-bar indicator showing "LAN" while a wired link is active](docs/screenshots/menubar.png)
>
> _An open-menu screenshot is still welcome — see [#1](https://github.com/roypadina/LanGuard/issues/1)._

## How LanGuard compares

|  | **LanGuard** | BridgeChecker | ToggleWifi |
|---|:---:|:---:|:---:|
| Price | **Free** | Paid (~$50) | Free |
| Open source | ✅ (MIT) | ❌ | ✅ |
| Per-interface selection | ✅ | ✅ | ❌ |
| Edge-based (respects manual toggle) | ✅ | — | — |
| Wake-from-sleep handling | ✅ | — | not documented |
| No admin / sudo | ✅ | — | ❌ (needs admin) |

<sub>Comparison based on each project's public docs at time of writing; verify current details on their sites. LanGuard is **not** notarized (ad-hoc signed) — see [Is it safe?](#is-it-safe).</sub>

## Install

> **Requires macOS 14+ (Sonoma).**

### Homebrew

This installs the **original project**, not this fork. To use this fork’s
AirDrop and AirPlay mode, build from source below.

```bash
brew install --cask roypadina/tap/languard
```

> LanGuard is ad-hoc signed (not notarized). On first launch, **right-click it in
> `/Applications` → Open** (then Open again), or run once:
> ```bash
> xattr -dr com.apple.quarantine "/Applications/LanGuard.app"
> ```
> See [Is it safe?](#is-it-safe) for why.

### Build from source

```bash
git clone https://github.com/Firebolt9907/LanGuard.git
cd LanGuard
xcodebuild -workspace LanGuard.xcworkspace -scheme LanGuard -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/LanGuard-*/Build/Products/Release/LanGuard.app /Applications/
open /Applications/LanGuard.app
```

The app lives in the menu bar (no Dock icon). On first launch, click **Allow** on the
notification prompt if you want toggle banners.

## Usage

Click the menu-bar icon for status, the **Auto-toggle** master switch, and **Settings…**.

In **Settings** you can:
- choose which **wired adapters** count as triggers (real adapters on by default, virtual off),
- choose which **Wi-Fi adapters** are controlled,
- enable **Keep Wi-Fi on for AirDrop and AirPlay** (see [Why this fork?](#why-this-fork)),
- toggle **notifications**,
- pick the **menu-bar icon style** (icon / icon + label / label),
- enable **Start at login**.

<div align="center">

<img src="docs/screenshots/settings.png" alt="LanGuard Settings: Auto-toggle, Start at login, notifications, menu-bar icon style, per-interface Wired triggers (with the active link dotted green) and Controlled Wi-Fi adapters." width="380">

</div>

## How it works

```
wired link UP   ─▶  Wi-Fi OFF
wired link DOWN ─▶  Wi-Fi ON
(no edge)       ─▶  leave Wi-Fi alone   ← respects manual override
```

| Component | Role |
|---|---|
| `NetworkMonitor` | `SCDynamicStore` link/IP callbacks + `NSWorkspace` wake notification |
| `WiFiController` | CoreWLAN power on/off (no sudo) |
| `ToggleEngine`   | Edge state machine — dependency-injected, fully unit-tested |
| `InterfaceCatalog` | Enumerate + classify Ethernet/Wi-Fi; flag virtual adapters |
| `LoginItem` | `SMAppService` login item (self-healing) |
| `Notifier` | `UNUserNotificationCenter` banners |

See the [Wiki](https://github.com/roypadina/LanGuard/wiki) for deeper docs,
[`CHANGELOG.md`](CHANGELOG.md) for release history, and [`CLAUDE.md`](CLAUDE.md) for the
full component map.

## Is it safe?

Fair question — it toggles your network and launches at login. Here's the honest picture:

- **Open source (MIT).** Every line is in this repo; read or build it yourself.
- **No network calls of its own. No ads, no analytics, no tracking.** It uses local macOS
  networking APIs (CoreWLAN, SystemConfiguration). The only external tools it ever runs are
  read-only `ifconfig` (a link-state fallback) and a one-time `launchctl` to remove the legacy
  LaunchAgent — never `networksetup`, never with elevated privileges.
- **No admin / sudo.** It never asks for your password or installs a privileged helper.
- **Ad-hoc signed, _not_ notarized.** That's the one rough edge: macOS can't verify the
  developer, so the first launch is blocked until you **right-click → Open** (or clear
  quarantine with the `xattr` command above). Notarization needs a paid Apple Developer ID;
  it's on the roadmap. If you'd rather not trust a prebuilt binary, **build from source**.
- Each release ships a **SHA-256** for the download so you can verify it.

## FAQ

**Wi-Fi turned back on by itself while I was docked — bug?**
No. LanGuard is *edge-based*: it acts only at the moment you plug/unplug. If you (or another
app) turn Wi-Fi on while wired, LanGuard respects that until your next unplug/replug.

**I'm docked but Wi-Fi stayed on.**
Either you turned it on manually since plugging in (see above), or that wired adapter isn't
selected as a trigger in Settings (virtual adapters are off by default).

**Does it work with USB-C / Thunderbolt docks and USB-Ethernet adapters?**
Yes — any adapter macOS reports as an Ethernet interface. You choose which ones count.

**Why is my VPN / VM adapter ignored?**
Virtual adapters (VPN tunnels, VMware/Parallels `vmnet`, bridges) are off by default so they
can't be mistaken for a real wired link. You can opt any of them in under Settings.

**Does it need admin rights?**
No. Wi-Fi power goes through CoreWLAN and link state through SystemConfiguration, both as your
normal user.

**macOS says it "can't verify the developer."**
It's not notarized yet — right-click the app → Open, or run the `xattr` command in
[Install](#install). See [Is it safe?](#is-it-safe).

## Uninstall

If you used **Keep Wi-Fi on for AirDrop and AirPlay**:

1. Disconnect Ethernet while LanGuard is running. If the app crashed or was force
   quit, reopen it with Ethernet disconnected.
2. Check that Wi-Fi reconnects and resolve any auto-join error shown in Settings
   before continuing.
3. Quit LanGuard normally, then remove the app and optionally delete its settings.


```bash
brew uninstall --cask languard          # if installed via Homebrew
# or just drag /Applications/LanGuard.app to the Trash

defaults delete com.roy.languard        # forget all settings (optional)
```
Also remove it under **System Settings → General → Login Items** if it's still listed.

## Reporting a bug

Hit something odd (Wi-Fi toggling when it shouldn't, etc.)? Turn on **Settings → Debug →
Enable debug logging**, reproduce it, then click **Reveal Logs in Finder** and attach
`~/Library/Logs/LanGuard/languard.log` to your [issue](https://github.com/roypadina/LanGuard/issues).
The log stays on your Mac and contains only interface names + toggle decisions (no personal data).

## Contributing

PRs welcome! `main` is protected — fork, branch, add tests, and open a PR. Good first issues are
[labeled here](https://github.com/roypadina/LanGuard/labels/good%20first%20issue). See
[CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

```bash
cd LanGuardPackage && swift test   # pure logic, no hardware needed
```

## Support

If LanGuard saves you some battery and annoyance, you can
[**buy me a coffee on Ko-fi ☕**](https://ko-fi.com/roypadina) — totally optional, always appreciated.
A **⭐ star** helps just as much.

## License

[MIT](LICENSE) © Roy Padina

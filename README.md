# AirDash

<img src="assets/icon.png" width="120" alt="AirDash icon" />

[![Build](https://github.com/zlimteck/AirDash/actions/workflows/build.yml/badge.svg)](https://github.com/zlimteck/AirDash/actions/workflows/build.yml)

Unofficial native iOS dashboard for [AirVPN](https://airvpn.org), built with SwiftUI and the iOS 26 Liquid Glass design.

> ⭐ If you find this project useful, a star on GitHub is greatly appreciated!

> **Disclaimer** — This is an independent project with no affiliation to AirVPN. It uses the public AirVPN API with your personal API key.

---

## Screenshots

<p float="left">
  <img src="assets/screenshot-login.png" width="22%" alt="Login" />
  <img src="assets/screenshot-dashboard.png" width="22%" alt="Dashboard" />
  <img src="assets/screenshot-network.png" width="22%" alt="Network" />
  <img src="assets/screenshot-server-detail.png" width="22%" alt="Server detail" />
</p>

---

## Features

- **Network** — full server list with load, users, health, ping latency, sort (load / name / ping), continent filter, search and favorites
- **Server comparison** — long-press any server to add it to a comparison (up to 3); tap the toolbar button to view them side by side
- **Dashboard** — account info (current IP, VPN status, expiration, credits, sessions, member since); swipe left on a session to disconnect
- **Server detail** — WireGuard or OpenVPN profile generation, direct import into the system VPN app, share and QR code (WireGuard) in a `···` menu; recent profiles per server with one-tap reimport
- **Profile history** — recently used server profiles shown in Dashboard and in each server detail; supports one-tap reimport by protocol
- **Biometric lock** — Face ID / Touch ID protection, toggleable in Settings
- **App icon** — 8 variants: Auto, Classic, Light, Purple, Green, Red, Minimal, Minimal Dark
- **Settings** — API key rotation, light/dark/system theme, app icon picker, changelog, credits
- **Notifications** — subscription expiration alerts 7 days and 1 day in advance (delivered by the OS even when the app is closed)
- **Siri Shortcuts** — VPN Status, My IP Address, Open Server (navigates directly to a specific server)
- **Widget** — current IP, VPN status and active sessions on the home screen; configurable with a favorite server picker showing load, users and latency (Small, Medium and Large sizes)
- **Quick Actions** — long-press the app icon to jump directly to Dashboard or Network

---

## Tech Stack

| | |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + iOS 26 Liquid Glass |
| Architecture | MVVM (`@MainActor` + `ObservableObject`) |
| Networking | `actor AirVPNAPIClient` with TTL cache |
| Security | API key stored in Keychain |
| Localisation | String Catalog (FR / EN) |
| Build | XcodeGen (`project.yml`) |
| Dependencies | [FlagKit](https://github.com/madebybowtie/FlagKit) |

---

## Installation — Pre-built IPA

A pre-built unsigned IPA is available on the [Releases](https://github.com/zlimteck/AirDash/releases) page. Install it with one of the following tools:

| Tool | Widget support |
|---|---|
| [AltStore](https://altstore.io) | ✅ Full support |
| [Sideloadly](https://sideloadly.io) | ✅ Full support |
| [LiveContainer](https://github.com/LiveContainerApp/LiveContainer) | ⚠️ App works, widget not supported |

> The widget requires a proper system installation to access the shared App Group. LiveContainer sandboxing prevents this.

---

## Build from Source

### Requirements

- Xcode 26 or later
- iOS 26 minimum (simulator or device)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed
- An AirVPN API key (account → *Client Area* → *API*)

---

## Installation & Build

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Clone and generate the project

The `.xcodeproj` is not versioned — generate it after cloning:

```bash
git clone https://github.com/zlimteck/AirDash.git
cd AirDash
xcodegen generate
open AirDash.xcodeproj
```

### 3. Resolve dependencies

Xcode downloads **FlagKit** automatically on first launch. If not:

**File → Packages → Resolve Package Versions**

### 4. Signing

- **Simulator** — no configuration needed, just hit **⌘R**
- **Real device** — Xcode → targets `AirDash` and `AirDashWidget` → *Signing & Capabilities* → select the same Apple team on both

> The widget and the app share an **App Group** (`group.com.airdash.ios`). Both targets must be signed with the same team for the group to work on a real device.

### Note

After adding any `.swift` file outside of Xcode, run `xcodegen generate` before building.

---

## Project Structure

```
AirDash/
├── AirDash/
│   ├── App/                  # Entry point, AppState, AppDelegate, SceneDelegate, MainTabView
│   ├── Intents/              # AppIntents (Siri Shortcuts), ServerEntity
│   ├── Models/               # AirVPNModels, AppError
│   ├── Networking/           # AirVPNAPIClient (actor), CacheService
│   ├── Services/             # KeychainService, VPNProfileImporter, SharedDataService, PingService, NotificationService, AppLockService, ProfileHistoryService
│   ├── ViewModels/           # DashboardViewModel, NetworkStatusViewModel, …
│   ├── Views/
│   │   ├── Components/       # GlassCard, GlassButton, FlagBadge, LoadBar, …
│   │   ├── Dashboard/        # DashboardView, SessionRowView
│   │   ├── NetworkStatus/    # NetworkStatusView, ServerRowView, ServerComparisonView
│   │   ├── Onboarding/       # OnboardingView
│   │   ├── ServerDetail/     # ServerDetailView, QRCodeView
│   │   └── Settings/         # SettingsView, ChangelogView, CreditsView, AppIconPickerView
│   └── Resources/            # Localizable.xcstrings, Assets.xcassets
└── AirDashWidget/            # Widget Extension (WidgetKit)
    └── AirDashWidget.swift   # AppIntentProvider, entry, Small/Medium/Large views, server picker intent
```

### Shared data (App Group)

The app and the widget communicate via `UserDefaults(suiteName: "group.com.airdash.ios")`. After each Dashboard load, `SharedDataService` writes the data and automatically reloads the widget.

---

## AirVPN API

The app exclusively uses the public AirVPN API:

| Endpoint | Usage |
|---|---|
| `POST /api/status/` | Server list and network stats |
| `POST /api/userinfo/` | Account info and active sessions |
| `POST /api/disconnect/` | Disconnect a VPN session |
| `POST /api/devices/` | Device management |
| `GET /api/generator/` | WireGuard / OpenVPN profile generation |

---

## Known Limitations

- Disconnecting a session via the app does not kill the active VPN tunnel on the device (this would require the *Personal VPN* entitlement and `NETunnelProviderManager`, which require a paid developer account)
- Widget and alternate app icons are not supported when installed via LiveContainer (system-level features require a native installation)

## Compatibility

- iPhone and iPad
- iOS 26 or later

---

## License

MIT

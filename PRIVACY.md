# Privacy Policy

**Last updated: September 4, 2026**

AirDash is an independent, unofficial companion app for [AirVPN](https://airvpn.org). It has no affiliation with AirVPN, and no account system or backend of its own beyond what is described below. This policy explains, in detail, what data AirDash accesses, stores, and transmits, and where.

## Data you provide

AirDash requires your personal AirVPN API key (from your AirVPN account, *Client Area → API*) to function. This key is:

- Stored only in the iOS Keychain, on your device
- Never transmitted anywhere except directly to AirVPN's own API (`airvpn.org`), to fetch your account and server data
- Never sent to the app developer or any third party

If you use Face ID / Touch ID to lock the app, biometric data is handled entirely by iOS and never leaves your device or reaches AirDash itself.

## What AirDash stores on your device

- **In the iOS Keychain** (encrypted, app-only unless noted): your AirVPN account(s) and API key(s); your generated VPN profile history, including WireGuard private keys and OpenVPN credentials, so you can re-import a previously generated profile without regenerating it.
- **In local `UserDefaults`** (this device only, never synced or transmitted): app preferences such as theme, app icon, sort order, favorite servers (scoped per account), the last device you picked when generating a profile, and feature toggles (biometric lock, the opt-in history features described below).
- **In a shared iOS App Group** (`group.com.airdash.ios`, readable only by AirDash and its own home screen widget, never leaves your device): your current public IP, whether a VPN session looks active, your AirVPN login and subscription expiration, a short list of your active sessions (server name, country, duration), your favorite/best server, and cached server and device names. This exists purely so the widget and Siri Shortcuts can display useful information and resolve their parameters without a network call of their own; none of it leaves the device.
- **Temporary files**: when you tap Share or Import on a generated profile, AirDash briefly writes that profile (private key included, for WireGuard) to the app's temporary directory, only for the duration of that handoff, and deletes it immediately afterward; it also clears any such file left over from an earlier interrupted session the next time the app launches. Outside of that brief window, no plaintext copy of your profile exists anywhere except the Keychain entry above.
- **Native VPN connections** (full build only, not the Lite build distributed for sideloading): the WireGuard tunnel itself is handled by iOS's own `NetworkExtension` framework. AirDash does not inspect, log, or transmit your VPN traffic; it only starts and stops the tunnel, and stores the current tunnel configuration in the Keychain (shared between the app and its Packet Tunnel extension) so the extension can read it.

## Server history & trends (opt-in, off by default)

Load/user history charts, peak hours, reliability badges, and the Trends screen are **disabled by default** and only activate if you turn on "Server History & Trends" in Settings.

When enabled, AirDash additionally queries `airvpn-api.zmtk.fr`, a small Cloudflare Worker the developer runs separately from AirVPN, to display historical data that AirVPN's own API doesn't expose. Specifically:

- **What it's asked for and stores**: only public server metrics (load, connected users, bandwidth, health) polled periodically from AirVPN's own public status, the same information visible to anyone on AirVPN's status page. It never receives your API key, account information, or any other personal data; the application code has no path that would let it.
- **What it unavoidably sees, like any web server**: your device's source IP address and request timing, simply because that's part of how HTTP requests work. Neither the application code nor Cloudflare's platform-level request logging retain this: per-request logging ("Workers Logs") is disabled on this Worker, so no IP address or request metadata is stored anywhere, even transiently, past the moment the request is served. Only error messages the code itself explicitly logs for debugging are retained, and those never include request metadata.
- **Source code**: the Worker is open source, available at [github.com/zlimteck/airvpn-history-worker](https://github.com/zlimteck/airvpn-history-worker), so you can verify all of the above yourself rather than take this document's word for it.

If you'd rather not have any request reach this service at all, simply leave the feature turned off; nothing above is used by any other part of the app.

## What AirDash does not do

- No analytics, crash reporting, or advertising SDKs
- No account system, sign-up, or user tracking
- No data is sold, shared, or used for advertising

## Notifications

Subscription expiration reminders are scheduled locally on your device via iOS notifications. No push notification server is involved.

## Changes to this policy

If this policy changes, the update will be reflected here with a new "Last updated" date.

## Contact

Questions or concerns: open an issue on the [GitHub repository](https://github.com/zlimteck/AirDash/issues).

# Re-signing AirDash with zsign

AirDash ships 3 separate bundles inside one IPA, each with its own Bundle ID:

| Component | Bundle ID | Needs its own App ID/profile because of |
|---|---|---|
| `AirDash.app` | `com.airdash.ios` | Personal VPN, Network Extension, App Groups |
| `AirDashTunnel.appex` | `com.airdash.ios.tunnel` | Network Extension (Packet Tunnel Provider), App Groups, Keychain Sharing |
| `AirDashWidget.appex` | `com.airdash.ios.widget` | App Groups |

iOS signs and validates **each Mach-O executable in the bundle individually** — the app and every extension carry their own embedded `.mobileprovision` and must each resolve to a matching `application-identifier`. A re-signing tool that only accepts **one** certificate/profile for the whole IPA (as some GUI resigners do) cannot correctly sign this app: it will either fail outright, or sign the extensions with the app's own profile, which breaks App Groups / Keychain sharing / the VPN entitlement on the extensions.

`zsign` (https://github.com/zhlynn/zsign) signs each bundle individually with a different profile, which AirDash requires. This doc is the exact recipe, generalized — no personal credentials, no team ID.

## Prerequisites

- A **paid** Apple Developer Program account. VPN / Network Extension entitlements are never granted to a free/personal-team account, regardless of signing tool.
- 3 distinct App IDs on the portal, matching your actual Bundle IDs (adjust the suffix/prefix to whatever your account uses — Xcode-managed "XC ..." App IDs, or ones a tool like SideStore auto-created with your Team ID appended):
  - App (VPN + Network Extension + App Groups)
  - Tunnel extension (Network Extension + App Groups + Keychain Sharing)
  - Widget extension (App Groups only)
- **The App Group `group.<your-bundle-id>` must be explicitly attached to all 3 App IDs** on the portal — just enabling the "App Groups" capability is not enough, you have to select the actual group inside each App ID's configuration. This is the single most common mistake: a freshly generated profile with App Groups "enabled" but no group selected produces an **empty** `application-groups` array in the entitlements, which silently breaks shared UserDefaults (widget) and the shared Keychain item (tunnel config).
- 3 separate `.mobileprovision` files downloaded, one per App ID.
- A code-signing certificate `.p12` + its password, valid for the same team as the 3 App IDs.

## 1. Build zsign

```bash
brew install pkg-config openssl
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/macos
make clean && make
```

The binary lands at `zsign/bin/zsign` (not in `build/macos/`).

## 2. Extract the IPA

```bash
mkdir AirDash_work && cd AirDash_work
unzip ../AirDash.ipa
```

## 3. Decode each provisioning profile to a plist, then extract its Entitlements

Use `-o` for the output, not `>` — a failed `security cms -D` still creates an (empty) file with `>`, which then silently breaks the next step.

```bash
security cms -D -i AirDash.mobileprovision            -o airdash-profile.plist
security cms -D -i AirDashTunnel.mobileprovision       -o airdash-tunnel-profile.plist
security cms -D -i AirDashWidget.mobileprovision       -o airdash-widget-profile.plist

/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-profile.plist         > airdash.entitlements
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-tunnel-profile.plist  > airdash-tunnel.entitlements
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-widget-profile.plist  > airdash-widget.entitlements
```

**Sanity-check each `.entitlements` file before continuing:**

```bash
grep -A3 application-groups airdash.entitlements
grep -A3 application-groups airdash-tunnel.entitlements
grep -A3 application-groups airdash-widget.entitlements
```

If any of them shows `<array/>` (empty) instead of `<string>group.your.id</string>`, go back to the portal, attach the App Group to that App ID explicitly, regenerate the profile, re-download it, and redo this step. Also confirm the app's and tunnel's entitlements contain `com.apple.developer.networking.networkextension` / `com.apple.developer.networking.vpn.api` — an App ID with those capabilities not yet enabled at profile-generation time produces a profile silently missing them, with no error anywhere in the chain.

## 4. If your App IDs don't use the original Bundle IDs verbatim (e.g. a Team ID suffix)

Some tools (SideStore, AltStore) auto-create App IDs with the Team ID appended to avoid colliding with App Store-registered IDs (`com.yourapp.ios.TEAMID` instead of `com.yourapp.ios`). If that's what your 3 profiles were generated for, you must rewrite each bundle's `CFBundleIdentifier` to match **before** signing — otherwise the signed `application-identifier` entitlement won't match the actual bundle ID and the install is rejected ("Mismatched bundle IDs").

```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID"         Payload/AirDash.app/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID.tunnel"  Payload/AirDash.app/PlugIns/AirDashTunnel.appex/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID.widget"  Payload/AirDash.app/PlugIns/AirDashWidget.appex/Info.plist
```

Skip this step entirely if your profiles were generated for the exact original Bundle IDs (`com.airdash.ios` etc.) — that's the simpler, recommended path when you don't have a reason to suffix.

## 5. Sign — **extensions after the app, not before**

Signing the app bundle makes zsign walk and re-sign every nested `.appex` too, using the app's own entitlements — which overwrites whatever you signed them with earlier. Always sign in this order: app first, extensions last.

Use `-f` (force) on every call. Without it, zsign may reuse a stale cache from a previous signing pass of the same folder and silently keep the old Bundle ID/entitlements even after you've edited `Info.plist`.

```bash
# 1. App first
../bin/zsign -f -k Certificates.p12 -p "$P12_PASSWORD" \
  -m airdash.mobileprovision \
  -e airdash.entitlements \
  Payload/AirDash.app

# 2. Extensions last, so the app's signing pass doesn't overwrite them
../bin/zsign -f -k Certificates.p12 -p "$P12_PASSWORD" \
  -m airdash-tunnel.mobileprovision \
  -e airdash-tunnel.entitlements \
  Payload/AirDash.app/PlugIns/AirDashTunnel.appex

../bin/zsign -f -k Certificates.p12 -p "$P12_PASSWORD" \
  -m airdash-widget.mobileprovision \
  -e airdash-widget.entitlements \
  Payload/AirDash.app/PlugIns/AirDashWidget.appex
```

(`$P12_PASSWORD` — export it in your shell, or type it inline; never commit it anywhere.)

## 6. Verify before packaging

```bash
for target in \
  Payload/AirDash.app \
  Payload/AirDash.app/PlugIns/AirDashTunnel.appex \
  Payload/AirDash.app/PlugIns/AirDashWidget.appex
do
  echo "== $target =="
  codesign -dv "$target" 2>&1 | grep Identifier
  codesign -d --entitlements :- "$target" 2>&1 | grep -v warning
  echo
done
```

Confirm for each:
- `Identifier=` (from `Info.plist`) matches the suffix of its own `application-identifier` in the entitlements — not the app's.
- The Tunnel keeps `com.apple.developer.networking.networkextension` and `com.apple.developer.networking.vpn.api` (app only).
- Both extensions keep a non-empty `com.apple.security.application-groups`.
- Only the app and the Tunnel carry `keychain-access-groups`; the Widget never used the Keychain in this project so it shouldn't need it either.

## 7. Repackage and install

```bash
cd AirDash_work
zip -qr ../AirDash-resigned.ipa Payload
cd ..
```

Install with **Apple Configurator 2** (free, Mac App Store) by dragging the IPA onto the connected device, or with `ideviceinstaller -i AirDash-resigned.ipa`. No further re-signing tool is needed — the IPA is already correctly, individually signed.

## Why a single-profile resigner (e.g. a GUI tool that only lets you pick one profile for the whole IPA) can't do this

It's not a bug in those tools specifically — it's an Apple platform rule. A provisioning profile's App ID is either an **exact Bundle ID match** or a **wildcard** (`TEAMID.*`). A wildcard profile can cover any Bundle ID with one file, but Apple does not allow App Groups, Keychain Sharing, or Network Extension capabilities on a wildcard App ID — ever, on any tool, on any account tier. Since AirDash's Tunnel and Widget both need App Groups (and the Tunnel also needs Network Extension + Keychain Sharing), a wildcard can't carry them, which is why 3 explicit profiles — and therefore a tool that applies them per-component — are required.

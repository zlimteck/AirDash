# Re-signing AirDash with zsign

AirDash ships 3 separate bundles inside one IPA, each with its own Bundle ID:

| Component | Bundle ID | Needs its own App ID/profile because of |
|---|---|---|
| `AirDash.app` | `com.airdash.ios` | Personal VPN, Network Extension, App Groups, Keychain Sharing |
| `AirDashTunnel.appex` | `com.airdash.ios.tunnel` | Network Extension (Packet Tunnel Provider), App Groups, Keychain Sharing |
| `AirDashWidget.appex` | `com.airdash.ios.widget` | App Groups |

iOS signs and validates **each Mach-O executable in the bundle individually** — the app and every extension carry their own embedded `.mobileprovision` and must each resolve to a matching `application-identifier`. A re-signing tool that only accepts **one** certificate/profile for the whole IPA (as some GUI resigners do) cannot correctly sign this app: it will either fail outright, or sign the extensions with the app's own profile, which breaks App Groups / Keychain sharing / the VPN entitlement on the extensions.

`zsign` (https://github.com/zhlynn/zsign) can sign each bundle individually with a different profile, which AirDash requires — but it has a quirk around nested extensions (see step 6) that needs Apple's own `codesign` for the final step. This doc is the exact recipe that was validated end-to-end on a real device, generalized — no personal credentials, no team ID.

## Prerequisites

- A **paid** Apple Developer Program account. VPN / Network Extension entitlements are never granted to a free/personal-team account, regardless of signing tool.
- 3 distinct App IDs on the portal, matching your actual Bundle IDs (adjust the suffix/prefix to whatever your account uses — Xcode-managed "XC ..." App IDs, or ones a tool like SideStore auto-created with your Team ID appended):
  - App (Personal VPN + Network Extension + App Groups + Keychain Sharing)
  - Tunnel extension (Network Extension + App Groups + Keychain Sharing)
  - Widget extension (App Groups only)
- **The App Group `group.<your-bundle-id>` must be explicitly attached to all 3 App IDs** on the portal — just enabling the "App Groups" capability is not enough, you have to select the actual group inside each App ID's configuration. This is the single most common mistake: a freshly generated profile with App Groups "enabled" but no group selected produces an **empty** `application-groups` array in the entitlements, which silently breaks shared UserDefaults (widget) and the shared Keychain item (tunnel config).
- If you're signing a **Development**-type profile (not Ad Hoc/Distribution), **your device's UDID must be registered under Devices on the portal and included in all 3 profiles**, or the install fails with a generic "integrity could not be verified" message. Check with `/usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" airdash-profile.plist`.
- 3 separate `.mobileprovision` files downloaded, one per App ID.
- A code-signing certificate `.p12` + its password, valid for the same team as the 3 App IDs. It also needs to be importable into your login keychain for the final step (step 6).

## 1. Build zsign

```bash
brew install pkg-config openssl
git clone https://github.com/zhlynn/zsign.git
cd zsign/build/macos
make clean && make
```

The binary lands at `zsign/bin/zsign`, not in `build/macos/`.

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

**Fix the `keychain-access-groups` wildcard.** A profile's own declared entitlements commonly list `TEAMID.*` (a wildcard) for `keychain-access-groups`, rather than your app's actual group — Apple shows the broadest thing the profile *permits*, not what your app *uses*. AirDash's code (`TunnelKeychainService`) writes to the Keychain using the specific group `group.com.airdash.ios`, not a wildcard, so the entitlements you sign with must spell it out explicitly or the write fails at runtime with `errSecMissingEntitlement` (-34018), surfaced in the app as "Tunnel keychain write failed: -34018". Replace the wildcard on both the app and tunnel entitlements:

```bash
sed -i '' 's|TEAMID\.\*|TEAMID.group.com.airdash.ios|' airdash.entitlements
sed -i '' 's|TEAMID\.\*|TEAMID.group.com.airdash.ios|' airdash-tunnel.entitlements
```

(replace `TEAMID` with your real team ID both in the command and in the resulting file — check the result keeps the `com.apple.token` entry alongside it.)

## 4. If your App IDs don't use the original Bundle IDs verbatim (e.g. a Team ID suffix)

Some tools (SideStore, AltStore) auto-create App IDs with the Team ID appended to avoid colliding with App Store-registered IDs (`com.yourapp.ios.TEAMID` instead of `com.yourapp.ios`). If that's what your 3 profiles were generated for, you must rewrite each bundle's `CFBundleIdentifier` to match **before** signing — otherwise the signed `application-identifier` entitlement won't match the actual bundle ID and the install is rejected ("Mismatched bundle IDs").

```bash
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID"         Payload/AirDash.app/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID.tunnel"  Payload/AirDash.app/PlugIns/AirDashTunnel.appex/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yourapp.ios.TEAMID.widget"  Payload/AirDash.app/PlugIns/AirDashWidget.appex/Info.plist
```

Skip this step entirely if your profiles were generated for the exact original Bundle IDs (`com.airdash.ios` etc.) — that's the simpler, recommended path when you don't have a reason to suffix.

## 5. Sign the two extensions with zsign

Use `-f` (force) on every call. Without it, zsign may reuse a stale cache from a previous signing pass of the same folder and silently keep the old Bundle ID/entitlements even after you've edited `Info.plist`.

```bash
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

## 6. Sign the app **last, with Apple's own `codesign`** — not zsign

This is the step that took the most trial and error, so it's worth explaining why.

zsign has no option to leave an already-signed nested `.appex` alone: whenever it signs a `.app` folder, it unconditionally re-walks and re-signs every bundle inside `PlugIns/` too, using the app's own profile/entitlements. That overwrites the extensions' correct per-component signatures (wrong `application-identifier`, wrong capabilities) — so signing the app with zsign has to happen *before* the extensions, never after.

But signing the app *before* the extensions creates the opposite problem: the app's `_CodeSignature/CodeResources` seal gets computed at that point, and then re-signing the extensions afterwards changes bytes on disk that seal doesn't expect — `installd` rejects the install with:

```
Failed to verify code signature of .../AirDash.app : 0xe8008017
(A signed resource has been added, modified, or deleted.)
```

surfaced on-device as the generic "This app's integrity could not be verified."

The fix: sign the two extensions first (step 5, done), then sign the app **last** using the real `codesign` binary (already installed with Xcode's command line tools) instead of zsign — without `--deep`. Unlike zsign, `codesign` without `--deep` never descends into nested `.appex`/`.framework` bundles, so it reseals the app's own resources correctly while leaving the already-signed extensions untouched.

```bash
# Make sure your signing identity is in your login keychain:
security find-identity -v -p codesigning
# If it's not listed, import it:
security import Certificates.p12 -k ~/Library/Keychains/login.keychain-db -P "$P12_PASSWORD" -T /usr/bin/codesign

# codesign/installd expects embedded.mobileprovision inside the .app itself:
cp AirDash.mobileprovision Payload/AirDash.app/embedded.mobileprovision

codesign -f -s "Apple Development: Your Name (TEAMID)" \
  --entitlements airdash.entitlements \
  Payload/AirDash.app
```

(use the exact identity string `security find-identity` printed)

## 7. Verify before packaging

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

codesign --verify --deep --strict -v Payload/AirDash.app
echo "exit code: $?"
```

Confirm for each bundle:
- `Identifier=` (from `Info.plist`) matches the suffix of its own `application-identifier` in the entitlements — not the app's.
- The Tunnel keeps `com.apple.developer.networking.networkextension`; `com.apple.developer.networking.vpn.api` is app-only.
- Both extensions keep a non-empty `com.apple.security.application-groups`.
- The app and the Tunnel carry `keychain-access-groups` with the **specific** group (`TEAMID.group.com.airdash.ios`), not a `TEAMID.*` wildcard. The Widget never used the Keychain in this project so it shouldn't need it either.
- `codesign --verify --deep --strict` exits `0` with "valid on disk" / "satisfies its Designated Requirement" — this is the same check `installd` performs, so if it fails here it will fail on-device too.

## 8. Repackage and install

```bash
find . -name ".DS_Store" -delete
rm -f ../AirDash-resigned.ipa
zip -qr ../AirDash-resigned.ipa Payload
cd ..
```

Install with **Apple Configurator 2** (free, Mac App Store) by dragging the IPA onto the connected device, or with `ideviceinstaller -i AirDash-resigned.ipa`. No further re-signing tool is needed — the IPA is already correctly, individually signed.

## Troubleshooting reference

| Symptom | Cause | Fix |
|---|---|---|
| "This app's integrity could not be verified" at install | **Device UDID not in the profile** (Development-type profiles only) | Add the device under Devices on the portal, regenerate and re-download the profile |
| Same message, but `idevicesyslog` shows `0xe8008017 (A signed resource has been added, modified, or deleted.)` | App's `CodeResources` seal is stale because extensions were re-signed after the app | Sign extensions first, then the app last with real `codesign` (no `--deep`) — step 6 |
| App installs and launches, but `Tunnel keychain write failed: -34018` | `keychain-access-groups` in the signed entitlements is the profile's generic `TEAMID.*` wildcard instead of the app's actual group | Replace the wildcard with `TEAMID.group.com.airdash.ios` explicitly — step 3 |
| Install fails with "Mismatched bundle IDs" | The entitlements' `application-identifier` doesn't match the bundle's actual `CFBundleIdentifier` | Make sure step 4 (if applicable) ran before signing, and re-run `-f` on zsign calls to bypass its cache |
| `zsign` crashes with `Assertion failed: ... "Unsupported Entitlements DER Type"` | The entitlements file being signed is empty/malformed (commonly because `security cms -D ... > file.plist` silently wrote an error message into the file instead of real content) | Re-run `security cms -D -i profile.mobileprovision -o file.plist` (use `-o`, not `>`) and confirm the file starts with `<?xml` before re-signing |

## Why a single-profile resigner (e.g. a GUI tool that only lets you pick one profile for the whole IPA) can't do this

It's not a bug in those tools specifically — it's an Apple platform rule. A provisioning profile's App ID is either an **exact Bundle ID match** or a **wildcard** (`TEAMID.*`). A wildcard profile can cover any Bundle ID with one file, but Apple does not allow App Groups, Keychain Sharing, or Network Extension capabilities on a wildcard App ID — ever, on any tool, on any account tier. Since AirDash's Tunnel and Widget both need App Groups (and the Tunnel also needs Network Extension + Keychain Sharing), a wildcard can't carry them, which is why 3 explicit profiles — and therefore a tool that applies them per-component — are required.

#!/bin/bash
# Re-signs an AirDash IPA with 3 separate provisioning profiles (app + tunnel + widget)
# using zsign for the extensions and Apple's own codesign for the app (last, no --deep).
#
# This is NOT meant to be committed to the repo: it's a personal local helper.
# Fill in the variables below for your setup, then run: ./resign-airdash.sh

set -euo pipefail

# ─── EDIT THESE ──────────────────────────────────────────────────────────────

IPA_PATH="AirDash.ipa"                     # source IPA to re-sign
WORK_DIR="AirDash_work"                    # scratch folder (recreated each run)
ZSIGN_BIN="$HOME/zsign/bin/zsign"          # path to the compiled zsign binary

P12_PATH="Certificates.p12"
P12_PASSWORD="CHANGE_ME"

TEAM_ID="CHANGE_ME"                        # e.g. B6T8AU4P3G
APP_GROUP="group.com.airdash.ios"          # must match TunnelKeychainService/SharedDataService

# Bundle IDs actually baked into the IPA (what Xcode produced).
APP_BUNDLE_ID_SRC="com.airdash.ios"
TUNNEL_BUNDLE_ID_SRC="com.airdash.ios.tunnel"
WIDGET_BUNDLE_ID_SRC="com.airdash.ios.widget"

# Bundle IDs your 3 App IDs/profiles actually use. Leave identical to the
# *_SRC values above if your profiles were generated for the exact original
# Bundle IDs (recommended/simplest path). Set these only if your App IDs use
# something else, e.g. a Team-ID-suffixed scheme some tools auto-create.
APP_BUNDLE_ID_DST="$APP_BUNDLE_ID_SRC"
TUNNEL_BUNDLE_ID_DST="$TUNNEL_BUNDLE_ID_SRC"
WIDGET_BUNDLE_ID_DST="$WIDGET_BUNDLE_ID_SRC"

APP_PROFILE="AirDash.mobileprovision"
TUNNEL_PROFILE="AirDashTunnel.mobileprovision"
WIDGET_PROFILE="AirDashWidget.mobileprovision"

CODESIGN_IDENTITY="CHANGE_ME"              # e.g. "Apple Development: Your Name (TEAMID)": must already be in your login keychain

OUTPUT_IPA="AirDash-resigned.ipa"

# ──────────────────────────────────────────────────────────────────────────

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31mERROR:\033[0m %s\n' "$1" >&2; exit 1; }

[[ -f "$IPA_PATH" ]] || die "IPA not found: $IPA_PATH"
[[ -x "$ZSIGN_BIN" ]] || die "zsign binary not found/executable at: $ZSIGN_BIN"
[[ -f "$P12_PATH" ]] || die "p12 not found: $P12_PATH"
[[ -f "$APP_PROFILE" && -f "$TUNNEL_PROFILE" && -f "$WIDGET_PROFILE" ]] || die "one or more .mobileprovision files not found"
[[ "$P12_PASSWORD" != "CHANGE_ME" ]] || die "edit P12_PASSWORD at the top of this script"
[[ "$TEAM_ID" != "CHANGE_ME" ]] || die "edit TEAM_ID at the top of this script"
[[ "$CODESIGN_IDENTITY" != "CHANGE_ME" ]] || die "edit CODESIGN_IDENTITY at the top of this script (see: security find-identity -v -p codesigning)"

say "Checking codesign identity is in the login keychain"
if ! security find-identity -v -p codesigning | grep -qF "$CODESIGN_IDENTITY"; then
  say "Importing $P12_PATH into login keychain"
  security import "$P12_PATH" -k ~/Library/Keychains/login.keychain-db -P "$P12_PASSWORD" -T /usr/bin/codesign
fi

say "Resetting work dir: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir "$WORK_DIR"
unzip -q "$IPA_PATH" -d "$WORK_DIR"
cd "$WORK_DIR"

# macOS re-tags files with Finder metadata (com.apple.FinderInfo) just by having
# a Finder window open on this folder while it's being worked on. codesign
# --strict rejects that xattr outright ("resource fork, Finder information, or
# similar detritus not allowed"), and WidgetKit swallows the resulting signature
# failure silently: the extension launches but produces an empty timeline, with
# no crash log anywhere to point at the real cause. Stripped before every
# signing pass and again right before zipping so this can never sneak back in.
xattr -cr Payload

APP_PATH="Payload/AirDash.app"
TUNNEL_PATH="$APP_PATH/PlugIns/AirDashTunnel.appex"
WIDGET_PATH="$APP_PATH/PlugIns/AirDashWidget.appex"

[[ -d "$APP_PATH" ]] || die "Payload/AirDash.app not found in IPA: check IPA_PATH / Payload layout"

say "Decoding provisioning profiles"
for pair in "../$APP_PROFILE:airdash-profile.plist" "../$TUNNEL_PROFILE:airdash-tunnel-profile.plist" "../$WIDGET_PROFILE:airdash-widget-profile.plist"; do
  src="${pair%%:*}"; out="${pair##*:}"
  security cms -D -i "$src" -o "$out"
  head -c5 "$out" | grep -q '<?xml' || die "failed to decode $src: check it's a valid .mobileprovision"
done

say "Extracting entitlements from each profile"
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-profile.plist        > airdash.entitlements
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-tunnel-profile.plist > airdash-tunnel.entitlements
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" airdash-widget-profile.plist > airdash-widget.entitlements

say "Checking App Groups aren't empty in the decoded entitlements"
for f in airdash.entitlements airdash-tunnel.entitlements airdash-widget.entitlements; do
  grep -q "$APP_GROUP" "$f" || die "$f does not contain $APP_GROUP: attach the App Group to that App ID on the portal, regenerate+redownload the profile, and re-run."
done

say "Replacing any TEAMID.* keychain-access-groups wildcard with the real group"
for f in airdash.entitlements airdash-tunnel.entitlements; do
  sed -i '' "s|${TEAM_ID}\.\*|${TEAM_ID}.${APP_GROUP}|" "$f"
done

if [[ "$APP_BUNDLE_ID_DST" != "$APP_BUNDLE_ID_SRC" ]]; then
  say "Rewriting CFBundleIdentifier to match destination App IDs"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID_DST"    "$APP_PATH/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $TUNNEL_BUNDLE_ID_DST" "$TUNNEL_PATH/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $WIDGET_BUNDLE_ID_DST" "$WIDGET_PATH/Info.plist"
fi

say "Signing AirDashTunnel.appex with zsign"
"$ZSIGN_BIN" -f -k "../$P12_PATH" -p "$P12_PASSWORD" \
  -m "../$TUNNEL_PROFILE" \
  -e airdash-tunnel.entitlements \
  "$TUNNEL_PATH"

say "Signing AirDashWidget.appex with zsign"
"$ZSIGN_BIN" -f -k "../$P12_PATH" -p "$P12_PASSWORD" \
  -m "../$WIDGET_PROFILE" \
  -e airdash-widget.entitlements \
  "$WIDGET_PATH"

xattr -cr Payload

say "Signing AirDash.app LAST with Apple's own codesign (no --deep, so it won't touch the extensions)"
cp "../$APP_PROFILE" "$APP_PATH/embedded.mobileprovision"
codesign -f -s "$CODESIGN_IDENTITY" --entitlements airdash.entitlements "$APP_PATH"

say "Verifying signatures"
for target in "$APP_PATH" "$TUNNEL_PATH" "$WIDGET_PATH"; do
  echo "-- $target --"
  codesign -dv "$target" 2>&1 | grep Identifier
  codesign --verify --strict -v "$target" || die "codesign --verify --strict failed on $target: do not install this IPA, it will fail (or silently show empty data) on-device too"
done
codesign --verify --deep --strict -v "$APP_PATH" || die "codesign --verify --deep --strict failed: do not install this IPA, it will fail on-device too"

say "Packaging $OUTPUT_IPA"
xattr -cr Payload
find . -name ".DS_Store" -delete
rm -f "../$OUTPUT_IPA"
zip -qr "../$OUTPUT_IPA" Payload
cd ..

say "Done: $OUTPUT_IPA"
echo "Install with Apple Configurator 2, or: ideviceinstaller -i $OUTPUT_IPA"

#!/usr/bin/env bash
# iOS run helper – mirrors the behaviour of mobile/scripts/android/run.sh
# 1. Lists available iOS simulators and lets the user choose one.
# 2. If no simulator exists, a default iPad simulator is created automatically.
# 3. Boots the chosen simulator (if needed), installs the built app and launches it.
# 4. For physical devices: automatically signs the app if MATCH_DEV_PASSWORD is set.

set -euo pipefail

CWD=$(realpath "$(dirname "$0")")
APP=${APP:-"$CWD/../../bin/Applications/Status.app"}  # Path to the .app bundle
APPID=${APPID:-$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")} # Bundle identifier of the app
SIMULATOR_UDID=${SIMULATOR_UDID:-""}               # Specify to skip interactive selection
IPHONE_SDK=${IPHONE_SDK:-iphonesimulator}  # Default to simulator if not set
DEVICE_ID=${DEVICE_ID:-""}                # For physical device selection
FASTLANE_DIR="$CWD/../../fastlane"
SKIP_SIGNING=${SKIP_SIGNING:-0}           # Set to 1 to skip automatic signing

# Create a default iPad simulator if none are found
create_default_simulator() {
  DEFAULT_NAME="status-default-sim"
  DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-16GB"

  echo "Creating default simulator: $DEFAULT_NAME ($DEVICE_TYPE)"
  xcrun simctl create "$DEFAULT_NAME" "$DEVICE_TYPE" || {
    echo "Failed to create the default simulator"; exit 1;
  }
}

# Present the list of available devices and let the user pick one
select_device() {
  local device_lines
  device_lines=$(xcrun devicectl list devices --hide-headers)

  if [[ -z "$device_lines" ]]; then
    echo "No available devices found. Exiting."; exit 1;
  fi

  echo "Available devices:"
  echo "$device_lines" | nl -w2 -s': '

  read -rp "Select a device to use (enter number): " selection

  local selected_line
  selected_line=$(echo "$device_lines" | sed -n "${selection}p")
  if [[ -z "$selected_line" ]]; then
    echo "Invalid selection. Exiting."; exit 1;
  fi

  DEVICE_ID=$(echo "$selected_line" | awk '{print $3}')
  DEVICE_NAME=$(echo "$selected_line" | awk '{print substr($0, 1, index($0, $3)-2)}' | xargs)
}

# Present the list of available simulators and let the user pick one
select_simulator() {
  local device_lines
  device_lines=$(xcrun simctl list devices available | grep -E "^\s{4}.*\(" || true)

  if [[ -z "$device_lines" ]]; then
    echo "No simulators found. Creating a default one..."
    create_default_simulator
    device_lines=$(xcrun simctl list devices available | grep -E "^\s{4}.*\(")
  fi

  echo "Available simulators:"
  echo "$device_lines" | nl -w2 -s': '

  read -rp "Select a simulator to use (enter number): " selection

  local selected_line
  selected_line=$(echo "$device_lines" | sed -n "${selection}p")
  if [[ -z "$selected_line" ]]; then
    echo "Invalid selection. Exiting."; exit 1;
  fi

  SIMULATOR_UDID=$(echo "$selected_line" | grep -E -o "([0-9A-Fa-f-]{36})")
  SIMULATOR_NAME=$(echo "$selected_line" | sed -E 's/^\s+([^()]*)\s+\(.*/\1/' | xargs)
}

# Check if app is signed for device deployment
is_app_signed() {
  # Check if the app has a valid signature
  codesign -v "$APP" 2>/dev/null
}

# Sign the app for physical device deployment
sign_app_for_device() {
  if [[ "$SKIP_SIGNING" == "1" ]]; then
    echo "Skipping signing (SKIP_SIGNING=1)"
    return 0
  fi

  # Check if already signed
  if is_app_signed; then
    echo "App is already signed, skipping signing step"
    return 0
  fi

  echo ""
  echo "=================================================="
  echo "App needs to be signed for physical device"
  echo "=================================================="

  # Check for MATCH_DEV_PASSWORD
  if [[ -z "${MATCH_DEV_PASSWORD:-}" ]]; then
    echo ""
    echo "ERROR: MATCH_DEV_PASSWORD not set"
    echo ""
    echo "To sign the app for physical device, set MATCH_DEV_PASSWORD:"
    echo "  export MATCH_DEV_PASSWORD='...'"
    echo ""
    echo "Then run again:"
    echo "  make mobile-run IPHONE_SDK=iphoneos"
    echo ""
    echo "Or skip signing (app won't install on device):"
    echo "  SKIP_SIGNING=1 make mobile-run IPHONE_SDK=iphoneos"
    echo "=================================================="
    exit 1
  fi

  echo "Signing app with fastlane..."

  # Run fastlane in nix shell
  if command -v nix &>/dev/null; then
    (cd "$FASTLANE_DIR" && \
      nix --extra-experimental-features 'nix-command flakes' develop --command \
      bundle exec fastlane ios development)
  else
    # Fallback: try running fastlane directly if nix is not available
    echo "Warning: nix not found, trying direct fastlane execution..."
    (cd "$FASTLANE_DIR" && bundle exec fastlane ios development)
  fi

  if [[ $? -eq 0 ]]; then
    echo ""
    echo "=================================================="
    echo "App signed successfully!"
    echo "=================================================="
  else
    echo ""
    echo "=================================================="
    echo "Signing failed! Check the error above."
    echo "=================================================="
    exit 1
  fi
}

run_device() {
  if [[ -z "$DEVICE_ID" ]]; then
    select_device
  fi

  # Sign the app before installing on device
  sign_app_for_device

  echo "Using device: ${DEVICE_NAME:-$DEVICE_ID}"

  # Install the app on the device
  echo "Installing app $APP onto device $DEVICE_ID"
  if ! xcrun devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1; then
    echo ""
    echo "=================================================="
    echo "Installation failed. Common issues:"
    echo ""
    echo "1. App not signed: Set MATCH_DEV_PASSWORD and rebuild"
    echo "   export MATCH_DEV_PASSWORD='...'"
    echo "   make mobile-build IPHONE_SDK=iphoneos"
    echo ""
    echo "2. Device not trusted: On your iOS device go to:"
    echo "   Settings > General > VPN & Device Management"
    echo "   Find the developer profile and tap 'Trust'"
    echo "=================================================="
    exit 1
  fi

  echo ""
  echo "=================================================="
  echo "First time running on this device?"
  echo "If the app doesn't launch, trust the developer profile:"
  echo "  Settings > General > VPN & Device Management > Trust"
  echo "=================================================="
  echo ""

  # Launch the app on the device
  echo "Launching $APPID on device $DEVICE_ID"
  xcrun devicectl device process launch --activate --console --device "$DEVICE_ID" "$APPID"
}

run_simulator() {
  # If no UDID provided via env var, ask the user
  if [[ -z "$SIMULATOR_UDID" ]]; then
    select_simulator
  fi

  # Get info/state for the chosen simulator
  SIMULATOR_INFO=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | head -n 1 || true)
  if [[ -z "$SIMULATOR_INFO" ]]; then
    echo "Simulator $SIMULATOR_UDID not found. Exiting."; exit 1;
  fi
  SIMULATOR_STATE=$(echo "$SIMULATOR_INFO" | grep -E -o "\((Booted|Shutdown|Shutting Down|Creating|Deleting)\)" | tr -d '()')

  echo "Using simulator: ${SIMULATOR_NAME:-$SIMULATOR_UDID} – state: $SIMULATOR_STATE"

  # Boot if necessary
  if [[ "$SIMULATOR_STATE" != "Booted" ]]; then
    echo "Booting simulator $SIMULATOR_UDID..."
    xcrun simctl boot "$SIMULATOR_UDID"
  fi

  # Bring Simulator app to foreground with the chosen device
  open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID"

  # Re-install the app
  echo "Installing app $APP onto simulator $SIMULATOR_UDID"
  xcrun simctl install "$SIMULATOR_UDID" "$APP"

  # Launch the app (using --console-pty to avoid freeze issues)
  echo "Launching $APPID"
  xcrun simctl launch --console-pty "$SIMULATOR_UDID" "$APPID"
}

if [[ "$IPHONE_SDK" == "iphoneos" ]]; then
  run_device
elif [[ "$IPHONE_SDK" == "iphonesimulator" ]]; then
  run_simulator
else
  echo "Invalid SDK specified: $IPHONE_SDK. Use 'iphonesimulator' or 'iphoneos'."
  exit 1
fi

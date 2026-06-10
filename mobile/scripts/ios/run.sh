#!/usr/bin/env bash
# iOS run helper – mirrors the behaviour of mobile/scripts/android/run.sh
# 1. Lists available iOS simulators and lets the user choose one.
# 2. If no simulator exists, a default iPad simulator is created automatically.
# 3. Boots the chosen simulator (if needed), installs the built app and launches it.

set -euo pipefail

CWD=$(realpath "$(dirname "$0")")
APP=${APP:-"$CWD/../../bin/Applications/Status.app"}  # Path to the .app bundle
APPID=${APPID:-$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")} # Bundle identifier of the app
SIMULATOR_UDID=${SIMULATOR_UDID:-""}               # Specify to skip interactive selection
IPHONE_SDK=${IPHONE_SDK:-iphonesimulator}  # Default to simulator if not set
DEVICE_ID=${DEVICE_ID:-""}                # For physical device selection

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

  DEVICE_ID=$(echo "$selected_line" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
  DEVICE_NAME=$(echo "$selected_line" | awk -F '  +' '{print $1}' | xargs)
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

run_device() {
  if [[ -z "$DEVICE_ID" ]]; then
    select_device
  fi

  echo "Using device: ${DEVICE_NAME:-$DEVICE_ID}"

  # Install the app on the device
  echo "Installing app $APP onto device $DEVICE_ID"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

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

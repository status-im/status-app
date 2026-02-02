#!/usr/bin/env bash

CWD=$(realpath `dirname $0`)
APP=${APP:="$CWD/../bin/$OS/Status.apk"}
# for local builds debug variant is default
APP_PACKAGE=${APP_PACKAGE:="app.status.mobile.debug"}
ARCH=${ARCH:="arm64-v8a"}
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:=""}
EMULATOR=${EMULATOR:="$ANDROID_SDK_ROOT/emulator/emulator"}
ADB=${ADB:="$ANDROID_SDK_ROOT/platform-tools/adb"}
# Optional params:
ANDROID_SERIAL=${ANDROID_SERIAL:=""} # Serial number of the device to use to avoid interactive selection

# It's only used if no device is connected and no emulator is defined
# to create a new emulator
AVDMANAGER=${AVDMANAGER:="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager"}
SDKMANAGER=${SDKMANAGER:="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"}


if [ "$ADB" = "" ]; then
    echo "ADB is not set. Please set ADB to the path of your Android SDK."
    exit 1
fi

if [ "$EMULATOR" = "" ]; then
    echo "EMULATOR is not set. Please set EMULATOR to the path of your Android SDK."
    exit 1
fi

create_emulator() {
    # Detect host architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        ABI="arm64-v8a"
    else
        ABI="x86_64"
    fi

    API_LEVEL="30"
    PACKAGE_NAME="system-images;android-${API_LEVEL};google_apis;${ABI}"
    AVD_NAME="status-default-avd"

    $SDKMANAGER --install "$PACKAGE_NAME" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to install system image for API level $API_LEVEL and ABI $ABI."
        exit 1
    fi

    # Create AVD if not exists
    if ! $AVDMANAGER list avd | grep -q "$AVD_NAME"; then
    echo "no" | avdmanager create avd \
        --name "$AVD_NAME" \
        --package "$PACKAGE_NAME" \
        --device "Nexus 10"
    fi
}

select_device_or_emulator() {
    # If no device connected and no emulator AVD exists, create one
    if ! $ADB devices | awk 'NR>1 && /device$/' | grep -q . \
       && ! $EMULATOR -list-avds | grep -q .; then
        echo "No device connected and no AVD found. Creating a new emulator for you."
        create_emulator
    fi

    # 1) Gather connected devices
    device_list=$("$ADB" devices | sed '1d' | awk '/device$/ {print $1}')
    device_count=$(printf '%s\n' "$device_list" | grep -c .)

    # 2) Gather available AVD names
    avd_list=$("$EMULATOR" -list-avds)
    emulator_count=$(printf '%s\n' "$avd_list" | grep -c .)

    # 3) Display lists
    echo "Running devices:"
    if [ "$device_count" -eq 0 ]; then
        echo "  (none)"
    else
        idx=1
        printf '%s\n' "$device_list" | while IFS= read -r dev; do
            echo "  $idx: $dev"
            idx=$((idx+1))
        done
    fi

    echo "Emulators:"
    if [ "$emulator_count" -eq 0 ]; then
        echo "  (none)"
    else
        idx=$((device_count+1))
        printf '%s\n' "$avd_list" | while IFS= read -r avd; do
            echo "  $idx: $avd"
            idx=$((idx+1))
        done
    fi

    total_choices=$(( device_count + emulator_count ))

    # 4) Prompt until valid selection
    while true; do
        read -rp "Select a device or emulator [1–$total_choices]: " sel
        [[ -z $sel ]] && { echo "Please type a number."; continue; }
        [[ ! $sel =~ ^[0-9]+$ ]] && { echo "That’s not a number. Try again."; continue; }
        if [ "$sel" -lt 1 ] || [ "$sel" -gt "$total_choices" ]; then
            echo "Out of range (1–$total_choices)."; continue;
        fi
        break
    done

    # 5) Use the choice
    if [ "$sel" -le "$device_count" ]; then
        ANDROID_SERIAL=$(printf '%s\n' "$device_list" | sed -n "${sel}p")
        echo "Selected device: $ANDROID_SERIAL"
    else
        avd_index=$(( sel - device_count ))
        avd_name=$(printf '%s\n' "$avd_list" | sed -n "${avd_index}p")
        echo "Starting emulator: $avd_name"
        # find free port
        port=5554
        while netstat -an | grep -q ":$port "; do
            port=$((port + 2))
        done
        echo "Using port $port"
        "$EMULATOR" -avd "$avd_name" -port "$port" >/dev/null 2>&1 &
        emulator_pid=$!
        sleep 5
        if ! ps -p $emulator_pid >/dev/null; then
            echo "Failed to start emulator: $avd_name"
            exit 1
        fi
        ANDROID_SERIAL=emulator-$port
        echo "Emulator started. Waiting to boot…"
        "$ADB" wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done;'
    fi
}

# Run on the connected device or emulator
if [ -z "$ANDROID_SERIAL" ]; then
    select_device_or_emulator
fi

echo "Installing app"

# try installing app without removing data folder first
$ADB -s $ANDROID_SERIAL install -r "$APP"
if [ $? -ne 0 ]; then
    echo
    echo "❌ App installation failed"

    echo
    echo "⚠️  NOTE: In some cases installing new app without uninstalling old "
    echo "    one will create a signature mismatch issue and lead to failure in app installation "
    echo "    if you choose to Uninstall the existing app, please note that -"
    echo "    Uninstalling the existing app will wipe its stored data."
    echo "    If you care about keeping your messages and media, please"
    echo "    back up Status folder"
    read -p "Do you want to uninstall the existing app before installing the new one? [y/N] " confirm

    if [[ "$confirm" =~ ^[Yy] ]]; then
        echo
        echo "→ Uninstalling existing app…"
        $ADB -s $ANDROID_SERIAL uninstall $APP_PACKAGE
        if [ $? -ne 0 ]; then
            echo "❌ Uninstall failed (perhaps it wasn’t installed?). Continuing with install…"
        fi
        echo
        echo "→ Installing new app…"
        $ADB -s $ANDROID_SERIAL install -r "$APP"
    else
        echo
        echo "→ Skipping uninstall. Installing new app directly…"
        $ADB -s $ANDROID_SERIAL install -r "$APP"
    fi

    if [ $? -ne 0 ]; then
        echo
        echo "❌ App installation failed."
        exit 1
    else
        echo
        echo "✅ App installed successfully."
    fi
fi

echo "App installed. Starting app"

DEFAULT_ACTIVITY_NAME="${APP_PACKAGE}/app.status.mobile.StatusQtActivity"
$ADB -s $ANDROID_SERIAL shell am start -a android.intent.action.MAIN -n $DEFAULT_ACTIVITY_NAME
# wait for the app to start and then start logcat
echo "Waiting for the app to start"
while true; do
    PID=$($ADB -s $ANDROID_SERIAL shell pidof $APP_PACKAGE | tr -d '\r')
    if [ -n "$PID" ]; then
        echo "App started with PID: $PID"
        break
    fi
    sleep 1
done

echo "Starting logcat with PID filter for $PID"
$ADB -s $ANDROID_SERIAL logcat --pid $PID

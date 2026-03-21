#!/usr/bin/env bash
# Android emulator management from WSL2.
# Uses Windows-side SDK installed at C:\Users\Mikew\android-sdk
#
# Usage:
#   ./scripts/android-emulator.sh start     # Launch the emulator
#   ./scripts/android-emulator.sh stop      # Kill the emulator
#   ./scripts/android-emulator.sh install   # Build & install debug APK
#   ./scripts/android-emulator.sh launch    # Start the app
#   ./scripts/android-emulator.sh screenshot [path]  # Take a screenshot
#   ./scripts/android-emulator.sh tap X Y   # Tap at coordinates
#   ./scripts/android-emulator.sh back      # Press back button
#   ./scripts/android-emulator.sh uidump    # Dump UI hierarchy
#   ./scripts/android-emulator.sh logcat    # Stream app logs
#   ./scripts/android-emulator.sh status    # Check if emulator is running

set -euo pipefail

WIN_SDK="C:\\Users\\Mikew\\android-sdk"
ADB="$WIN_SDK\\platform-tools\\adb.exe"
EMULATOR_BAT="$WIN_SDK\\start-emulator.bat"
PKG="com.danceval.dance_evaluation"
ACTIVITY="$PKG/.MainActivity"

# Export build environment
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk/jdk-21.0.2}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Locate flutter
FLUTTER="${FLUTTER:-$(command -v flutter 2>/dev/null || echo "$HOME/flutter/bin/flutter")}"

adb_cmd() {
    cmd.exe /c "$ADB $*" 2>/dev/null | tr -d '\r'
}

case "${1:-help}" in
    start)
        echo "Starting Android emulator..."
        cmd.exe /c "start $EMULATOR_BAT" 2>/dev/null
        echo "Waiting for emulator to boot..."
        for i in $(seq 1 60); do
            if adb_cmd devices | grep -q "emulator.*device"; then
                echo "Emulator is ready."
                exit 0
            fi
            sleep 2
        done
        echo "ERROR: Emulator did not start within 120 seconds."
        exit 1
        ;;

    stop)
        echo "Stopping emulator..."
        adb_cmd emu kill || true
        echo "Done."
        ;;

    status)
        if adb_cmd devices | grep -q "emulator.*device"; then
            echo "Emulator is running."
        else
            echo "Emulator is not running."
            exit 1
        fi
        ;;

    install)
        echo "Building debug APK..."
        "$FLUTTER" build apk --debug
        echo "Installing on emulator..."
        APK_WIN="\\\\wsl.localhost\\Ubuntu$(realpath build/app/outputs/flutter-apk/app-debug.apk | sed 's|/|\\\\|g')"
        adb_cmd install -r "$APK_WIN"
        echo "Installed."
        ;;

    launch)
        echo "Launching $PKG..."
        adb_cmd shell am start -n "$ACTIVITY"
        ;;

    screenshot)
        DEST="${2:-/tmp/emulator_screenshot.png}"
        adb_cmd shell screencap -p /sdcard/screen.png
        adb_cmd pull /sdcard/screen.png "C:\\Users\\Mikew\\screen.png"
        cp /mnt/c/Users/Mikew/screen.png "$DEST"
        echo "Screenshot saved to $DEST"
        ;;

    tap)
        X="${2:?Usage: $0 tap X Y}"
        Y="${3:?Usage: $0 tap X Y}"
        adb_cmd shell input tap "$X" "$Y"
        ;;

    back)
        adb_cmd shell input keyevent KEYCODE_BACK
        ;;

    uidump)
        adb_cmd shell uiautomator dump /sdcard/ui.xml
        adb_cmd pull /sdcard/ui.xml "C:\\Users\\Mikew\\ui.xml"
        cp /mnt/c/Users/Mikew/ui.xml /tmp/ui.xml
        # Pretty-print clickable elements with their bounds
        grep -oP 'content-desc="[^"]*"[^>]*clickable="true"[^>]*bounds="\[[0-9,\]\[]*\]"' /tmp/ui.xml \
            | sed 's/checkable.*clickable="true"[^b]*//' \
            | sed 's/content-desc="/  /;s/" bounds/  bounds/' \
            || echo "(no clickable elements found)"
        ;;

    logcat)
        PID=$(adb_cmd shell pidof "$PKG" | tr -d '[:space:]')
        if [ -z "$PID" ]; then
            echo "App is not running. Showing all flutter logs..."
            cmd.exe /c "$ADB logcat -s flutter" 2>/dev/null | tr -d '\r'
        else
            echo "Streaming logs for PID $PID..."
            cmd.exe /c "$ADB logcat --pid=$PID" 2>/dev/null | tr -d '\r'
        fi
        ;;

    help|*)
        echo "Usage: $0 {start|stop|status|install|launch|screenshot|tap|back|uidump|logcat}"
        echo ""
        echo "Commands:"
        echo "  start           Launch the Android emulator"
        echo "  stop            Kill the running emulator"
        echo "  status          Check if the emulator is running"
        echo "  install         Build debug APK and install on emulator"
        echo "  launch          Start the Dance Eval app"
        echo "  screenshot [f]  Save screenshot (default: /tmp/emulator_screenshot.png)"
        echo "  tap X Y         Tap at native coordinates (1080x2400)"
        echo "  back            Press the back button"
        echo "  uidump          Dump UI hierarchy and show clickable elements"
        echo "  logcat          Stream app logs"
        ;;
esac

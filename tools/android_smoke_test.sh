#!/usr/bin/env bash
# android_smoke_test.sh — Automated smoke test for Dance Eval on Android emulator.
# Navigates through key screens, takes screenshots, and reports results.
#
# Usage: ./tools/android_smoke_test.sh [ADB_PATH]
#   ADB_PATH defaults to the Windows SDK adb.exe for WSL environments.

set -euo pipefail

# Auto-detect: prefer Windows adb.exe in WSL, fall back to Linux adb
if [[ -z "${1:-}" ]]; then
  if [[ -f "/mnt/c/Users/Mikew/android-sdk/platform-tools/adb.exe" ]]; then
    ADB="/mnt/c/Users/Mikew/android-sdk/platform-tools/adb.exe"
  else
    ADB="adb"
  fi
else
  ADB="$1"
fi
PKG="com.danceval.dance_evaluation"
SCREENSHOT_DIR="test_results/android_smoke_$(date +%Y%m%d_%H%M%S)"
PASS=0
FAIL=0
TESTS=()

mkdir -p "$SCREENSHOT_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "[$(date +%H:%M:%S)] $*"; }

screenshot() {
  local name="$1"
  local path="$SCREENSHOT_DIR/${name}.png"
  $ADB exec-out screencap -p > "$path" 2>/dev/null
  echo "$path"
}

tap() {
  # tap x y — coordinates in 1080x2400 space
  $ADB shell input tap "$1" "$2" 2>/dev/null
}

swipe() {
  $ADB shell input swipe "$1" "$2" "$3" "$4" "${5:-300}" 2>/dev/null
}

press_back() {
  $ADB shell input keyevent KEYCODE_BACK 2>/dev/null
}

wait_for_render() {
  sleep "${1:-2}"
}

launch_app() {
  # Force-stop and cleanly relaunch, waiting for Flutter to render.
  $ADB shell am force-stop "$PKG" 2>/dev/null || true
  sleep 1
  $ADB logcat -c 2>/dev/null || true  # Clear logcat for this test
  $ADB shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 2>/dev/null >/dev/null
  # Flutter apps need time to load — wait for the engine to finish init.
  log "  Waiting for app to render..."
  sleep 5
}

check_screen() {
  # Verify the app is the top resumed activity.
  # NOTE: pipe must be on the host side — Windows adb.exe doesn't support
  # pipes inside shell "..." quotes.
  local top
  top=$($ADB shell dumpsys activity activities 2>/dev/null | tr -d '\r' | grep "topResumedActivity" || true)
  if echo "$top" | grep -q "$PKG"; then
    return 0
  else
    return 1
  fi
}

record_result() {
  local test_name="$1"
  local status="$2"
  local screenshot_file="$3"
  local detail="${4:-}"

  if [[ "$status" == "PASS" ]]; then
    PASS=$((PASS + 1))
    log "  ✓ $test_name"
  else
    FAIL=$((FAIL + 1))
    log "  ✗ $test_name — $detail"
  fi
  TESTS+=("$status|$test_name|$screenshot_file|$detail")
}

# ---------------------------------------------------------------------------
# Button coordinates (1080x2400 screen)
# Measured from actual home screen screenshot:
#   "Start Dancing"     — center ~(540, 710)
#   "Upload Video"      — center ~(540, 850)
#   "History"           — center ~(540, 970)
#   "Manage References" — center ~(540, 1080)
# ---------------------------------------------------------------------------

BTN_START_DANCING_Y=710
BTN_UPLOAD_VIDEO_Y=850
BTN_HISTORY_Y=970
BTN_MANAGE_REFS_Y=1080
BTN_CENTER_X=540

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

log "=== Dance Eval Android Smoke Test ==="
log "Screenshots: $SCREENSHOT_DIR"
echo ""

# Verify emulator is connected
DEVICES=$($ADB devices 2>&1 | tr -d '\r' | grep -c "device$" || true)
if [[ "$DEVICES" -eq 0 ]]; then
  log "ERROR: No device/emulator connected."
  exit 1
fi
log "Device connected."

# Push test video for later upload test
$ADB push assets/test_videos/dance_test.mp4 /sdcard/Download/dance_test.mp4 2>/dev/null || true

# ---------------------------------------------------------------------------
# Test 1: Home screen renders
# ---------------------------------------------------------------------------

log "Test 1: Home screen"
launch_app
SHOT=$(screenshot "01_home_screen")
if check_screen; then
  record_result "Home screen renders" "PASS" "$SHOT"
else
  record_result "Home screen renders" "FAIL" "$SHOT" "App not in foreground"
fi

# ---------------------------------------------------------------------------
# Test 2: History screen (empty state)
# ---------------------------------------------------------------------------

log "Test 2: History screen"
tap $BTN_CENTER_X $BTN_HISTORY_Y
wait_for_render 2
SHOT=$(screenshot "02_history")
if check_screen; then
  record_result "History screen opens" "PASS" "$SHOT"
else
  record_result "History screen opens" "FAIL" "$SHOT" "App not in foreground"
fi

# ---------------------------------------------------------------------------
# Test 3: Reference list screen
# ---------------------------------------------------------------------------

log "Test 3: Reference list screen"
launch_app
tap $BTN_CENTER_X $BTN_MANAGE_REFS_Y
wait_for_render 2
SHOT=$(screenshot "03_references")
if check_screen; then
  record_result "References screen opens" "PASS" "$SHOT"
else
  record_result "References screen opens" "FAIL" "$SHOT" "App not in foreground"
fi

# ---------------------------------------------------------------------------
# Test 4: Start Dancing → reference selection → capture
# ---------------------------------------------------------------------------

log "Test 4: Start Dancing flow"
launch_app
tap $BTN_CENTER_X $BTN_START_DANCING_Y
wait_for_render 3
SHOT=$(screenshot "04_start_dancing")
if check_screen; then
  record_result "Start Dancing flow opens" "PASS" "$SHOT"
else
  record_result "Start Dancing flow opens" "FAIL" "$SHOT" "App not in foreground"
fi

# If on a reference list, tap the first reference item (~y=300 in the list body)
tap $BTN_CENTER_X 400
wait_for_render 3
SHOT=$(screenshot "04b_capture_screen")
if check_screen; then
  record_result "Capture screen renders" "PASS" "$SHOT"
else
  record_result "Capture screen renders" "FAIL" "$SHOT" "App not in foreground"
fi

# ---------------------------------------------------------------------------
# Test 5: Upload Video flow
# ---------------------------------------------------------------------------

log "Test 5: Upload Video flow"
launch_app
tap $BTN_CENTER_X $BTN_UPLOAD_VIDEO_Y
wait_for_render 3
SHOT=$(screenshot "05_upload_flow")
if check_screen; then
  record_result "Upload Video flow opens" "PASS" "$SHOT"
else
  record_result "Upload Video flow opens" "FAIL" "$SHOT" "App not in foreground"
fi

# ---------------------------------------------------------------------------
# Test 6: Orientation change survival
# ---------------------------------------------------------------------------

log "Test 6: Orientation change"
launch_app

# Rotate to landscape
$ADB shell settings put system accelerometer_rotation 0 2>/dev/null
$ADB shell settings put system user_rotation 1 2>/dev/null
wait_for_render 3
SHOT=$(screenshot "06_landscape")
if check_screen; then
  record_result "Survives rotation to landscape" "PASS" "$SHOT"
else
  record_result "Survives rotation to landscape" "FAIL" "$SHOT" "App crashed on rotation"
fi

# Rotate back to portrait
$ADB shell settings put system user_rotation 0 2>/dev/null
wait_for_render 2
SHOT=$(screenshot "06b_portrait_again")
if check_screen; then
  record_result "Survives rotation back to portrait" "PASS" "$SHOT"
else
  record_result "Survives rotation back to portrait" "FAIL" "$SHOT" "App crashed on rotation back"
fi

# Restore auto-rotation
$ADB shell settings put system accelerometer_rotation 1 2>/dev/null

# ---------------------------------------------------------------------------
# Test 7: App survives process kill and cold restart
# ---------------------------------------------------------------------------

log "Test 7: Process kill and cold restart"
launch_app
SHOT=$(screenshot "07_cold_restart")
if check_screen; then
  record_result "Cold restart works" "PASS" "$SHOT"
else
  record_result "Cold restart works" "FAIL" "$SHOT" "App failed to restart"
fi

# ---------------------------------------------------------------------------
# Test 8: Rapid navigation stress test
# ---------------------------------------------------------------------------

log "Test 8: Rapid navigation"
# Quickly tap through buttons. Back-pressing past root exits the app (expected),
# so we just verify the app can still launch afterward (no crash/corruption).
tap $BTN_CENTER_X $BTN_HISTORY_Y
sleep 0.5
press_back
sleep 0.5
tap $BTN_CENTER_X $BTN_MANAGE_REFS_Y
sleep 0.5
press_back
sleep 0.5
tap $BTN_CENTER_X $BTN_START_DANCING_Y
sleep 0.5
press_back
sleep 0.5
press_back
sleep 1
# App may have exited — relaunch and verify it still works.
$ADB shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 2>/dev/null >/dev/null
wait_for_render 4
SHOT=$(screenshot "08_after_rapid_nav")
if check_screen; then
  record_result "Survives rapid navigation" "PASS" "$SHOT"
else
  record_result "Survives rapid navigation" "FAIL" "$SHOT" "App failed to relaunch after rapid nav"
fi

# ---------------------------------------------------------------------------
# Test 9: Check logcat for crashes/exceptions
# ---------------------------------------------------------------------------

log "Test 9: Check logcat for crashes"
CRASHES=$($ADB logcat -d -s AndroidRuntime 2>/dev/null | tr -d '\r' | grep -c "FATAL EXCEPTION" || true)
FLUTTER_ERRORS=$($ADB logcat -d 2>/dev/null | tr -d '\r' | grep -c "══╡ EXCEPTION" || true)

if [[ "$CRASHES" -eq 0 && "$FLUTTER_ERRORS" -eq 0 ]]; then
  record_result "No crashes in logcat" "PASS" "-"
else
  # Dump crash logs for review
  $ADB logcat -d -s AndroidRuntime > "$SCREENSHOT_DIR/crash_log.txt" 2>/dev/null || true
  $ADB logcat -d | tr -d '\r' | grep -B2 -A10 "══╡ EXCEPTION\|FATAL EXCEPTION" > "$SCREENSHOT_DIR/flutter_errors.txt" 2>/dev/null || true
  record_result "No crashes in logcat" "FAIL" "$SCREENSHOT_DIR/crash_log.txt" "$CRASHES native + $FLUTTER_ERRORS flutter errors"
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

echo ""
log "==========================================="
log "  RESULTS"
log "==========================================="
TOTAL=$((PASS + FAIL))
log "  $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  log "  FAILURES:"
  for t in "${TESTS[@]}"; do
    IFS='|' read -r status name file detail <<< "$t"
    if [[ "$status" == "FAIL" ]]; then
      log "    ✗ $name: $detail"
      [[ "$file" != "-" ]] && log "      see: $file"
    fi
  done
fi

echo ""
log "Screenshots saved to: $SCREENSHOT_DIR/"
ls -1 "$SCREENSHOT_DIR/"

# Exit with failure if any test failed
[[ "$FAIL" -eq 0 ]]

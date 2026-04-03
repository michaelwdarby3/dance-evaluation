#!/bin/bash
# Run all web integration tests sequentially.
# Each test file gets its own chromedriver instance to avoid hangs.
# flutter drive for web may not exit cleanly after tests pass,
# so we use `timeout` and check output for "All tests passed".

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CHROMEDRIVER="$(PATH="$HOME/bin:$PATH" which chromedriver 2>/dev/null || echo chromedriver)"
CHROME="$(PATH="$HOME/bin:$PATH" which google-chrome-nosandbox 2>/dev/null || echo google-chrome)"
TIMEOUT="${INTEGRATION_TIMEOUT:-180}"

# Flutter's chromeLauncher looks up CHROME_EXECUTABLE to find the browser binary.
# Without this, it uses 'google-chrome' directly (missing our SwiftShader/WebGL flags).
export CHROME_EXECUTABLE="$CHROME"
MAX_RETRIES="${INTEGRATION_RETRIES:-3}"
LOGFILE="/tmp/flutter_drive_output.log"

# Accept a single test file as argument, or run all
if [ -n "$1" ]; then
  TEST_FILES=("$1")
else
  TEST_FILES=(integration_test/*_test.dart)
fi

cleanup_chrome() {
  pkill -9 -f chromedriver 2>/dev/null || true
  pkill -9 -f "chrome --user-data-dir" 2>/dev/null || true
  pkill -9 -f "chrome_crashpad" 2>/dev/null || true
  rm -rf /tmp/flutter_tools.* /tmp/.org.chromium.* /tmp/.com.google.Chrome.* 2>/dev/null || true
  # Wait for port 4444 to be free
  for i in $(seq 1 15); do
    if ! ss -tlnp 2>/dev/null | grep -q ":4444 "; then break; fi
    sleep 1
  done
}

PASS=0
FAIL=0
FAILED_FILES=()

# Clean slate
cleanup_chrome
sleep 1

for f in "${TEST_FILES[@]}"; do
  echo "=========================================="
  echo "RUNNING: $f"
  echo "=========================================="

  TEST_PASSED=false
  for attempt in $(seq 1 "$MAX_RETRIES"); do
    if [ "$attempt" -gt 1 ]; then
      echo "  Retry $attempt/$MAX_RETRIES for $f ..."
      cleanup_chrome
      sleep 2
    fi

    # Start chromedriver and wait until it's ready
    "$CHROMEDRIVER" --port=4444 &>/dev/null &
    CDPID=$!
    for i in $(seq 1 10); do
      if ss -tlnp 2>/dev/null | grep -q ":4444 "; then break; fi
      sleep 1
    done
    sleep 1

    # Run flutter drive with timeout, capture output
    timeout "$TIMEOUT" flutter drive \
      --driver=test_driver/integration_test.dart \
      --target="$f" \
      -d chrome \
      --chrome-binary="$CHROME" 2>&1 | tee "$LOGFILE"
    STATUS=${PIPESTATUS[0]}

    # Thorough cleanup between tests
    kill -9 "$CDPID" 2>/dev/null || true
    cleanup_chrome
    sleep 1

    # exit 0 = clean pass, exit 124 = timeout (check if tests actually passed)
    if [ "$STATUS" -eq 0 ] || { [ "$STATUS" -eq 124 ] && grep -q "All tests passed" "$LOGFILE"; }; then
      TEST_PASSED=true
      break
    fi

    # If AppConnectionException, retry; otherwise fail immediately
    if ! grep -q "AppConnectionException" "$LOGFILE"; then
      break
    fi
  done

  if [ "$TEST_PASSED" = true ]; then
    PASS=$((PASS + 1))
    echo "PASSED: $f"
  else
    FAIL=$((FAIL + 1))
    FAILED_FILES+=("$f")
    echo "FAILED: $f (exit code: $STATUS)"
  fi
done

echo ""
echo "=========================================="
echo "RESULTS: $PASS passed, $FAIL failed out of $((PASS + FAIL)) test files"
if [ ${#FAILED_FILES[@]} -gt 0 ]; then
  echo "FAILED:"
  for ff in "${FAILED_FILES[@]}"; do
    echo "  - $ff"
  done
fi
echo "=========================================="

[ "$FAIL" -eq 0 ]

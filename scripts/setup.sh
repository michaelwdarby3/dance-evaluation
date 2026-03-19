#!/usr/bin/env bash
set -euo pipefail

# Dance Evaluation — Local Development Setup
# Run: ./scripts/setup.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[setup]${NC} $1"; }
ok()    { echo -e "${GREEN}[  ok ]${NC} $1"; }
fail()  { echo -e "${RED}[fail]${NC} $1"; exit 1; }

# ---- Check prerequisites ----

info "Checking prerequisites..."

command -v flutter >/dev/null 2>&1 || fail "flutter not found. Install from https://flutter.dev/docs/get-started/install"
command -v python3 >/dev/null 2>&1 || fail "python3 not found."
command -v dart    >/dev/null 2>&1 || fail "dart not found (should come with Flutter)."

FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
ok "Flutter: $FLUTTER_VERSION"

PYTHON_VERSION=$(python3 --version)
ok "Python: $PYTHON_VERSION"

# ---- Flutter dependencies ----

info "Installing Flutter dependencies..."
flutter pub get
ok "Flutter packages installed"

# ---- Server setup ----

info "Setting up Python server environment..."
if [ ! -d server/.venv ]; then
    python3 -m venv server/.venv
fi
(
    source server/.venv/bin/activate
    pip install --quiet -r server/requirements.txt
    pip install --quiet -r server/requirements-dev.txt
)
ok "Server dependencies installed"

# ---- Tools setup ----

info "Setting up Python tools environment..."
if [ ! -d tools/.venv ]; then
    python3 -m venv tools/.venv
fi
(
    source tools/.venv/bin/activate
    pip install --quiet mediapipe opencv-python-headless numpy
)
ok "Tools dependencies installed"

# ---- Verify ----

info "Running Flutter analyze..."
flutter analyze --no-fatal-infos || true

info "Running tests..."
flutter test --reporter compact
ok "All tests passed"

echo ""
echo -e "${GREEN}Setup complete!${NC} Quick reference:"
echo ""
echo "  make run-web          Run the app in Chrome"
echo "  make run-server       Start the backend (port 8000)"
echo "  make test             Run all tests"
echo "  make test-integration Run browser integration tests"
echo "  make build-web        Build for production"
echo ""

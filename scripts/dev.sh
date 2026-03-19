#!/usr/bin/env bash
set -euo pipefail

# Dance Evaluation — Start Development Environment
# Runs the Flutter web app and backend server in parallel.
# Run: ./scripts/dev.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

cleanup() {
    echo ""
    echo -e "${CYAN}Shutting down...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    kill $FLUTTER_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start backend server
echo -e "${CYAN}Starting backend server on :8000...${NC}"
(
    cd server
    source .venv/bin/activate
    uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload
) &
SERVER_PID=$!

# Wait for server to be ready
sleep 2
if kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${GREEN}Server running${NC} at http://localhost:8000"
else
    echo -e "${RED}Server failed to start${NC}"
    exit 1
fi

# Start Flutter web app
echo -e "${CYAN}Starting Flutter web app...${NC}"
flutter run -d chrome &
FLUTTER_PID=$!

echo ""
echo -e "${GREEN}Development environment running:${NC}"
echo "  App:    http://localhost:8080 (Flutter web)"
echo "  API:    http://localhost:8000"
echo "  Docs:   http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop."

wait

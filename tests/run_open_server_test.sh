#!/usr/bin/env bash
# Open-server test: the real dedicated server started as `--server --open` with NO secret, and two guest
# clients that find it through LAN discovery. One creates a room, the other joins it by room code alone.
# Usage: tests/run_open_server_test.sh [godot-binary]   (default: godot)
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
LOG="$(mktemp -d)"
unset OXENWAR_SERVER_SECRET OXENWAR_TRANSPORT OXENWAR_OPEN_MODE

"$GODOT" --headless --path . -- --server --open > "$LOG/server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }
trap cleanup EXIT

for _ in $(seq 1 60); do
  grep -q "LAN discovery listening" "$LOG/server.log" && break
  sleep 0.5
done
if ! grep -q "LAN discovery listening" "$LOG/server.log"; then
  echo "Open server did not start:"; cat "$LOG/server.log"; exit 1
fi

CODE_FILE="$LOG/room.txt"
"$GODOT" --headless --path . --script tests/online/open_client.gd -- --role=B --file="$CODE_FILE" > "$LOG/b.log" 2>&1 &
B_PID=$!
"$GODOT" --headless --path . --script tests/online/open_client.gd -- --role=A --file="$CODE_FILE" > "$LOG/a.log" 2>&1 &
A_PID=$!
wait "$A_PID"; A_CODE=$?
wait "$B_PID"; B_CODE=$?

grep -hE "OPEN_(NOTE|FAIL|RESULT)" "$LOG/a.log" "$LOG/b.log"
if grep -q "SCRIPT ERROR" "$LOG/server.log" "$LOG/a.log" "$LOG/b.log"; then
  echo "A script error was reported:"; grep -h "SCRIPT ERROR" -A2 "$LOG/server.log" "$LOG/a.log" "$LOG/b.log" | head -20
  exit 1
fi
if [ "$A_CODE" -ne 0 ] || [ "$B_CODE" -ne 0 ]; then
  echo "OPEN SERVER TEST FAILED (A=$A_CODE B=$B_CODE). Server log:"; tail -30 "$LOG/server.log"; exit 1
fi
echo "OPEN SERVER TEST PASSED"

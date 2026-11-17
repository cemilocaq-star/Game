#!/usr/bin/env bash
# Online test: one dedicated server and two clients, real UDP sockets on localhost, the real network
# script (only ticket redemption and the Supabase save are replaced, see tests/online/).
# Usage: tests/run_online_test.sh [godot-binary]   (default: godot)
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
LOG="$(mktemp -d)"
export OXENWAR_SERVER_SECRET="online-test-only-not-production"
unset OXENWAR_TRANSPORT

"$GODOT" --headless --path . --script tests/online/online_server.gd > "$LOG/server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; }
trap cleanup EXIT

for _ in $(seq 1 50); do
  grep -q "ONLINE_SERVER_READY" "$LOG/server.log" && break
  sleep 0.2
done
if ! grep -q "ONLINE_SERVER_READY" "$LOG/server.log"; then
  echo "Server did not start:"; cat "$LOG/server.log"; exit 1
fi

# B (target) first so it is waiting in the room when A (shooter) arrives.
"$GODOT" --headless --path . --script tests/online/online_client.gd -- --role=B > "$LOG/b.log" 2>&1 &
B_PID=$!
sleep 1
"$GODOT" --headless --path . --script tests/online/online_client.gd -- --role=A > "$LOG/a.log" 2>&1 &
A_PID=$!
wait "$A_PID"; A_CODE=$?
wait "$B_PID"; B_CODE=$?

grep -hE "ONLINE_(NOTE|FAIL|RESULT)" "$LOG/a.log" "$LOG/b.log"
if grep -q "SCRIPT ERROR" "$LOG/server.log" "$LOG/a.log" "$LOG/b.log"; then
  echo "A script error was reported:"; grep -h "SCRIPT ERROR" -A2 "$LOG/server.log" "$LOG/a.log" "$LOG/b.log" | head -20
  exit 1
fi
if [ "$A_CODE" -ne 0 ] || [ "$B_CODE" -ne 0 ]; then
  echo "ONLINE TEST FAILED (A=$A_CODE B=$B_CODE). Logs in $LOG"; exit 1
fi
echo "ONLINE TEST PASSED"

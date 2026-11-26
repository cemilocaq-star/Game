#!/usr/bin/env bash
set -eu
GODOT=$(realpath "$1")
OUT=$(realpath -m "$2")
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
export OXENWAR_SERVER_SECRET=reconnect-fixture-only
unset OXENWAR_TRANSPORT
"$GODOT" --headless --path . --script tests/online/online_server.gd > "$OUT/server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true' EXIT
for i in $(seq 1 60); do
 if rg -q ONLINE_SERVER_READY "$OUT/server.log"; then break; fi
 sleep .1
done
timeout 35 "$GODOT" --headless --path . --script tests/online/reconnect_client.gd > "$OUT/client.log" 2>&1
cat "$OUT/client.log"
if rg -q 'SCRIPT ERROR|ONLINE_FAIL' "$OUT/client.log" "$OUT/server.log"; then exit 1; fi

#!/bin/sh
# Release: end the vigil for the agent session that spawned this hook
# Inlined to avoid DLL locking with the running vigil start process
VIGIL_DIR="${TMPDIR:-/tmp}/vigil"
PID_FILE="$VIGIL_DIR/$PPID.pid"

if [ -f "$PID_FILE" ]; then
    VIGIL_PID=$(cat "$PID_FILE")
    kill "$VIGIL_PID" 2>/dev/null
    rm -f "$PID_FILE"
fi

#!/bin/sh
# Release: end the vigil for the agent session that spawned this hook
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname)" in
    Darwin)
        VIGIL_DIR="${TMPDIR:-/tmp}/vigil"
        PID_FILE="$VIGIL_DIR/$PPID.pid"
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null
            rm -f "$PID_FILE"
        fi
        ;;
    *)
        dotnet run "$SCRIPT_DIR/vigil.cs" -- end "$PPID" > /dev/null 2>&1
        ;;
esac
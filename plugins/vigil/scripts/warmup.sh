#!/bin/sh
# Warmup: pre-build vigil.cs so subsequent dotnet run calls skip compilation
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname)" in
    Darwin)
        # macOS uses caffeinate, no build needed
        ;;
    *)
        dotnet build "$SCRIPT_DIR/vigil.cs" > /dev/null 2>&1
        ;;
esac

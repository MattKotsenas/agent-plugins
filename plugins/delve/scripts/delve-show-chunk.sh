#!/usr/bin/env bash
# Display a diff chunk in a terminal split pane. If no supported terminal
# multiplexer is detected, exits with code 1 so the caller can fall back
# to inline rendering.
#
# Usage: delve-show-chunk.sh --diff-file <path> --state-dir <path>
#
# Exit 0 = pane displayed successfully.
# Exit 1 = no supported terminal; caller should render inline.

set -euo pipefail

diff_file=""
state_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diff-file) diff_file="$2"; shift 2 ;;
        --state-dir) state_dir="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$diff_file" || -z "$state_dir" ]]; then
    echo "Usage: delve-show-chunk.sh --diff-file <path> --state-dir <path>" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
signal_file="$state_dir/pane.close"
pid_file="$state_dir/pane.pid"

# --- Detect terminal multiplexer ---
multiplexer=""
if [[ -n "${TMUX:-}" ]]; then
    multiplexer="tmux"
elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    multiplexer="iterm2"
else
    exit 1  # No supported multiplexer — fall back to inline
fi

# --- Close any existing pane ---
if [[ -f "$pid_file" ]]; then
    echo "close" > "$signal_file"
    old_pid=$(cat "$pid_file" 2>/dev/null || echo "")
    if [[ -n "$old_pid" ]]; then
        for _ in $(seq 1 20); do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -f "$pid_file" "$signal_file"
fi

# --- Open the split pane ---
pane_script="$script_dir/delve-pane.sh"

case "$multiplexer" in
    tmux)
        tmux split-window -h -l '50%' \
            bash "$pane_script" --diff-file "$diff_file" --state-dir "$state_dir"
        ;;
    iterm2)
        # AppleScript to split pane in iTerm2
        osascript -e "
            tell application \"iTerm2\"
                tell current session of current tab of current window
                    set newSession to (split vertically with default profile)
                    tell newSession
                        write text \"bash '$pane_script' --diff-file '$diff_file' --state-dir '$state_dir'\"
                    end tell
                end tell
            end tell
        " 2>/dev/null || exit 1
        ;;
esac

exit 0

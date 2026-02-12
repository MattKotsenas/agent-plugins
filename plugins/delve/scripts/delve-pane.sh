#!/usr/bin/env bash
# Runs inside a terminal split pane to display a diff file.
# Called by delve-show-chunk.sh — not intended to be called directly.
#
# Usage: delve-pane.sh --diff-file <path> --state-dir <path>

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
    echo "Usage: delve-pane.sh --diff-file <path> --state-dir <path>" >&2
    exit 1
fi

pid_file="$state_dir/pane.pid"
signal_file="$state_dir/pane.close"

echo $$ > "$pid_file"
rm -f "$signal_file"

# Detect the user's git pager
pager=$(git config core.pager 2>/dev/null || echo "")
if [[ -z "$pager" ]]; then
    pager="${PAGER:-}"
fi

# Extract the base command (first word) for existence check
pager_cmd="${pager%% *}"

if [[ -n "$pager_cmd" ]] && command -v "$pager_cmd" &>/dev/null; then
    # Try with --paging=never first (works with delta, bat)
    $pager_cmd --paging=never < "$diff_file" 2>/dev/null || \
        $pager_cmd < "$diff_file" 2>/dev/null || \
        cat "$diff_file"
else
    cat "$diff_file"
fi

printf '\n\033[90mPress Q to close this pane...\033[0m\n'

# Poll for close signal or Q keypress
while true; do
    if [[ -f "$signal_file" ]]; then
        rm -f "$signal_file"
        break
    fi
    # Read with timeout — non-blocking single char
    if read -t 0.1 -n 1 key 2>/dev/null; then
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    fi
done

rm -f "$pid_file"
exit 0

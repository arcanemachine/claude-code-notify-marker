#!/bin/bash

# notify-marker.sh
# Pause/resume marker creation for the CURRENT Claude Code session.
#
# Backed by a .paused-sessions file (one session id per line) in the marker
# directory. Invoked by the /claude-code-notify-marker:pause and :resume slash
# commands. Idempotent: pausing an already-paused session (or resuming one that
# isn't paused) is a harmless no-op.
#
# Usage: notify-marker.sh {pause|resume|status}

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

action="$1"

dir="$(notify_marker_dir)" || {
    echo "notify-marker: disabled — CC_NOTIFY_MARKER_DIR is not set, nothing to pause."
    exit 1
}

sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$sid" ] || {
    echo "notify-marker: CLAUDE_CODE_SESSION_ID is not set; cannot identify this session."
    exit 1
}

mkdir -p "$dir" 2>/dev/null
state="$dir/.paused-sessions"

is_paused() { grep -qxF "$sid" "$state" 2>/dev/null; }

case "$action" in
    pause)
        if is_paused; then
            echo "notify-marker: already paused for this session ($sid)."
        else
            echo "$sid" >> "$state"
            echo "notify-marker: paused for this session ($sid)."
        fi
        ;;
    resume)
        if is_paused; then
            # Note: grep -v exits non-zero when the result is empty (last entry
            # removed), so do not gate the mv on its exit status.
            grep -vxF "$sid" "$state" > "$state.tmp" 2>/dev/null
            mv "$state.tmp" "$state"
            echo "notify-marker: resumed for this session ($sid)."
        else
            echo "notify-marker: not paused for this session ($sid)."
        fi
        ;;
    status)
        if is_paused; then echo "paused"; else echo "active"; fi
        ;;
    *)
        echo "usage: notify-marker.sh {pause|resume|status}"
        exit 2
        ;;
esac

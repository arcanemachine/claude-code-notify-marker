#!/bin/bash

# notify-marker.sh
# Pause/resume marker creation for the CURRENT Claude Code session.
#
# Backed by two list files in the marker directory (one session id per line):
#   .paused-sessions  - sessions explicitly paused
#   .active-sessions  - sessions explicitly resumed
# An explicit entry always wins over the default. The default is controlled by
# CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT (truthy = paused-by-default, so a session
# stays silent until it explicitly resumes).
#
# Invoked by the /notify-marker:pause and :unpause slash commands.
# Idempotent: repeating pause/unpause for a session is a harmless no-op.
#
# Usage: notify-marker.sh {pause|unpause|status}

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

action="$1"

dir="$(notify_marker_dir)" || {
    echo "notify-marker: disabled — CC_NOTIFY_MARKER_DIR is not set, nothing to do."
    exit 1
}

sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$sid" ] || {
    echo "notify-marker: CLAUDE_CODE_SESSION_ID is not set; cannot identify this session."
    exit 1
}

mkdir -p "$dir" 2>/dev/null
paused="$dir/.paused-sessions"
active="$dir/.active-sessions"

case "$action" in
    pause)
        notify_marker_list_remove "$active" "$sid"
        notify_marker_list_add "$paused" "$sid"
        echo "notify-marker: paused for this session ($sid)."
        ;;
    unpause)
        notify_marker_list_remove "$paused" "$sid"
        notify_marker_list_add "$active" "$sid"
        echo "notify-marker: unpaused for this session ($sid)."
        ;;
    status)
        if notify_marker_listed "$paused" "$sid"; then
            echo "paused"
        elif notify_marker_listed "$active" "$sid"; then
            echo "active"
        elif notify_marker_truthy "${CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT:-}"; then
            echo "paused (default)"
        else
            echo "active (default)"
        fi
        ;;
    *)
        echo "usage: notify-marker.sh {pause|unpause|status}"
        exit 2
        ;;
esac

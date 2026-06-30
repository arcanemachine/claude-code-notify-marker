#!/bin/bash

# notify-marker.sh
# Pause/unpause marker creation for the CURRENT Claude Code session.
#
# Backed by two list files in the marker directory (one session id per line):
#   .paused-sessions  - sessions explicitly paused
#   .active-sessions  - sessions explicitly unpaused
# An explicit entry always wins over the default. The default is controlled by
# CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT (truthy = paused-by-default, so a session
# stays silent until it explicitly unpauses).
#
# Invoked by the /notify-marker:pause and :unpause slash commands.
# Idempotent and quiet: it records intent when possible and prints a single
# terse line. If the plugin is disabled (no marker dir) it just no-ops silently
# rather than printing errors.
#
# Usage: notify-marker.sh {pause|unpause|status}

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

action="$1"
sid="${CLAUDE_CODE_SESSION_ID:-}"
dir="$(notify_marker_dir)" || dir=""

# Record the explicit per-session override when we have somewhere to record it.
if [ -n "$dir" ] && [ -n "$sid" ]; then
    mkdir -p "$dir" 2>/dev/null
    paused="$dir/.paused-sessions"
    active="$dir/.active-sessions"
    case "$action" in
        pause)
            notify_marker_list_remove "$active" "$sid"
            notify_marker_list_add "$paused" "$sid"
            ;;
        unpause)
            notify_marker_list_remove "$paused" "$sid"
            notify_marker_list_add "$active" "$sid"
            ;;
    esac
fi

case "$action" in
    pause) echo "notify-marker: paused" ;;
    unpause) echo "notify-marker: unpaused" ;;
    status)
        if [ -n "$dir" ] && notify_marker_listed "$dir/.paused-sessions" "$sid"; then
            echo "paused"
        elif [ -n "$dir" ] && notify_marker_listed "$dir/.active-sessions" "$sid"; then
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

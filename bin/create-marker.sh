#!/bin/bash

# create-marker.sh
# Invoked by Claude Code hooks (see hooks/hooks.json) to write a marker file
# named after the event. An external watcher (watch-and-notify.sh) turns these
# into desktop notifications.
#
# Usage: create-marker.sh <MARKER_NAME>
#
# Opt-in:      does nothing unless CC_NOTIFY_MARKER_DIR points at a directory.
# Per-session: does nothing if this session id is listed in .paused-sessions.
# Best-effort: always exits 0 so a hook never blocks Claude.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

marker_name="$1"
[ -n "$marker_name" ] || exit 0

# Disabled or not configured -> do nothing.
dir="$(notify_marker_dir)" || exit 0

sid="${CLAUDE_CODE_SESSION_ID:-}"

# Explicit per-session pause always wins.
if [ -n "$sid" ] && notify_marker_listed "$dir/.paused-sessions" "$sid"; then
    exit 0
fi

# Paused-by-default: emit only for sessions that have explicitly resumed.
if notify_marker_truthy "${CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT:-}" &&
    ! { [ -n "$sid" ] && notify_marker_listed "$dir/.active-sessions" "$sid"; }; then
    exit 0
fi

# Write the session label (its name, else its id) as the marker's contents, so
# the watcher can show which session fired. Plain text - no parsing needed.
label="$(notify_marker_session_name)"
label="${label:-$sid}"

# Unique filename per event so concurrent sessions don't clobber each other's
# markers before the watcher consumes them. The event name is the part before
# the first dot; the watcher strips the suffix for display.
suffix="$$.$(date +%s%N 2>/dev/null || echo "$RANDOM")"
mkdir -p "$dir" 2>/dev/null &&
    printf '%s' "$label" > "$dir/${marker_name}.${suffix}" 2>/dev/null

# Always succeed - markers are best-effort and must never block Claude.
exit 0

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

# Per-session mute: skip if this session is paused.
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] &&
    grep -qxF "$CLAUDE_CODE_SESSION_ID" "$dir/.paused-sessions" 2>/dev/null; then
    exit 0
fi

mkdir -p "$dir" 2>/dev/null &&
    printf '{"created":"%s"}' "$(date --iso-8601=seconds)" \
        > "$dir/$marker_name" 2>/dev/null

# Always succeed - markers are best-effort and must never block Claude.
exit 0

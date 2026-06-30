#!/bin/bash

# create-marker.sh
# Invoked by Claude Code hooks (see hooks/hooks.json) to write a marker file
# named after the event. An external watcher (watch-and-notify.sh) turns these
# into desktop notifications.
#
# Usage: create-marker.sh <MARKER_NAME>
#
# Markers are best-effort: this script always exits 0 so a hook never blocks Claude.

# Customize marker directory with the CC_NOTIFY_MARKER_DIR environment variable
CC_NOTIFY_MARKER_DIR="${CC_NOTIFY_MARKER_DIR:-/tmp/cc-notify-marker-files}"

marker_name="$1"

if [ -n "$marker_name" ]; then
    mkdir -p "$CC_NOTIFY_MARKER_DIR" 2>/dev/null &&
        printf '{"created":"%s"}' "$(date --iso-8601=seconds)" \
            > "$CC_NOTIFY_MARKER_DIR/$marker_name" 2>/dev/null
fi

# Always succeed - markers are best-effort and must never block Claude.
exit 0

#!/bin/bash

# Customize marker directory with CC_NOTIFY_MARKER_WATCH_DIR environment variable
CC_NOTIFY_MARKER_WATCH_DIR="${CC_NOTIFY_MARKER_WATCH_DIR:-/tmp/cc-notify-marker-files}"

# Ensure directory exists
mkdir -p "$CC_NOTIFY_MARKER_WATCH_DIR"

# Remove existing marker files on startup
remove_existing_markers() {
    shopt -s nullglob
    local count=0
    for file in "$CC_NOTIFY_MARKER_WATCH_DIR"/*; do
        if [ -f "$file" ]; then
            count=$((count + 1))
            rm "$file"
        fi
    done
    shopt -u nullglob
    if [ $count -gt 0 ]; then
        echo "Removed $count existing marker file(s) on startup."
    fi
}

# Read the session label written into a marker file (its name, else its id).
marker_session() {
    local s
    s=$(cat "$1" 2>/dev/null)
    printf '%s' "${s:-unknown}"
}

# Remove existing markers on startup
echo "Watching marker directory: $CC_NOTIFY_MARKER_WATCH_DIR"
remove_existing_markers

# Check if inotifywait is available
if command -v inotifywait &> /dev/null; then
    echo "Using inotifywait to watch files."
    # close_write (not create) so the marker's contents are fully written
    # before we read the session label out of it.
    inotifywait -m -e close_write --format '%f' "$CC_NOTIFY_MARKER_WATCH_DIR" | while read -r file; do
        filename=$(basename "$file")
        # Ignore dotfiles (e.g. .paused-sessions state) - not marker events.
        case "$filename" in .*) continue ;; esac
        session=$(marker_session "$CC_NOTIFY_MARKER_WATCH_DIR/$file")
        notify-send -t 15000 "Claude Code event handler" "\nSession: $session\n\nEvent: $filename\n\nTimestamp: $(date --iso-8601=seconds)"
        rm "$CC_NOTIFY_MARKER_WATCH_DIR/$file"
    done
else
    echo "inotifywait not found, using polling fallback..."
    while true; do
        shopt -s nullglob
        for file in "$CC_NOTIFY_MARKER_WATCH_DIR"/*; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                session=$(marker_session "$file")
                notify-send -t 15000 "Claude Code event handler" "\nSession: $session\n\nEvent: $filename\n\nTimestamp: $(date --iso-8601=seconds)"
                rm "$file"
            fi
        done
        shopt -u nullglob
        sleep 2
    done
fi

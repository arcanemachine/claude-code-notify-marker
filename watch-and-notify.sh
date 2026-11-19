#!/bin/bash

# Customize marker directory with CC_NOTIFY_MARKER_WATCH_DIR environment variable
CC_NOTIFY_MARKER_WATCH_DIR="${CC_NOTIFY_MARKER_WATCH_DIR:-/tmp/cc-notify-marker-files}"

# Ensure directory exists
mkdir -p "$CC_NOTIFY_MARKER_WATCH_DIR"

# Single-instance guard: refuse to start a second watcher on the same directory
# (duplicate watchers cause duplicate notifications). Held for our lifetime.
if command -v flock &> /dev/null; then
    exec 9>"$CC_NOTIFY_MARKER_WATCH_DIR/.watcher.lock"
    if ! flock -n 9; then
        echo "Another watcher is already running on $CC_NOTIFY_MARKER_WATCH_DIR. Exiting."
        exit 1
    fi
fi

# Marker filenames are "<EVENT>.<unique-suffix>"; show just the event.
marker_event() {
    printf '%s' "${1%%.*}"
}

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
# Line 1 is the label; any following lines are an optional message (PING).
marker_session() {
    local s
    s=$(head -n1 "$1" 2>/dev/null)
    printf '%s' "${s:-unknown}"
}

marker_message() {
    tail -n +2 "$1" 2>/dev/null
}

# Build the notification body for marker file $1.
marker_body() {
    local body msg
    body="\nSession: $(marker_session "$1")\n\nEvent: $(marker_event "$(basename "$1")")"
    msg=$(marker_message "$1")
    [ -n "$msg" ] && body="$body\n\nMessage: $msg"
    printf '%s' "$body\n\nTimestamp: $(date --iso-8601=seconds)"
}

# Opt-in (CC_NOTIFY_MARKER_SPEAK_PING): speak PING markers aloud with the first
# speech program found. Without one, warn once and only show the notification.
speaker=""
case "$(printf '%s' "${CC_NOTIFY_MARKER_SPEAK_PING:-}" | tr '[:upper:]' '[:lower:]')" in
    '' | 0 | false | off | no) ;;
    *)
        for cmd in spd-say espeak-ng; do
            if command -v "$cmd" &> /dev/null; then speaker="$cmd"; break; fi
        done
        if [ -n "$speaker" ]; then
            echo "Speaking pings with $speaker."
        else
            warning="CC_NOTIFY_MARKER_SPEAK_PING is set, but neither spd-say nor espeak-ng is installed. Pings will not be spoken."
            echo "$warning"
            notify-send -t 15000 "Claude Code event handler" "$warning"
        fi
        ;;
esac

# Speak marker file $1 if it is a PING and speech is on.
speak_ping() {
    local text msg
    [ -n "$speaker" ] && [ "$(marker_event "$(basename "$1")")" = PING ] || return 0
    text="ping from $(marker_session "$1")"
    msg=$(marker_message "$1")
    [ -n "$msg" ] && text="$text: $msg"
    "$speaker" "$text" &> /dev/null &
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
        notify-send -t 15000 "Claude Code event handler" "$(marker_body "$CC_NOTIFY_MARKER_WATCH_DIR/$file")"
        speak_ping "$CC_NOTIFY_MARKER_WATCH_DIR/$file"
        rm "$CC_NOTIFY_MARKER_WATCH_DIR/$file"
    done
else
    echo "inotifywait not found, using polling fallback..."
    while true; do
        shopt -s nullglob
        for file in "$CC_NOTIFY_MARKER_WATCH_DIR"/*; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                notify-send -t 15000 "Claude Code event handler" "$(marker_body "$file")"
                speak_ping "$file"
                rm "$file"
            fi
        done
        shopt -u nullglob
        sleep 2
    done
fi

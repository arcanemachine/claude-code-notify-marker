#!/bin/bash

# Shared helpers for claude-code-notify-marker.

# Resolve the marker directory from CC_NOTIFY_MARKER_DIR.
#
# Opt-in: prints the directory and returns 0 only when explicitly enabled.
# Returns non-zero (disabled) when the variable is unset/empty or set to a
# falsey value (0/false/off/no, case-insensitive).
notify_marker_dir() {
    local dir="${CC_NOTIFY_MARKER_DIR:-}"
    case "$(printf '%s' "$dir" | tr '[:upper:]' '[:lower:]')" in
        '' | 0 | false | off | no) return 1 ;;
    esac
    printf '%s' "$dir"
}

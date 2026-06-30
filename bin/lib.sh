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

# Print the current session's configured name (Claude Code session metadata),
# or empty if it has none / cannot be resolved. The watcher falls back to the
# session id when this is empty. Characters that would break the flat JSON
# marker payload are stripped.
notify_marker_session_name() {
    local sid="${CLAUDE_CODE_SESSION_ID:-}"
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local name=""
    if [ -n "$sid" ] && command -v jq >/dev/null 2>&1; then
        name="$(jq -r --arg id "$sid" \
            'select(.sessionId == $id) | .name // empty' \
            "$cfg"/sessions/*.json 2>/dev/null | head -n1)"
    fi
    printf '%s' "${name//[\"\\]/}"
}

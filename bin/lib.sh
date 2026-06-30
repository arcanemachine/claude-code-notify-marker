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
    local file name=""
    [ -n "$sid" ] || return 0
    # Find this session's metadata file (the id is unique enough to match on),
    # then pull its "name" field out with sed. No jq dependency.
    file="$(grep -lF "$sid" "$cfg"/sessions/*.json 2>/dev/null | head -n1)"
    if [ -n "$file" ]; then
        name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n1)"
    fi
    printf '%s' "${name//[\"\\]/}"
}

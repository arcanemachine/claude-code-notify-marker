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

# True if $1 is a truthy flag value (1/true/yes/on, case-insensitive).
notify_marker_truthy() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1 | true | yes | on) return 0 ;;
        *) return 1 ;;
    esac
}

# True if line $2 is present in list file $1.
notify_marker_listed() {
    grep -qxF "$2" "$1" 2>/dev/null
}

# Add line $2 to list file $1 (idempotent).
notify_marker_list_add() {
    notify_marker_listed "$1" "$2" || echo "$2" >> "$1"
}

# Remove line $2 from list file $1 (no-op if absent/missing).
notify_marker_list_remove() {
    [ -f "$1" ] || return 0
    # grep -v exits non-zero when the result is empty, so don't gate the mv.
    grep -vxF "$2" "$1" > "$1.tmp" 2>/dev/null
    mv "$1.tmp" "$1"
}

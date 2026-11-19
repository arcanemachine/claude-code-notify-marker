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
# session id when this is empty. Quotes and backslashes are stripped.
notify_marker_session_name() {
    local sid="${CLAUDE_CODE_SESSION_ID:-}"
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local file name=""
    [ -n "$sid" ] || return 0
    # Find this session's metadata file (the id is unique enough to match on),
    # then read its top-level "name" (not the ones under "formerNames").
    file="$(grep -lF "$sid" "$cfg"/sessions/*.json 2>/dev/null | head -n1)"
    if [ -n "$file" ]; then
        name="$(notify_marker_json_field name < "$file")"
    fi
    printf '%s' "${name//[\"\\]/}"
}

# Print top-level string field $1 of the JSON object on stdin. Uses jq when
# installed; otherwise takes the first match, which is the top-level field as
# long as it comes before any nested object holding the same key.
notify_marker_json_field() {
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$1" '.[$k] // empty | strings' 2>/dev/null
    else
        grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"(\\\\.|[^\"\\\\])*\"" | head -n1 |
            sed -e 's/^[^:]*:[[:space:]]*"//' -e 's/"$//' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
    fi
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

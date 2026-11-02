#!/bin/bash

# Smoke tests for claude-code-notify-marker.
# Pure bash, no deps beyond coreutils. Run: ./test.sh

set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CM="$here/bin/create-marker.sh"
NM="$here/bin/notify-marker.sh"
PING="$here/bin/notify-marker-ping"

pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 (want [$3] got [$2])"; fi; }

# Count exact-line occurrences of $2 in file $1 (0 if file missing).
count_in() { if [ -f "$1" ]; then grep -cxF "$2" "$1"; else echo 0; fi; }
# Count marker files matching glob-prefix $1 (e.g. "$D/AGENT_DONE").
nfiles() { ls -1 "$1".* 2>/dev/null | wc -l | tr -d ' '; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export CLAUDE_CONFIG_DIR="$T/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR/sessions"

# Did create-marker write any marker file for this event? (unique suffix names)
emitted() { # $1 event -> "yes"/"no"
    rm -f "$D"/"$1".* 2>/dev/null
    "$CM" "$1" >/dev/null 2>&1
    compgen -G "$D/$1".* >/dev/null && echo yes || echo no
}

# --- Gate 1: opt-in (CC_NOTIFY_MARKER_DIR) ---
unset CC_NOTIFY_MARKER_DIR
D="$T/d"; mkdir -p "$D"
CLAUDE_CODE_SESSION_ID=s1 CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT="" \
    bash -c '"'"$CM"'" AGENT_DONE' 2>/dev/null
ok "disabled writes nothing" "$(compgen -G "$D"/AGENT_DONE.* >/dev/null && echo yes || echo no)" "no"

export CC_NOTIFY_MARKER_DIR="$D" CLAUDE_CODE_SESSION_ID=s1

# --- Gate 2: default active ---
unset CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT
ok "default-active emits"        "$(emitted AGENT_DONE)" "yes"
"$NM" pause >/dev/null;   ok "after pause silent"   "$(emitted AGENT_DONE)" "no"
"$NM" unpause >/dev/null; ok "after unpause emits"   "$(emitted AGENT_DONE)" "yes"

# --- Gate 2: default paused ---
export CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT=1
rm -f "$D/.paused-sessions" "$D/.active-sessions"
ok "default-paused silent"       "$(emitted AGENT_DONE)" "no"
"$NM" unpause >/dev/null; ok "paused+unpause emits"  "$(emitted AGENT_DONE)" "yes"
"$NM" pause >/dev/null;   ok "paused+pause silent"   "$(emitted AGENT_DONE)" "no"

# --- idempotency + mutual exclusion ---
rm -f "$D/.paused-sessions" "$D/.active-sessions"
"$NM" unpause >/dev/null; "$NM" unpause >/dev/null
ok "unpause idempotent (active)" "$(count_in "$D/.active-sessions" s1)" "1"
ok "unpause clears paused"       "$(count_in "$D/.paused-sessions" s1)" "0"

# --- forget clears both ---
"$NM" pause >/dev/null; "$NM" forget >/dev/null
ok "forget clears active" "$(count_in "$D/.active-sessions" s1)" "0"
ok "forget clears paused" "$(count_in "$D/.paused-sessions" s1)" "0"

# --- status reporting ---
rm -f "$D/.paused-sessions" "$D/.active-sessions"
ok "status default-paused" "$(CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT=1 "$NM" status)" "paused (default)"
ok "status default-active" "$(CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT="" "$NM" status)" "active (default)"
"$NM" unpause >/dev/null
ok "status active"         "$("$NM" status)" "active"
ok "status disabled" "$(CC_NOTIFY_MARKER_DIR="" "$NM" status)" "disabled (CC_NOTIFY_MARKER_DIR not set)"

# --- concurrent sessions don't collide (unique filenames) ---
rm -f "$D"/AGENT_DONE.* "$D/.paused-sessions" "$D/.active-sessions"
unset CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT
CLAUDE_CODE_SESSION_ID=sA "$CM" AGENT_DONE
CLAUDE_CODE_SESSION_ID=sB "$CM" AGENT_DONE
ok "two sessions -> two markers" "$(nfiles "$D/AGENT_DONE")" "2"

# --- ping ignores pause state, carries an optional message, reports delivery ---
rm -f "$D"/PING.* "$D/.paused-sessions" "$D/.active-sessions"
export CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT=1
"$NM" pause >/dev/null

# Fake watcher: copy the first PING marker aside, then consume it.
fake_watch() {
    local f
    for _ in $(seq 1 30); do
        for f in "$D"/PING.*; do
            [ -e "$f" ] && { cp "$f" "$T/seen"; rm -f "$f"; return; }
        done
        sleep 0.1
    done
}

rm -f "$T/seen"; fake_watch & "$PING" "need input" >/dev/null; rc=$?; wait
ok "ping delivered while paused" "$rc" "0"
ok "ping label line"   "$(head -n1 "$T/seen")" "s1"
ok "ping message line" "$(tail -n +2 "$T/seen")" "need input"

rm -f "$T/seen"; fake_watch & "$PING" >/dev/null; wait
ok "ping without message" "$(cat "$T/seen")" "s1"

CC_NOTIFY_MARKER_PING_WAIT=0.3 "$PING" "nobody home" >/dev/null; rc=$?
ok "ping undelivered exit"    "$rc" "3"
ok "ping undelivered cleaned" "$(nfiles "$D/PING")" "0"

ok "ping disabled fails" "$(CC_NOTIFY_MARKER_DIR="" "$PING" 2>/dev/null; echo $?)" "1"
unset CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]

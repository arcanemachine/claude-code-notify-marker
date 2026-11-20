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
# Hooks get JSON on stdin; tests that don't supply any must not wait on a terminal.
exec </dev/null
export CLAUDE_CONFIG_DIR="$T/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR/sessions"

# Did create-marker write any marker file for this event? (unique suffix names)
emitted() { # $1 event -> "yes"/"no"
    rm -f "$D"/"$1".* 2>/dev/null
    "$CM" "$1" >/dev/null 2>&1
    compgen -G "$D/$1".* >/dev/null && echo yes || echo no
}

# --- Gate 1: opt-in (CC_NOTIFY_MARKER_DIR) ---
unset CC_NOTIFY_MARKER_DIR CC_NOTIFY_MARKER_PING_MAX
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

# --- session name: top-level "name", not a former one ---
rm -f "$D"/AGENT_DONE.* "$D/.paused-sessions" "$D/.active-sessions"
printf '%s' '{"sessionId":"s9","name":"current","nameSource":"user","formerNames":[{"name":"old"}]}' \
    > "$CLAUDE_CONFIG_DIR/sessions/9.json"
# PATH without jq, to exercise the fallback parser.
mkdir -p "$T/nojq"
for f in /usr/bin/* /bin/*; do [ "${f##*/}" = jq ] || ln -sf "$f" "$T/nojq/" 2>/dev/null; done
CLAUDE_CODE_SESSION_ID=s9 "$CM" AGENT_DONE
ok "session name (jq)" "$(cat "$D"/AGENT_DONE.*)" "current"
rm -f "$D"/AGENT_DONE.*
CLAUDE_CODE_SESSION_ID=s9 PATH="$T/nojq" "$CM" AGENT_DONE
ok "session name (no jq)" "$(cat "$D"/AGENT_DONE.*)" "current"
rm -f "$D"/AGENT_DONE.* "$CLAUDE_CONFIG_DIR/sessions/9.json"

# --- Notification hook input: "message" becomes the second line ---
notif='{"session_id":"s1","hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}'
rm -f "$D"/NOTIFICATION.*
"$CM" NOTIFICATION <<<"$notif"
ok "notification message (jq)" "$(tail -n +2 "$D"/NOTIFICATION.*)" "Claude needs your permission to use Bash"
rm -f "$D"/NOTIFICATION.*
PATH="$T/nojq" "$CM" NOTIFICATION <<<"$notif"
ok "notification message (no jq)" "$(tail -n +2 "$D"/NOTIFICATION.*)" "Claude needs your permission to use Bash"
esc='{"message":"use \"mcp\" in C:\\tmp"}'
rm -f "$D"/NOTIFICATION.*
"$CM" NOTIFICATION <<<"$esc"
ok "escaped message (jq)" "$(tail -n +2 "$D"/NOTIFICATION.*)" 'use "mcp" in C:\tmp'
rm -f "$D"/NOTIFICATION.*
PATH="$T/nojq" "$CM" NOTIFICATION <<<"$esc"
ok "escaped message (no jq)" "$(tail -n +2 "$D"/NOTIFICATION.*)" 'use "mcp" in C:\tmp'
rm -f "$D"/NOTIFICATION.*
start=$(date +%s); "$CM" NOTIFICATION < <(sleep 5)
ok "open stdin doesn't hang" "$(( $(date +%s) - start < 4 ))" "1"
rm -f "$D"/AGENT_DONE.*
"$CM" AGENT_DONE <<<'{"session_id":"s1","hook_event_name":"Stop","last_assistant_message":"done"}'
ok "stop marker has no message" "$(cat "$D"/AGENT_DONE.*)" "s1"
rm -f "$D"/AGENT_DONE.* "$D"/NOTIFICATION.*

# --- ping ignores pause state, carries an optional message, reports delivery ---
rm -f "$D"/PING* "$D/.paused-sessions" "$D/.active-sessions"
export CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT=1
"$NM" pause >/dev/null

# Fake watcher: copy the first PING marker aside, then consume it.
fake_watch() {
    local f
    for _ in $(seq 1 30); do
        for f in "$D"/PING*; do
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

at_max=$(printf 'é%.0s' $(seq 1 255))
rm -f "$T/seen"; fake_watch & "$PING" "$at_max" >/dev/null; rc=$?; wait
ok "ping at the limit delivered" "$rc" "0"
ok "ping at the limit intact" "$(tail -n +2 "$T/seen")" "$at_max"

"$PING" "${at_max}é" 2>/dev/null; rc=$?
ok "ping over the limit rejected" "$rc" "2"
ok "ping over the limit not sent" "$(nfiles "$D/PING")" "0"

ok "ping --max default" "$("$PING" --max)" "255"
ok "ping --max set"     "$(CC_NOTIFY_MARKER_PING_MAX=64 "$PING" --max)" "64"
ok "ping --max invalid" "$(CC_NOTIFY_MARKER_PING_MAX=abc "$PING" --max)" "255"
ok "ping --max disabled" "$(CC_NOTIFY_MARKER_DIR="" "$PING" --max; echo $?)" "$(printf '255\n0')"
rm -f "$T/seen"; fake_watch & "$PING" --max please >/dev/null; wait
ok "ping --max inside a message" "$(tail -n +2 "$T/seen")" "--max please"

for q in -q --quiet; do
    rm -f "$T/seen"; fake_watch & "$PING" "$q" "shh" >/dev/null; rc=$?; wait
    ok "ping $q delivered" "$rc" "0"
    ok "ping $q message" "$(tail -n +2 "$T/seen")" "shh"
done
fake_watch_name() { for _ in $(seq 1 30); do for f in "$D"/PING*; do [ -e "$f" ] && { basename "$f" | cut -d. -f1; rm -f "$f"; return; }; done; sleep 0.1; done; }
ok "ping --quiet event" "$(fake_watch_name & "$PING" --quiet x >/dev/null; wait)" "PING_QUIET"
ok "ping event"         "$(fake_watch_name & "$PING" x >/dev/null; wait)" "PING"

ok "ping disabled fails" "$(CC_NOTIFY_MARKER_DIR="" "$PING" 2>/dev/null; echo $?)" "1"
unset CC_NOTIFY_MARKER_PAUSED_BY_DEFAULT

# --- watcher: speaks PING markers when CC_NOTIFY_MARKER_SPEAK_PING is on ---
WATCHER="$here/watch-and-notify.sh"
mkdir -p "$T/fakes" "$T/fakes-nospeech"
for c in spd-say notify-send; do
    printf '#!/bin/bash\necho "%s: $*" >> "%s/calls"\n' "$c" "$T" > "$T/fakes/$c"
    chmod +x "$T/fakes/$c"
done
cp "$T/fakes/notify-send" "$T/fakes-nospeech/"

# Run the watcher on a fresh dir with $1 as speech setting and $2 as fake bin dir,
# feed it a PING with a message, a bare PING, a PING_QUIET and an AGENT_DONE; print spd-say calls.
watch_run() {
    local W="$T/w"; rm -rf "$W" "$T/calls"; mkdir -p "$W"
    CC_NOTIFY_MARKER_WATCH_DIR="$W" CC_NOTIFY_MARKER_SPEAK_PING="$1" PATH="$2:$PATH" \
        env -u BASH_ENV timeout 2 "$WATCHER" >/dev/null 2>&1 &
    sleep 0.5
    printf 's1\nbuild finished' > "$W/PING.a"; sleep 0.2
    printf 's1' > "$W/PING.b"; sleep 0.2
    printf 's1\nshh' > "$W/PING_QUIET.c"; sleep 0.2
    printf 's1' > "$W/AGENT_DONE.c"; sleep 0.3
    wait
    grep -E '^spd-say|installed' "$T/calls" 2>/dev/null
}
ok "watcher speaks pings" "$(watch_run 1 "$T/fakes")" \
    "$(printf 'spd-say: ping from s1 with message build finished\nspd-say: ping from s1')"
ok "watcher silent by default" "$(watch_run "" "$T/fakes")" ""
ok "watcher warns without speech" "$(watch_run 1 "$T/fakes-nospeech" | grep -c 'neither spd-say nor espeak-ng')" "1"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]

---
name: ping
description: Desktop ping via notify-marker; args say when and what (e.g. in 10s, "build finished")
disable-model-invocation: true
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping:*)", "Bash(sleep:*)"]
---

Ping the user by running `"${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping" "<message>"`.

- No arguments: ping now with the message `ping`.
- Arguments: instructions for the ping (when, what it says). Follow them if clear; otherwise ask the user.
- A delay: run `sleep <seconds>; <the command above>` as a background command (Bash `run_in_background`, not `&`), so the turn can end.
- For the rest of the session, the user may ask you to ping them again (e.g. "ping me when done"); use the same command.

`ping delivered` (exit 0) means the user was notified. `ping NOT picked up` (exit 3) means no watcher is
running: don't retry; say so in your reply.

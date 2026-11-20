---
name: ping
description: Desktop ping via notify-marker; args say when and what (e.g. in 10s, "build finished")
disable-model-invocation: true
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping:*)", "Bash(sleep:*)"]
---

Ping the user by running `"${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping" "<message>"`.

Message length limit: !`"${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping" --max` characters. Keep the message well under it;
the script has the final say.

- No arguments: ping now with the message `ping`.
- Quiet: if the instructions start with `quiet`, `-q` or `--quiet`, or ask for a quiet or silent ping, drop that word
  and pass `--quiet` as the first argument, before the message. The ping is shown but not spoken.
- Arguments: instructions for the ping (when, what it says). Follow them if clear; otherwise ask the user.
- A delay: run `sleep <seconds>; <the command above>` as a background command (Bash `run_in_background`, not `&`), so the turn can end.
- For the rest of the session, the user may ask you to ping them again (e.g. "ping me when done"); use the same command.

Results:

- `ping delivered` (exit 0): the user was notified.
- Exit 1: disabled or the marker could not be written. Don't retry; say so in your reply.
- Exit 2: the message is over the limit (named in the error) and was not sent. Shorten it and run the command
  again, once, at once (no new delay, even for a delayed ping). If that fails too, say so in your reply.
- `ping NOT picked up` (exit 3): no watcher is running. Don't retry; say so in your reply.

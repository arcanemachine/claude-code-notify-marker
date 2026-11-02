---
name: ping
description: Send the user a desktop notification when you need their attention (a decision, input, approval, or you are blocked). Works even when notify-marker is paused for this session. Use sparingly — only when you genuinely need the user.
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping:*)"]
---

Run, with a short message saying what you need:

`"${CLAUDE_PLUGIN_ROOT}/bin/notify-marker-ping" "<short message>"`

It waits briefly to see if the watcher picked the ping up:

- `ping delivered` (exit 0): the user was notified.
- `ping NOT picked up` (exit 3): no watcher is running, so the user was not notified. Don't retry; just say what you need in your reply.

Either way, tell the user what you need in your reply as usual. The ping only gets their attention; it does not replace the message.

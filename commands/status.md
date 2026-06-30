---
description: Show whether notify-marker is paused or active for the current Claude Code session
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/bin/notify-marker.sh:*)"]
---

Run the following command and report only its output to the user:

`"${CLAUDE_PLUGIN_ROOT}/bin/notify-marker.sh" status`

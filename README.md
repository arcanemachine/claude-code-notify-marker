# claude-code-notify-marker

> Marker file plugin for Claude Code - create files when events occur.

A plugin for [Claude Code](https://code.claude.com) that creates marker files when specific events occur. Useful for external monitoring scripts to detect when the AI needs attention (e.g. when running Claude Code in a container where native OS notifications cannot be triggered).

This project is the Claude Code sibling of [pi-notify-marker](https://github.com/arcanemachine/pi-notify-marker) (for the Pi coding agent) and [opencode-notify-marker](https://github.com/arcanemachine/opencode-notify-marker) (for OpenCode).

## Why This Exists

So that you can run Claude Code in a container, and still have a means of getting OS notifications on the host.

## How It Works

Claude Code [hooks](https://code.claude.com/docs/en/hooks) run a small bundled script (`bin/create-marker.sh`) when certain events occur. The script writes a marker file into a configurable directory.

The included script `./watch-and-notify.sh` watches the marker directory and sends Linux OS notifications (via `notify-send`) when files are created. It automatically deletes the marker file after showing the notification.

### Supported Events

| Event          | Hook           | Marker File    | Description                          |
| -------------- | -------------- | -------------- | ------------------------------------ |
| Agent done     | `Stop`         | `AGENT_DONE`   | Claude finished responding           |
| Needs input    | `Notification` | `NOTIFICATION` | Claude needs attention (e.g. a permission prompt or is idle waiting for input) |

## Installation

### From GitHub (Recommended)

In Claude Code, install the plugin from this repo:

```
/plugin install https://github.com/arcanemachine/claude-code-notify-marker.git
```

### From Local Clone (development)

```bash
git clone https://github.com/arcanemachine/claude-code-notify-marker.git
claude --plugin-dir /path/to/claude-code-notify-marker
```

Use the `/hooks` command inside Claude Code to confirm the hooks registered.

## Usage

If you want desktop notifications when the agent finishes or needs attention:

1. Start Claude Code in the container (with the plugin installed).

2. Run `watch-and-notify.sh` from the host.

## Directory config

```bash
# Start Claude Code with a custom marker directory
CC_NOTIFY_MARKER_DIR="/path/to/some/dir" claude

# Run watcher script pointing to the same directory in a Docker volume mount
CC_NOTIFY_MARKER_WATCH_DIR="/workspace/path/to/mount/dir" ./watch-and-notify.sh
```

Both default to `/tmp/cc-notify-marker-files`. Prefer absolute paths; make sure Claude Code and the watcher resolve to the same directory (e.g. a shared volume mount).

# Agent Instructions

## Workflow

Commit when a task is completed.

## Pre-commit

```bash
# Validate JSON manifests parse cleanly
jq . .claude-plugin/plugin.json hooks/hooks.json

# Keep shell scripts executable
chmod +x bin/create-marker.sh watch-and-notify.sh
```

## Commit Style

Match existing commits:
- `Add plugin manifest and Stop/Notification hooks`
- `Update README with plugin installation instructions`
- `Rename marker directory env var`

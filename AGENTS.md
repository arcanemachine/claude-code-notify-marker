# Agent Instructions

## Workflow

Commit when a task is completed.

## Pre-commit

```bash
# Validate JSON manifests parse cleanly
jq . .claude-plugin/plugin.json hooks/hooks.json

# Keep shell scripts executable
chmod +x bin/create-marker.sh bin/notify-marker-ping watch-and-notify.sh
```

## Commit Style

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<optional scope>): <description>`, e.g.
- `feat(watcher): speak PING markers aloud`
- `fix: read the session name after a rename`
- `docs: update README for prompt-only notifications`

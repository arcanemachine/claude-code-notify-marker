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

## Release

1. Bump `"version"` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and commit as
   `chore(release): <version>`.
2. Tag it with an annotated tag: `git tag -a v<version> -m 'v<version>: <summary of changes>'`.
3. Update the installed plugin, so the running Claude Code uses the release:

   ```bash
   claude plugin marketplace update claude-code-notify-marker
   claude plugin update notify-marker@claude-code-notify-marker --scope <scope it is installed at>
   ```

   Then tell the user to run `/reload-plugins` to apply it.

## Commit Style

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<optional scope>): <description>`, e.g.
- `feat(watcher): speak PING markers aloud`
- `fix: read the session name after a rename`
- `docs: update README for prompt-only notifications`

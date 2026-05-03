#!/bin/bash
# Setup script for syncing Claude Code config to a new machine.
# Usage: git clone <repo-url> ~/src/Panoply && ~/src/Panoply/setup.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Setting up Claude Code config from $REPO_DIR..."

# Create ~/.claude if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Files/dirs to symlink (shared config, tracked in git).
# `skills/` is handled separately via the bundle switcher — it's not a single
# symlink but a populated directory of per-skill links.
SYMLINK_ITEMS=(CLAUDE.md settings.json hooks agents)

for item in "${SYMLINK_ITEMS[@]}"; do
  target="$CLAUDE_DIR/$item"
  source="$REPO_DIR/$item"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "  Backing up existing $target -> ${target}.bak"
    mv "$target" "${target}.bak"
  fi

  if [ -L "$target" ]; then
    rm "$target"
  fi

  ln -s "$source" "$target"
  echo "  Linked $target -> $source"
done

# Skills are managed by skill-bundles/ + scripts/panoply-skills.
# Default bundle lives in skill-bundles/ACTIVE (version-controlled).
# Initialise it on first setup if absent.
if [ ! -f "$REPO_DIR/skill-bundles/ACTIVE" ]; then
  echo "rpi" > "$REPO_DIR/skill-bundles/ACTIVE"
  echo "  Initialised skill-bundles/ACTIVE -> rpi"
fi
chmod +x "$REPO_DIR/scripts/panoply-skills" "$REPO_DIR/scripts/claude-skills"
"$REPO_DIR/scripts/panoply-skills" relink

# settings.local.json is machine-specific (permissions, MCP tools).
# Copy from template if no local file exists; never overwrite existing.
LOCAL_SETTINGS="$REPO_DIR/settings.local.json"
LOCAL_SETTINGS_CLAUDE="$CLAUDE_DIR/settings.local.json"

if [ ! -e "$LOCAL_SETTINGS" ]; then
  cp "$REPO_DIR/settings.local.example.json" "$LOCAL_SETTINGS"
  echo "  Created settings.local.json from template (customise your permissions here)"
else
  echo "  settings.local.json already exists (kept as-is)"
fi

# Symlink the local settings into ~/.claude/
if [ -e "$LOCAL_SETTINGS_CLAUDE" ] && [ ! -L "$LOCAL_SETTINGS_CLAUDE" ]; then
  echo "  Backing up existing $LOCAL_SETTINGS_CLAUDE -> ${LOCAL_SETTINGS_CLAUDE}.bak"
  mv "$LOCAL_SETTINGS_CLAUDE" "${LOCAL_SETTINGS_CLAUDE}.bak"
fi

if [ -L "$LOCAL_SETTINGS_CLAUDE" ]; then
  rm "$LOCAL_SETTINGS_CLAUDE"
fi

ln -s "$LOCAL_SETTINGS" "$LOCAL_SETTINGS_CLAUDE"
echo "  Linked $LOCAL_SETTINGS_CLAUDE -> $LOCAL_SETTINGS"

# Ensure hook scripts are executable (some systems strip execute bits on clone)
chmod +x "$REPO_DIR/hooks/"*.sh

# Install pre-commit hook to prevent accidental secret leaks
GIT_HOOKS_DIR="$REPO_DIR/.git/hooks"
mkdir -p "$GIT_HOOKS_DIR"
ln -sf "$REPO_DIR/hooks/pre-commit-secrets-check.sh" "$GIT_HOOKS_DIR/pre-commit"
echo "  Installed pre-commit secrets check hook"

echo ""
echo "Done! Claude Code config is now synced."
echo ""
echo "Next steps:"
echo "  - Edit ~/src/Panoply/settings.local.json to customise your permissions"
echo "  - Edit ~/src/Panoply/CLAUDE.md to set your workflow preferences"

#!/usr/bin/env bash
# install.sh — Install the Stride ideation extension for Gemini CLI
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cheezy/stride-gemini-ideation/main/install.sh | bash
#
# Or clone and run locally:
#   ./install.sh            # global:  ~/.gemini/extensions/stride-gemini-ideation/
#   ./install.sh --project  # project: .gemini/extensions/stride-gemini-ideation/
#
# Prefer `gemini extensions install https://github.com/cheezy/stride-gemini-ideation`
# when available — this script is the manual fallback.

set -euo pipefail

REPO="https://github.com/cheezy/stride-gemini-ideation.git"
EXT_NAME="stride-gemini-ideation"
MODE="global"

for arg in "$@"; do
  case "$arg" in
    --project) MODE="project" ;;
    --help|-h)
      echo "Usage: install.sh [--project]"
      echo ""
      echo "  (default)   Install globally to ~/.gemini/extensions/$EXT_NAME/"
      echo "  --project   Install to .gemini/extensions/$EXT_NAME/ in the current directory"
      exit 0
      ;;
  esac
done

if [ "$MODE" = "project" ]; then
  INSTALL_DIR=".gemini/extensions/$EXT_NAME"
  echo "Installing $EXT_NAME into .gemini/extensions/ (project-local)..."
else
  INSTALL_DIR="$HOME/.gemini/extensions/$EXT_NAME"
  echo "Installing $EXT_NAME into ~/.gemini/extensions/ (global)..."
fi

mkdir -p "$INSTALL_DIR"

# Determine the source: the directory this script lives in if it already
# contains the extension files, otherwise clone a fresh copy to a temp dir.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/gemini-extension.json" ]; then
  SRC="$SCRIPT_DIR"
  CLEANUP=""
else
  TMPDIR="$(mktemp -d)"
  CLEANUP="$TMPDIR"
  echo "Downloading from $REPO..."
  git clone --quiet --depth 1 "$REPO" "$TMPDIR/$EXT_NAME"
  SRC="$TMPDIR/$EXT_NAME"
fi
trap '[ -n "${CLEANUP:-}" ] && rm -rf "$CLEANUP"' EXIT

# Copy the manifest, context file, and the four content directories. Use
# cp -a to preserve the executable bit on the lib/*.sh helpers.
cp "$SRC/gemini-extension.json" "$INSTALL_DIR/"
cp "$SRC/GEMINI.md" "$INSTALL_DIR/"
[ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$INSTALL_DIR/"
for dir in commands skills agents lib fixtures; do
  mkdir -p "$INSTALL_DIR/$dir"
  cp -a "$SRC/$dir/." "$INSTALL_DIR/$dir/"
done

echo ""
echo "Stride Ideation for Gemini CLI installed to $INSTALL_DIR"
echo ""
echo "Installed:"
echo "  Commands: $(ls "$INSTALL_DIR/commands"/*.toml 2>/dev/null | wc -l | tr -d ' ') (.toml)"
echo "  Skills:   $(ls -d "$INSTALL_DIR/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  Agents:   $(ls "$INSTALL_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Helpers:  $(ls "$INSTALL_DIR/lib" 2>/dev/null | wc -l | tr -d ' ') files in lib/"
echo "  Fixtures: $(ls "$INSTALL_DIR/fixtures" 2>/dev/null | wc -l | tr -d ' ') files in fixtures/"
echo ""
echo "Next steps:"
echo "  1. Restart Gemini CLI so it picks up the new extension (/ideate, /stridify)."
echo "  2. For /stridify: create .stride_auth.md in your project root with your"
echo "     Stride API credentials (see the README) and add it to .gitignore."

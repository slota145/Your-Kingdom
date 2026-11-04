#!/usr/bin/env bash
# SessionStart hook (see .claude/settings.json): prepares Godot in Claude Code cloud
# sessions. Does nothing on local machines.
set -uo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0

GODOT_BIN="$(tools/setup_godot.sh)" || { echo "Godot setup failed" >&2; exit 0; }

# Make $GODOT available to every Bash command of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export GODOT=\"$GODOT_BIN\"" >> "$CLAUDE_ENV_FILE"
fi

# Fresh clone: build the import cache and the global class list once.
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1 || echo "Godot import reported errors" >&2
echo "Godot ready: $GODOT_BIN"
exit 0

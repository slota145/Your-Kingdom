#!/usr/bin/env bash
# Exports the game (ROADMAP M10 part 2) and, for Linux, runs the exported build once without a
# screen as a smoke run (Game.smoke_seconds): a new game at the highest speed, an autosave, the
# autosave loaded back, a moment more, quit. Checks that everything is found inside the pack.
#   tools/export_game.sh [linux|windows]     (default: linux; needs Godot's export templates in
#   ~/.local/share/godot/export_templates/4.7.2.stable, see docs/CLOUD_SETUP.md)
# On the owner's laptop use eksportuj.ps1 instead.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(tools/setup_godot.sh)}"
target="${1:-linux}"
if [ "$target" = "windows" ]; then
    preset="Windows Desktop"; out="build/windows/YourKingdom.exe"
else
    preset="Linux"; out="build/linux/YourKingdom.x86_64"
fi
mkdir -p "$(dirname "$out")"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "$preset" "$out" >/dev/null
ls -la "$out"
if [ "$target" = "linux" ]; then
    log="$(mktemp)"
    timeout 300 "./$out" --headless -- --smoke=20 >"$log" 2>&1 || true
    cat "$log"
    # Known engine noise of a headless release build (not from the game's scripts; 2026-11-14):
    # "Attempt to disconnect a nonexistent connection from 'root..." when the menu's windows
    # close, and now and then "N resources still in use at exit" when the game quits.
    if grep -E "SCRIPT ERROR|ERROR:" "$log" | grep -vE "nonexistent connection from 'root|resources still in use at exit" | grep -q . \
            || ! grep -q "^smoke:" "$log"; then
        echo "The exported game reported errors or did not finish the smoke run (above)." >&2
        exit 1
    fi
    echo "The exported game played, saved and loaded without errors."
fi

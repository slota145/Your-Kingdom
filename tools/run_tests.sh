#!/usr/bin/env bash
# Runs all gdUnit4 tests headless. Usage: tools/run_tests.sh [extra gdUnit4 args]
# Set GODOT to the Godot 4.7 console executable if it is not at the default path.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/c/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"

# Refresh imports and the global class cache (needed after adding class_name scripts).
"$GODOT" --headless --path . --import > /dev/null 2>&1

# --remote-debug to an unbound port avoids Godot's interactive debugger on script errors.
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests "$@"

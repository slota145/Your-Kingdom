#!/usr/bin/env bash
# Runs all gdUnit4 tests headless. Usage: tools/run_tests.sh [extra gdUnit4 args]
# GODOT may point to the Godot 4.7 executable. Otherwise the owner's Windows install is used
# if present, and on Linux (cloud sessions) Godot is downloaded by tools/setup_godot.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

WINDOWS_GODOT="/c/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
if [ -z "${GODOT:-}" ]; then
	if [ -x "$WINDOWS_GODOT" ]; then
		GODOT="$WINDOWS_GODOT"
	else
		GODOT="$(tools/setup_godot.sh)"
	fi
fi

# Refresh imports and the global class cache (needed after adding class_name scripts).
"$GODOT" --headless --path . --import > /dev/null 2>&1

# Default: the whole suite. Pass e.g. "-a res://tests/unit/view" to run a subset.
if [ $# -eq 0 ]; then set -- -a res://tests; fi

# --remote-debug to an unbound port avoids Godot's interactive debugger on script errors.
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "$@"

#!/usr/bin/env bash
# Runs the gdUnit4 tests headless, in two tiers (owner's decision 2026-11-07, ARCHITECTURE §12):
#   tools/run_tests.sh           fast tests: tests/unit, tests/data, tests/scenario, in 4 Godots
#                                at once (about 2 min); before every commit
#   tools/run_tests.sh --serial  the same fast tests in one Godot (one report)
#   tools/run_tests.sh --long    long tests: tests/long (automatic players, two hours of the big
#                                city, mode coherence; about 5 min), one Godot per suite in
#                                parallel; before merging to main and at the end of a part
#   tools/run_tests.sh --all     both tiers, in parallel
#                                (speed limits doubled here: the Godots share the processor;
#                                exact: "tools/run_tests.sh -a res://tests/long/<suite>.gd")
#   tools/run_tests.sh <args>    gdUnit4 arguments as they are, e.g. "-a res://tests/unit/view"
# Logs and reports of parallel runs: reports/<name>.log and reports/<name>/.
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

# --remote-debug to an unbound port avoids Godot's interactive debugger on script errors.
gdunit() {
	"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
		res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "$@"
}

FAST=(-a res://tests/unit -a res://tests/data -a res://tests/scenario)

# Runs every job ("name|gdUnit args") in its own Godot at once, then prints each job's
# summary and failures; fails when any job failed or did not finish.
run_parallel() {
	mkdir -p reports
	local pids=() names=()
	# The Godots share the processor: speed checks allow twice the time (SimFixture.speed_limit).
	export YK_SHARED_CPU=1
	for job in "$@"; do
		local name="${job%%|*}"
		local args="${job#*|}"
		# shellcheck disable=SC2086
		gdunit -c $args -rd "reports/$name" > "reports/$name.log" 2>&1 &
		pids+=($!)
		names+=("$name")
	done
	local failed=0
	for i in "${!pids[@]}"; do
		wait "${pids[$i]}" || true
		local log="reports/${names[$i]}.log"
		local summary
		summary="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep "Overall Summary" | tail -1 || true)"
		echo "${names[$i]}: ${summary:-no summary, see $log}"
		sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E " FAILED|SCRIPT ERROR" || true
		if [ -z "$summary" ] || ! echo "$summary" | grep -q "| 0 errors | 0 failures"; then
			failed=1
		fi
	done
	return $failed
}

# The fast tests in FAST_GROUPS Godots at once (speed-up 2026-11-11: one Godot took 6.5 min on
# the cloud's 4 cores). The slow world suites (M6-M8, world) are dealt out first, one by one
# in turn, then the rest, so each group gets a similar share.
FAST_GROUPS=4
fast_jobs() {
	local heavy=() light=() groups=()
	for f in tests/unit/*.gd tests/unit/*/*.gd tests/unit/*/*/*.gd tests/data/*.gd tests/data/*/*.gd tests/scenario/*.gd; do
		[ -f "$f" ] || continue
		case "$(basename "$f")" in
			test_m6_*|test_m7_*|test_m8_*|test_world_*) heavy+=("$f") ;;
			test_*.gd) light+=("$f") ;;
		esac
	done
	local i=0
	for f in "${heavy[@]}" "${light[@]}"; do
		groups[i % FAST_GROUPS]+=" -a res://$f"
		i=$((i + 1))
	done
	for g in "${!groups[@]}"; do
		echo "fast_$((g + 1))|${groups[$g]}"
	done
}

long_jobs() {
	for suite in tests/long/test_*.gd; do
		local name
		name="long_$(basename "$suite" .gd)"
		echo "$name|-a res://$suite"
	done
}

case "${1:-}" in
	"")
		mapfile -t jobs < <(fast_jobs)
		run_parallel "${jobs[@]}"
		;;
	--serial)
		gdunit -c "${FAST[@]}"
		;;
	--long)
		mapfile -t jobs < <(long_jobs)
		run_parallel "${jobs[@]}"
		;;
	--all)
		mapfile -t jobs < <(fast_jobs; long_jobs)
		run_parallel "${jobs[@]}"
		;;
	*)
		gdunit "$@"
		;;
esac

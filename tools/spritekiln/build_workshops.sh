#!/bin/bash
# G3 part 3: generate, render and export workshop buildings (base and both construction stages).
# Run from anywhere: tools/spritekiln/build_workshops.sh <id> [<id>...]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" && python3 gen_workshops.py "$@"
for id in "$@"; do
	(cd "$HERE/art/specs/props/$id" && for s in "$id" "${id}_c1" "${id}_c2" $(cd "$HERE/art/specs/props/$id" && ls ${id}_anim_*.yaml 2>/dev/null | sed "s/.yaml//"); do spritekiln render "$s.yaml" | grep -E "QA|rror"; done)
	python3 "$HERE/export_building.py" "$id" --stages
done

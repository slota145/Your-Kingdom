#!/bin/bash
# G3 clean-up: construction stages from the model for the earlier SpriteKiln buildings (gen_stages.py):
# generate, render (4 at a time, one core each) and export construction_1 and construction_2 only.
# Run from anywhere: tools/spritekiln/build_stages.sh [<id>...]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" && python3 gen_stages.py "$@"
ids="$*"
[ -n "$ids" ] || ids="$(python3 -c 'import gen_stages; print(" ".join(gen_stages.IDS))')"
for id in $ids; do
	cd "$HERE/art/specs/props/$id"
	for s in "${id}_c1" "${id}_c2"; do
		(NUMBA_NUM_THREADS=1 spritekiln render "$s.yaml" | grep -E "QA|rror" || true) &
		while [ "$(jobs -r | wc -l)" -ge 4 ]; do sleep 1; done
	done
done
wait
for id in $ids; do
	(cd "$HERE" && python3 -c "import sys; from export_building import export; [export(sys.argv[1], '%s_c%d' % (sys.argv[1], k), sys.argv[1], 'construction_%d' % k) for k in (1, 2)]" "$id")
done

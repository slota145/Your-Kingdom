#!/bin/bash
# G3 part 5a: generate, render and export harbour buildings: base art, both construction stages and
# the pieces of buildings drawn in pieces (the port's shed, the port warehouses' sheds). Yards (port
# warehouses, port store) have no base art. Run from anywhere: tools/spritekiln/build_port.sh <id>...
# Renders run 4 at a time, one core each.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
YARDS=" port_warehouse port_warehouse_small port_store "
cd "$HERE" && python3 "${GEN:-gen_port.py}" "$@"
for id in "$@"; do
	cd "$HERE/art/specs/props/$id"
	specs="${id}_c1 ${id}_c2 $(ls ${id}_shed_*.yaml 2>/dev/null | sed "s/.yaml//")"
	[[ "$YARDS" == *" $id "* ]] || specs="$id $specs"
	for s in $specs; do
		(NUMBA_NUM_THREADS=1 spritekiln render "$s.yaml" | grep -E "QA|rror" || true) &
		while [ "$(jobs -r | wc -l)" -ge 4 ]; do sleep 1; done
	done
	wait
	if [[ "$YARDS" == *" $id "* ]]; then
		(cd "$HERE" && python3 -c "import sys; from export_building import export; [export(sys.argv[1], '%s_c%d' % (sys.argv[1], k), sys.argv[1], 'construction_%d' % k) for k in (1, 2)]" "$id")
	else
		python3 "$HERE/export_building.py" "$id" --stages
	fi
	if [ -f "pieces.json" ]; then python3 "$HERE/export_pieces.py" "$id"; fi
done

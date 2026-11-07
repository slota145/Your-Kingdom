class_name ServiceCoverage
extends RefCounted
## Which tiles each service (well...) reaches, measured as path length from the service
## building's entrance (GDD §3.2). Recomputed when the map or the service buildings change.

## Service building def id -> how many sources cover each tile.
var _counts: Dictionary[StringName, PackedInt32Array] = {}
## Source building id -> its last flood (_Source). Kept while the building stands, also while
## it does not serve (a tavern without drinks), so it can serve again without a new flood.
var _sources: Dictionary[int, _Source] = {}
## Tiles whose walkability or walking cost changed since the last update -> their reach cost
## before the first of those changes (_dirty_solid: whether they were solid then).
var _dirty_tiles: Dictionary[Vector2i, float] = {}
var _dirty_solid: Dictionary[Vector2i, bool] = {}
## Walking cost per tile for service reach (index y * width + x): roads, fields and terrain,
## without trees (ProvinceSim.refresh_tile).
var cost_map: PackedFloat64Array = PackedFloat64Array()
var _width: int = 0
## Buildings with a service radius, rebuilt when buildings come or go.
var _service_buildings: Array[BuildingState] = []
var _buildings_version: int = -1
var _solid_version: int = -1
## Sources flooded whole and patched in place since the start (tests and measurements).
var full_floods: int = 0
var patched_floods: int = 0
## Grows whenever a covered tile changes (the view redraws the reach only then).
var version: int = 0


class _Source:
	var service: StringName
	var start: Vector2i
	var radius: float
	## Covered tile indices, and the same as a flag per tile.
	var tiles: PackedInt32Array
	var covered: PackedByteArray
	## Path length from the entrance per tile (INF where not covered): lets a change that only
	## shortens paths (a quarried rock, a new road) be patched instead of flooded again.
	var best: PackedFloat64Array
	## Bounding box of the covered tiles, grown by one tile.
	var box: Rect2i
	var active: bool = false
	var stale: bool = false


func covers(service: StringName, tile: Vector2i, size: Vector2i) -> bool:
	if not _counts.has(service) or tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return false
	return _counts[service][tile.y * size.x + tile.x] > 0


## Covered flag per tile (view overlay); empty when nothing provides the service.
func map_of(service: StringName) -> PackedByteArray:
	var counts: PackedInt32Array = _counts.get(service, PackedInt32Array())
	var map := PackedByteArray()
	var any := false
	map.resize(counts.size())
	for i: int in counts.size():
		if counts[i] > 0:
			map[i] = 1
			any = true
	return map if any else PackedByteArray()


func setup(size: Vector2i) -> void:
	_width = size.x
	cost_map.resize(size.x * size.y)
	cost_map.fill(1.0)


## The reach cost of [param tile] is [param cost] now and people can walk there unless
## [param solid]; [param solid_changed] when that flipped just now (ProvinceSim.refresh_tile).
func set_tile(tile: Vector2i, cost: float, solid: bool, solid_changed: bool) -> void:
	var i := tile.y * _width + tile.x
	if solid_changed or cost_map[i] != cost:
		if not _dirty_tiles.has(tile):
			_dirty_tiles[tile] = cost_map[i]
			_dirty_solid[tile] = solid != solid_changed
		cost_map[i] = cost


## Brings the coverage up to date. A source changes only when a changed tile touches what it
## covers (the flood reads only covered tiles and their neighbours). A change that only opens
## or shortens paths, or closes a tile no covered path goes through, is patched in place (a
## quarried rock in the town no longer floods every well around it at once, ROADMAP M4b-3
## review fixes); anything else floods the source again. Either way the result is the same as
## flooding every source from scratch (a loaded game matches the running one, ARCHITECTURE
## §9.3 M4b-3).
func update(province: ProvinceSim) -> void:
	var size := province.grid.size
	var check := false
	if not _dirty_tiles.is_empty():
		var changed := _real_changes(province)
		if not changed.is_empty():
			for source: _Source in _sources.values():
				if source.stale or not _touched(source, changed, size):
					continue
				if _patch(province, source, changed):
					patched_floods += 1
				else:
					source.stale = true
					check = true
		_dirty_tiles.clear()
		_dirty_solid.clear()
	if _buildings_version != province.buildings.version \
			or _solid_version != province.nav.solid_version:
		# Buildings came or went, or one was turned (its entrance moved).
		_buildings_version = province.buildings.version
		_solid_version = province.nav.solid_version
		_service_buildings.clear()
		for building: BuildingState in province.buildings.all():
			if building.def.service_radius > 0:
				_service_buildings.append(building)
		check = true
	if check:
		for id: int in _sources.keys():
			var source: _Source = _sources[id]
			var building := province.buildings.get_building(id)
			if building == null or building.def.service_radius <= 0 \
					or building.entrance_tile() != source.start or source.stale:
				_set_active(source, false, size)
				_sources.erase(id)
	for building: BuildingState in _service_buildings:
		var serving := building.provides_service(province.tick)
		var source: _Source = _sources.get(building.id)
		if source == null:
			if not serving:
				continue
			source = _flood_source(province, building)
			_sources[building.id] = source
		_set_active(source, serving, size)


## The dirty tiles that differ now from before (a tile changed and changed back is left out).
func _real_changes(province: ProvinceSim) -> Array[Vector2i]:
	var solid := province.nav.solid_map
	var result: Array[Vector2i] = []
	for tile: Vector2i in _dirty_tiles:
		var i := tile.y * _width + tile.x
		var was_solid: bool = _dirty_solid[tile]
		var is_solid := solid[i] == 1
		if was_solid != is_solid or (not is_solid and _dirty_tiles[tile] != cost_map[i]):
			result.append(tile)
	return result


func _touched(source: _Source, changed: Array[Vector2i], size: Vector2i) -> bool:
	for tile: Vector2i in changed:
		if not source.box.has_point(tile):
			continue
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var t := tile + Vector2i(dx, dy)
				if t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y \
						and source.covered[t.y * size.x + t.x] == 1:
					return true
	return false


## Applies [param changed] to [param source] without a new flood; false (nothing changed yet)
## when a covered path may have got longer, so the source must flood again.
func _patch(province: ProvinceSim, source: _Source, changed: Array[Vector2i]) -> bool:
	var w := province.grid.size.x
	var h := province.grid.size.y
	var solid := province.nav.solid_map
	var best := source.best
	var start_i := source.start.y * w + source.start.x
	var closed: Array[int] = []
	var opened: Array[int] = []
	# First only checks (best still holds the lengths before the change).
	for tile: Vector2i in changed:
		var i := tile.y * w + tile.x
		if i == start_i:
			return false
		var was_solid: bool = _dirty_solid[tile]
		var is_solid := solid[i] == 1
		if is_solid and not was_solid:
			# Closed: fine while no covered length came through it or past its corner.
			if _someone_steps_from(province, source, tile) or _corner_used(province, source, tile):
				return false
			closed.append(i)
		elif not is_solid and not was_solid and cost_map[i] > _dirty_tiles[tile]:
			# Dearer: its own length grows, and maybe of what lies behind it.
			if best[i] != INF:
				return false
		elif not is_solid:
			opened.append(i)
	for i: int in closed:
		if best[i] != INF:
			_uncover(source, i)
	var heap_d := PackedFloat64Array()
	var heap_i := PackedInt32Array()
	for i: int in opened:
		var tile := Vector2i(i % w, i / w)
		# The tile itself, reached from a covered neighbour.
		for step: Vector2i in IsoMath.DIR_GRID_STEP:
			var n := tile - step
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var ni := n.y * w + n.x
			if best[ni] != INF:
				_relax(solid, cost_map, w, source.radius, best, heap_d, heap_i, ni, i, step)
		# An open tile no longer blocks the diagonal steps past its corner.
		for d: Vector2i in DIAGONALS:
			var a := tile + Vector2i(d.x, 0)
			var b := tile + Vector2i(0, d.y)
			if a.x < 0 or a.x >= w or b.y < 0 or b.y >= h:
				continue
			var ai := a.y * w + a.x
			var bi := b.y * w + b.x
			if best[ai] != INF:
				_relax(solid, cost_map, w, source.radius, best, heap_d, heap_i, ai, bi, b - a)
			if best[bi] != INF:
				_relax(solid, cost_map, w, source.radius, best, heap_d, heap_i, bi, ai, a - b)
	var newly := PackedInt32Array()
	_expand(solid, cost_map, w, h, source.radius, best, heap_d, heap_i, source.covered, newly)
	if newly.is_empty():
		return true
	version += 1
	var counts: PackedInt32Array = _counts.get(source.service, PackedInt32Array())
	for i: int in newly:
		source.tiles.append(i)
		source.box = source.box.merge(Rect2i(Vector2i(i % w, i / w) - Vector2i.ONE, Vector2i(3, 3)))
		if source.active:
			counts[i] += 1
	if source.active:
		_counts[source.service] = counts
	return true


const DIAGONALS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Whether a covered neighbour's length came by a step from [param tile].
func _someone_steps_from(province: ProvinceSim, source: _Source, tile: Vector2i) -> bool:
	var w := province.grid.size.x
	var h := province.grid.size.y
	var i := tile.y * w + tile.x
	if source.best[i] == INF:
		return false
	for step: Vector2i in IsoMath.DIR_GRID_STEP:
		var n := tile + step
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
			continue
		if _came_from(source, i, n.y * w + n.x, step, n):
			return true
	return false


## Whether a covered length came by a diagonal step past the corner [param tile].
func _corner_used(province: ProvinceSim, source: _Source, tile: Vector2i) -> bool:
	var w := province.grid.size.x
	var h := province.grid.size.y
	for d: Vector2i in DIAGONALS:
		var a := tile + Vector2i(d.x, 0)
		var b := tile + Vector2i(0, d.y)
		if a.x < 0 or a.x >= w or b.y < 0 or b.y >= h:
			continue
		var ai := a.y * w + a.x
		var bi := b.y * w + b.x
		if source.best[ai] == INF or source.best[bi] == INF:
			continue
		if _came_from(source, ai, bi, b - a, b) or _came_from(source, bi, ai, a - b, a):
			return true
	return false


## Whether the length of [param to] (one [param step] from [param from]) equals that step with
## the reach cost before this update: then it may have come that way.
func _came_from(source: _Source, from: int, to: int, step: Vector2i, to_tile: Vector2i) -> bool:
	if source.best[to] == INF or to == source.start.y * _width + source.start.x:
		return false
	var cost: float = _dirty_tiles.get(to_tile, cost_map[to])
	return source.best[to] == source.best[from] + step_length(step) * cost


func _uncover(source: _Source, i: int) -> void:
	version += 1
	source.best[i] = INF
	source.covered[i] = 0
	var at := source.tiles.find(i)
	if at >= 0:
		source.tiles.remove_at(at)
	if source.active:
		var counts: PackedInt32Array = _counts[source.service]
		counts[i] -= 1
		_counts[source.service] = counts


func _set_active(source: _Source, active: bool, size: Vector2i) -> void:
	if source.active == active:
		return
	source.active = active
	version += 1
	if not _counts.has(source.service):
		var empty := PackedInt32Array()
		empty.resize(size.x * size.y)
		_counts[source.service] = empty
	var counts: PackedInt32Array = _counts[source.service]
	var change := 1 if active else -1
	for i: int in source.tiles:
		counts[i] += change
	_counts[source.service] = counts


func _flood_source(province: ProvinceSim, building: BuildingState) -> _Source:
	full_floods += 1
	var size := province.grid.size
	var source := _Source.new()
	source.service = building.def.id
	source.start = building.entrance_tile()
	source.radius = building.def.service_radius
	var covered := PackedByteArray()
	covered.resize(size.x * size.y)
	var best := PackedFloat64Array()
	best.resize(size.x * size.y)
	best.fill(INF)
	var tiles := PackedInt32Array()
	_flood_into(province, source.start, source.radius, covered, best, tiles)
	var low := size
	var high := Vector2i(-1, -1)
	for i: int in tiles:
		var t := Vector2i(i % size.x, i / size.x)
		low = Vector2i(mini(low.x, t.x), mini(low.y, t.y))
		high = Vector2i(maxi(high.x, t.x), maxi(high.y, t.y))
	source.covered = covered
	source.best = best
	source.tiles = tiles
	if high.x >= 0:
		source.box = Rect2i(low - Vector2i.ONE, high - low + Vector2i(3, 3))
	return source


## Indices of the tiles a service at [param start] would reach (the build preview).
static func reach_of(province: ProvinceSim, start: Vector2i, radius: float) -> PackedInt32Array:
	var size := province.grid.size
	var covered := PackedByteArray()
	covered.resize(size.x * size.y)
	var best := PackedFloat64Array()
	best.resize(size.x * size.y)
	best.fill(INF)
	var tiles := PackedInt32Array()
	_flood_into(province, start, radius, covered, best, tiles)
	return tiles


## Dijkstra over walkable tiles with movement costs, marking tiles within [param radius].
## Binary heap with lazy deletion (parallel arrays of distance and tile index), reading flat
## arrays: NavGrid.solid_map and the reach costs (cost_map, without trees).
static func _flood_into(province: ProvinceSim, start: Vector2i, radius: float, out: PackedByteArray,
		best: PackedFloat64Array, tiles: PackedInt32Array) -> void:
	var w := province.grid.size.x
	var start_i := start.y * w + start.x
	best[start_i] = 0.0
	var heap_d: PackedFloat64Array = [0.0]
	var heap_i: PackedInt32Array = [start_i]
	_expand(province.nav.solid_map, province.coverage.cost_map, w, province.grid.size.y, radius,
			best, heap_d, heap_i, out, tiles)


## Runs the Dijkstra from the heap: every tile popped is covered ([param newly] gets the ones
## not covered before), and shorter lengths spread to its neighbours.
static func _expand(solid: PackedByteArray, cost: PackedFloat64Array, w: int, h: int, radius: float,
		best: PackedFloat64Array, heap_d: PackedFloat64Array, heap_i: PackedInt32Array,
		covered: PackedByteArray, newly: PackedInt32Array) -> void:
	while not heap_d.is_empty():
		var d := heap_d[0]
		var current := heap_i[0]
		_pop(heap_d, heap_i)
		if d > best[current]:
			continue
		if covered[current] == 0:
			covered[current] = 1
			newly.append(current)
		var cx := current % w
		var cy := current / w
		for step: Vector2i in IsoMath.DIR_GRID_STEP:
			var nx := cx + step.x
			var ny := cy + step.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var next := ny * w + nx
			if solid[next] == 1:
				continue
			var length := 1.0
			if step.x != 0 and step.y != 0:
				# Both orthogonal neighbours are inside the map when the diagonal one is.
				if solid[cy * w + nx] == 1 or solid[ny * w + cx] == 1:
					continue
				length = 1.4142135
			var nd := d + length * cost[next]
			if nd <= radius and nd < best[next]:
				best[next] = nd
				_push(heap_d, heap_i, nd, next)


## One step from the covered tile [param from] to [param to] by [param step], as in _expand.
static func _relax(solid: PackedByteArray, cost: PackedFloat64Array, w: int, radius: float,
		best: PackedFloat64Array, heap_d: PackedFloat64Array, heap_i: PackedInt32Array, from: int,
		to: int, step: Vector2i) -> void:
	if solid[to] == 1:
		return
	var length := 1.0
	if step.x != 0 and step.y != 0:
		var fx := from % w
		var fy := from / w
		if solid[fy * w + fx + step.x] == 1 or solid[(fy + step.y) * w + fx] == 1:
			return
		length = 1.4142135
	var nd := best[from] + length * cost[to]
	if nd <= radius and nd < best[to]:
		best[to] = nd
		_push(heap_d, heap_i, nd, to)


static func _push(heap_d: PackedFloat64Array, heap_i: PackedInt32Array, d: float, t: int) -> void:
	heap_d.append(d)
	heap_i.append(t)
	var i := heap_d.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap_d[parent] <= heap_d[i]:
			break
		_swap(heap_d, heap_i, i, parent)
		i = parent


static func _pop(heap_d: PackedFloat64Array, heap_i: PackedInt32Array) -> void:
	var last := heap_d.size() - 1
	_swap(heap_d, heap_i, 0, last)
	heap_d.resize(last)
	heap_i.resize(last)
	var i := 0
	while true:
		var smallest := i
		var left := 2 * i + 1
		if left < last and heap_d[left] < heap_d[smallest]:
			smallest = left
		if left + 1 < last and heap_d[left + 1] < heap_d[smallest]:
			smallest = left + 1
		if smallest == i:
			return
		_swap(heap_d, heap_i, i, smallest)
		i = smallest


static func _swap(heap_d: PackedFloat64Array, heap_i: PackedInt32Array, a: int, b: int) -> void:
	var d := heap_d[a]
	heap_d[a] = heap_d[b]
	heap_d[b] = d
	var t := heap_i[a]
	heap_i[a] = heap_i[b]
	heap_i[b] = t


static func step_length(step: Vector2i) -> float:
	return 1.4142135 if step.x != 0 and step.y != 0 else 1.0

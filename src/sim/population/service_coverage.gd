class_name ServiceCoverage
extends RefCounted
## Which tiles each service (well...) reaches, measured as path length from the service
## building's entrance (GDD §3.2). Recomputed when the map or the service buildings change.

## Service building def id -> how many sources cover each tile.
var _counts: Dictionary[StringName, PackedInt32Array] = {}
## Source building id -> its last flood (_Source). Kept while the building stands, also while
## it does not serve (a tavern without drinks), so it can serve again without a new flood.
var _sources: Dictionary[int, _Source] = {}
## Tiles whose walkability or walking cost changed since the last update.
var _dirty_tiles: Dictionary[Vector2i, bool] = {}
## Walking cost per tile for service reach (index y * width + x): roads, fields and terrain,
## without trees (ProvinceSim.refresh_tile).
var cost_map: PackedFloat64Array = PackedFloat64Array()
var _width: int = 0
## Buildings with a service radius, rebuilt when buildings come or go.
var _service_buildings: Array[BuildingState] = []
var _buildings_version: int = -1
var _solid_version: int = -1


class _Source:
	var service: StringName
	var start: Vector2i
	var radius: float
	## Covered tile indices, and the same as a flag per tile.
	var tiles: PackedInt32Array
	var covered: PackedByteArray
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


## The reach cost of [param tile] is [param cost] now; [param solid_changed] when people can
## walk there now and could not before, or the other way round (ProvinceSim.refresh_tile).
func set_tile(tile: Vector2i, cost: float, solid_changed: bool) -> void:
	var i := tile.y * _width + tile.x
	if solid_changed or cost_map[i] != cost:
		cost_map[i] = cost
		_dirty_tiles[tile] = true


## Brings the coverage up to date. A source floods again only when a changed tile touches
## what it covers (the flood reads only covered tiles and their neighbours), so the result is
## the same as flooding every source from scratch (a loaded game matches the running one,
## ARCHITECTURE §9.3 M4b-3).
func update(province: ProvinceSim) -> void:
	var size := province.grid.size
	var check := false
	if not _dirty_tiles.is_empty():
		for source: _Source in _sources.values():
			if not source.stale and _touched(source, size):
				source.stale = true
				check = true
		_dirty_tiles.clear()
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


func _touched(source: _Source, size: Vector2i) -> bool:
	for tile: Vector2i in _dirty_tiles:
		if not source.box.has_point(tile):
			continue
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var t := tile + Vector2i(dx, dy)
				if t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y \
						and source.covered[t.y * size.x + t.x] == 1:
					return true
	return false


func _set_active(source: _Source, active: bool, size: Vector2i) -> void:
	if source.active == active:
		return
	source.active = active
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
	var size := province.grid.size
	var source := _Source.new()
	source.service = building.def.id
	source.start = building.entrance_tile()
	source.radius = building.def.service_radius
	var covered := PackedByteArray()
	covered.resize(size.x * size.y)
	flood(province, source.start, source.radius, covered)
	var tiles := PackedInt32Array()
	var low := size
	var high := Vector2i(-1, -1)
	for i: int in covered.size():
		if covered[i] == 1:
			tiles.append(i)
			var t := Vector2i(i % size.x, i / size.x)
			low = Vector2i(mini(low.x, t.x), mini(low.y, t.y))
			high = Vector2i(maxi(high.x, t.x), maxi(high.y, t.y))
	source.covered = covered
	source.tiles = tiles
	if high.x >= 0:
		source.box = Rect2i(low - Vector2i.ONE, high - low + Vector2i(3, 3))
	return source


## Dijkstra over walkable tiles with movement costs, marking tiles within [param radius].
## Binary heap with lazy deletion (parallel arrays of distance and tile index), reading flat
## arrays: NavGrid.solid_map and the reach costs (cost_map, without trees).
static func flood(province: ProvinceSim, start: Vector2i, radius: float, out: PackedByteArray) -> void:
	var w := province.grid.size.x
	var h := province.grid.size.y
	var solid := province.nav.solid_map
	var cost := province.coverage.cost_map
	var best := PackedFloat64Array()
	best.resize(w * h)
	best.fill(INF)
	var start_i := start.y * w + start.x
	best[start_i] = 0.0
	var heap_d: PackedFloat64Array = [0.0]
	var heap_i: PackedInt32Array = [start_i]
	while not heap_d.is_empty():
		var d := heap_d[0]
		var current := heap_i[0]
		_pop(heap_d, heap_i)
		if d > best[current]:
			continue
		out[current] = 1
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

class_name ServiceCoverage
extends RefCounted
## Which tiles each service (well...) reaches, measured as path length from the service
## building's entrance (GDD §3.2). Recomputed when the map or the service buildings change.

## Service building def id -> covered flag per tile.
var _covered: Dictionary[StringName, PackedByteArray] = {}
var _nav_version: int = -1
var _signature: String = ""


func covers(service: StringName, tile: Vector2i, size: Vector2i) -> bool:
	var map: PackedByteArray = _covered.get(service, PackedByteArray())
	if map.is_empty() or tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return false
	return map[tile.y * size.x + tile.x] == 1


## Covered flag per tile (view overlay); empty when nothing provides the service.
func map_of(service: StringName) -> PackedByteArray:
	return _covered.get(service, PackedByteArray())


func update(province: ProvinceSim) -> void:
	var sources: Array[BuildingState] = []
	var parts := PackedStringArray()
	for building: BuildingState in province.buildings.all():
		if building.def.service_radius > 0 and building.is_complete():
			sources.append(building)
			parts.append("%d" % building.id)
	var signature := ",".join(parts)
	if signature == _signature and province.nav.version == _nav_version:
		return
	_signature = signature
	_nav_version = province.nav.version
	_covered.clear()
	for source: BuildingState in sources:
		var id := source.def.id
		if not _covered.has(id):
			var empty := PackedByteArray()
			empty.resize(province.grid.size.x * province.grid.size.y)
			_covered[id] = empty
		flood(province, source.entrance_tile(), source.def.service_radius, _covered[id])


## Dijkstra over walkable tiles with movement costs, marking tiles within [param radius].
## Binary heap with lazy deletion (parallel arrays of distance and tile).
static func flood(province: ProvinceSim, start: Vector2i, radius: float, out: PackedByteArray) -> void:
	var size := province.grid.size
	var best: Dictionary[Vector2i, float] = {start: 0.0}
	var heap_d: PackedFloat64Array = [0.0]
	var heap_t: Array[Vector2i] = [start]
	while not heap_d.is_empty():
		var d := heap_d[0]
		var current := heap_t[0]
		_pop(heap_d, heap_t)
		if d > best[current]:
			continue
		out[current.y * size.x + current.x] = 1
		for step: Vector2i in IsoMath.DIR_GRID_STEP:
			var next := current + step
			if not province.nav.is_walkable(next):
				continue
			if step.x != 0 and step.y != 0 and (not province.nav.is_walkable(current + Vector2i(step.x, 0)) \
					or not province.nav.is_walkable(current + Vector2i(0, step.y))):
				continue
			var nd := d + step_length(step) * province.nav.get_cost(next)
			if nd <= radius and nd < best.get(next, INF):
				best[next] = nd
				_push(heap_d, heap_t, nd, next)


static func _push(heap_d: PackedFloat64Array, heap_t: Array[Vector2i], d: float, t: Vector2i) -> void:
	heap_d.append(d)
	heap_t.append(t)
	var i := heap_d.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap_d[parent] <= heap_d[i]:
			break
		_swap(heap_d, heap_t, i, parent)
		i = parent


static func _pop(heap_d: PackedFloat64Array, heap_t: Array[Vector2i]) -> void:
	var last := heap_d.size() - 1
	_swap(heap_d, heap_t, 0, last)
	heap_d.resize(last)
	heap_t.resize(last)
	var i := 0
	while true:
		var smallest := i
		for child: int in [2 * i + 1, 2 * i + 2]:
			if child < last and heap_d[child] < heap_d[smallest]:
				smallest = child
		if smallest == i:
			return
		_swap(heap_d, heap_t, i, smallest)
		i = smallest


static func _swap(heap_d: PackedFloat64Array, heap_t: Array[Vector2i], a: int, b: int) -> void:
	var d := heap_d[a]
	heap_d[a] = heap_d[b]
	heap_d[b] = d
	var t := heap_t[a]
	heap_t[a] = heap_t[b]
	heap_t[b] = t


static func step_length(step: Vector2i) -> float:
	return 1.4142135 if step.x != 0 and step.y != 0 else 1.0

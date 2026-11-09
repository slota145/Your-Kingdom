class_name WorldNav
extends RefCounted
## Ways across the world map (ROADMAP M8 part 2): the parchment cut into square cells, each
## land (the province it lies in) or sea. Armies walk over land cells, fleets sail over sea
## cells; a way is found by A* over the cells (8 directions, no cutting corners) and then
## straightened (a waypoint only where the straight line would leave its kind of ground).
## Made from the world's provinces and kept for the world (it is never saved: the provinces
## make the same cells again).

## Cell size in parchment pixels.
const CELL := 20.0
const SEA := 0

var size: Vector2i = Vector2i.ZERO
## Province id per cell (y * size.x + x), SEA for water.
var cells: PackedInt32Array = PackedInt32Array()

## Made navs by the key of their world (provinces and size), shared by every Simulation.
static var _made: Dictionary[String, WorldNav] = {}


## The nav of [param world] (made once per world).
static func of(world: WorldSim, data: DataRegistry) -> WorldNav:
	var def := data.get_world(world.world_id)
	if def == null:
		return null
	var key := "%s|%d|%s" % [world.world_id, world.provinces.size(), def.size]
	for id: int in world.ids():
		var pdef := world.def_of(id, data)
		if pdef != null and not pdef.outline.is_empty():
			key += "|%s" % pdef.outline[0]
			break
	if not _made.has(key):
		_made[key] = WorldNav.build(world, data, def.size)
	return _made[key]


static func build(world: WorldSim, data: DataRegistry, area: Vector2) -> WorldNav:
	var nav := WorldNav.new()
	nav.size = Vector2i(ceili(area.x / CELL), ceili(area.y / CELL))
	nav.cells.resize(nav.size.x * nav.size.y)
	nav.cells.fill(SEA)
	for id: int in world.ids():
		var def := world.def_of(id, data)
		if def == null or def.outline.size() < 3:
			continue
		var box := Rect2(def.outline[0], Vector2.ZERO)
		for p: Vector2 in def.outline:
			box = box.expand(p)
		var lo := Vector2i((box.position / CELL).floor()).maxi(0)
		var hi := Vector2i((box.end / CELL).ceil()).min(nav.size - Vector2i.ONE)
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				if Geometry2D.is_point_in_polygon(nav.center(Vector2i(x, y)), def.outline):
					nav.cells[y * nav.size.x + x] = id
	return nav


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / CELL), 0, size.x - 1), clampi(floori(p.y / CELL), 0, size.y - 1))


func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The province under [param p] (parchment pixels), SEA (0) for water.
func province_at(p: Vector2) -> int:
	var c := cell_of(p)
	return cells[c.y * size.x + c.x]


func is_sea(p: Vector2) -> bool:
	return province_at(p) == SEA


func _open(cell: Vector2i, sea: bool) -> bool:
	if not inside(cell):
		return false
	return (cells[cell.y * size.x + cell.x] == SEA) == sea


## The middle of the cell of the wanted kind (sea or land) nearest [param p]; [param p]
## itself when it lies on that kind already; Vector2.INF when there is none within reach.
func nearest(p: Vector2, sea: bool, reach: int = 40) -> Vector2:
	var c := cell_of(p)
	if _open(c, sea):
		return p
	var best := Vector2.INF
	var best_d := INF
	for r: int in range(1, reach + 1):
		for y: int in range(c.y - r, c.y + r + 1):
			for x: int in range(c.x - r, c.x + r + 1):
				if absi(x - c.x) != r and absi(y - c.y) != r:
					continue
				var cell := Vector2i(x, y)
				if _open(cell, sea):
					var d := center(cell).distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = center(cell)
		if best != Vector2.INF:
			return best
	return best


## The way from [param from] to [param to] over sea ([param sea]) or land cells: waypoints after
## [param from], [param to] last; [] when there is none (or [param to] is not of that kind).
func find_path(from: Vector2, to: Vector2, sea: bool) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := cell_of(from)
	var goal := cell_of(to)
	if not _open(goal, sea):
		return result
	if not _open(start, sea):
		var near := nearest(from, sea, 3)
		if near == Vector2.INF:
			return result
		start = cell_of(near)
	if start == goal:
		result.append(to)
		return result
	var cells_path := _astar(start, goal, sea)
	if cells_path.is_empty():
		return result
	# Straighten: from each anchor go to the farthest cell still in a straight line.
	var anchor := from
	var k := 0
	while k < cells_path.size() - 1:
		var far := k
		for j: int in range(cells_path.size() - 1, k, -1):
			if line_open(anchor, center(cells_path[j]), sea):
				far = j
				break
		if far == k:
			far = k + 1
		if far >= cells_path.size() - 1:
			break
		anchor = center(cells_path[far])
		result.append(anchor)
		k = far
	result.append(to)
	return result


## Whether the straight line from [param a] to [param b] stays on sea ([param sea]) or land.
func line_open(a: Vector2, b: Vector2, sea: bool) -> bool:
	var steps := maxi(ceili(a.distance_to(b) / (CELL * 0.4)), 1)
	for i: int in range(1, steps):
		if not _open(cell_of(a.lerp(b, i / float(steps))), sea):
			return false
	return true


## Length of a way (parchment pixels) from [param from] along [param points].
static func length_of(from: Vector2, points: Array[Vector2]) -> float:
	var total := 0.0
	var prev := from
	for p: Vector2 in points:
		total += prev.distance_to(p)
		prev = p
	return total


const _STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func _astar(start: Vector2i, goal: Vector2i, sea: bool) -> Array[Vector2i]:
	var w := size.x
	var cost := PackedFloat32Array()
	cost.resize(size.x * size.y)
	cost.fill(INF)
	var came := PackedInt32Array()
	came.resize(size.x * size.y)
	came.fill(-1)
	var s := start.y * w + start.x
	var g := goal.y * w + goal.x
	cost[s] = 0.0
	# A binary heap of [priority, index].
	var heap_p := PackedFloat32Array([_h(start, goal)])
	var heap_i := PackedInt32Array([s])
	while not heap_i.is_empty():
		var here := heap_i[0]
		var here_p := heap_p[0]
		_pop(heap_p, heap_i)
		if here == g:
			break
		var hc := Vector2i(here % w, here / w)
		if here_p > cost[here] + _h(hc, goal) + 0.001:
			continue
		for step: Vector2i in _STEPS:
			var nc := hc + step
			if not _open(nc, sea):
				continue
			if step.x != 0 and step.y != 0 and (not _open(hc + Vector2i(step.x, 0), sea) \
					or not _open(hc + Vector2i(0, step.y), sea)):
				continue
			var n := nc.y * w + nc.x
			var c := cost[here] + (1.4142 if step.x != 0 and step.y != 0 else 1.0)
			if c < cost[n]:
				cost[n] = c
				came[n] = here
				_push(heap_p, heap_i, c + _h(nc, goal), n)
	var result: Array[Vector2i] = []
	if came[g] == -1:
		return result
	var at := g
	while at != s:
		result.push_front(Vector2i(at % w, at / w))
		at = came[at]
	result.push_front(start)
	return result


static func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return maxi(dx, dy) + 0.4142 * mini(dx, dy)


static func _push(p: PackedFloat32Array, i: PackedInt32Array, priority: float, index: int) -> void:
	p.append(priority)
	i.append(index)
	var k := p.size() - 1
	while k > 0:
		var parent := (k - 1) / 2
		if p[parent] <= p[k]:
			break
		var tp := p[parent]
		p[parent] = p[k]
		p[k] = tp
		var ti := i[parent]
		i[parent] = i[k]
		i[k] = ti
		k = parent


static func _pop(p: PackedFloat32Array, i: PackedInt32Array) -> void:
	var last := p.size() - 1
	p[0] = p[last]
	i[0] = i[last]
	p.resize(last)
	i.resize(last)
	var k := 0
	while true:
		var l := k * 2 + 1
		var r := l + 1
		var m := k
		if l < last and p[l] < p[m]:
			m = l
		if r < last and p[r] < p[m]:
			m = r
		if m == k:
			break
		var tp := p[m]
		p[m] = p[k]
		p[k] = tp
		var ti := i[m]
		i[m] = i[k]
		i[k] = ti
		k = m

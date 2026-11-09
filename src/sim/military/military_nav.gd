class_name MilitaryNav
extends RefCounted
## Where fighters can walk (M7 part 2, ARCHITECTURE §10): on the ground and on the wall-walk,
## and how they get from one to the other.
## - [member wall_nav]: the crown of stone walls, wedges, gatehouse and tower tops,
## - [member enemy_nav]: the ground for an enemy: like the town's, but closed gates block it,
## - [member siege_nav]: the ground with walls and closed gates as (costly) passable tiles: the
##   way an enemy would break through; the first wall on it is what he attacks,
## - portals between the ground and the wall-walk: stairs and ladders (for everybody), the
##   door of a tower and the passage of a gatehouse (inner stairs, the owner's people only).
## [method route] finds a walk over both levels through at most a few portals.

const GROUND := 0
const WALL := 1
## Portal kinds: a ramp walked up (stairs, ladder), or inner stairs (tower, gatehouse) taken
## out of sight.
const RAMP := 0
const INSIDE := 1
## Walking cost of breaking through (siege_nav): a palisade, a stone wall or a closed gate.
const BREAK_PALISADE := 6.0
const BREAK_STONE := 16.0
const BREAK_GATE := 4.0   # per passage tile: a gate is 3 of them

var wall_nav: NavGrid
var enemy_nav: NavGrid
var siege_nav: NavGrid
## Ladders against walls: ground tile -> the wall tile it leans on. Saved.
var ladders: Dictionary[Vector2i, Vector2i] = {}

var _stairs: Array[Vector2i] = []
var _stairs_version: int = -1


class Portal:
	extends RefCounted
	var ground: Vector2i
	var top: Vector2i
	var kind: int
	## Only the town's own people use it (inner stairs of its towers and gatehouses).
	var owner_only: bool

	func _init(g: Vector2i, t: Vector2i, k: int, own: bool) -> void:
		ground = g
		top = t
		kind = k
		owner_only = own


func _init(size: Vector2i) -> void:
	wall_nav = NavGrid.new(size)
	wall_nav.set_solid_rect(Rect2i(Vector2i.ZERO, size), true)
	enemy_nav = NavGrid.new(size)
	siege_nav = NavGrid.new(size)


## Updates the three grids at [param tile] (ProvinceSim.refresh_tile).
func refresh_tile(province: ProvinceSim, tile: Vector2i, nav_solid: bool, cost: float) -> void:
	var walls := province.walls
	wall_nav.set_solid(tile, not walls.is_walkway(tile))
	var closed_gate := false
	if not province.passages.is_empty() and province.passages.has(tile):
		var gate := province.buildings.get_building(province.passages[tile])
		closed_gate = gate != null and gate.def.is_gate() and not gate.is_broken()
	enemy_nav.set_solid(tile, nav_solid or closed_gate)
	if not is_equal_approx(enemy_nav.get_cost(tile), cost):
		enemy_nav.set_cost(tile, cost)
	var siege_cost := cost
	var siege_solid := nav_solid
	if closed_gate:
		siege_cost = BREAK_GATE
	elif walls.kind(tile) == Walls.PALISADE:
		siege_solid = false
		siege_cost = BREAK_PALISADE
	elif walls.kind(tile) == Walls.STONE:
		siege_solid = false
		siege_cost = BREAK_STONE
	siege_nav.set_solid(tile, siege_solid or (nav_solid and walls.wedges.has(tile)))
	if not is_equal_approx(siege_nav.get_cost(tile), siege_cost):
		siege_nav.set_cost(tile, siege_cost)


## The ground grid of [param faction]: the town's own (gates open) or an enemy's.
func ground_nav(province: ProvinceSim, faction: int) -> NavGrid:
	return province.nav if faction == province.home_faction else enemy_nav


func nav_of(province: ProvinceSim, level: int, faction: int) -> NavGrid:
	return wall_nav if level == WALL else ground_nav(province, faction)


## Every way between the ground and the wall-walk that [param faction] may use.
func portals(province: ProvinceSim, faction: int) -> Array[Portal]:
	var result: Array[Portal] = []
	var walls := province.walls
	if _stairs_version != walls.version:
		_stairs_version = walls.version
		_stairs.clear()
		for tile: Vector2i in walls.tiles():
			if walls.is_stairs(tile):
				_stairs.append(tile)
	for tile: Vector2i in _stairs:
		var top := walls.stairs_top(tile)
		if walls.is_walkway(top):
			result.append(Portal.new(tile, top, RAMP, false))
	for ground: Vector2i in ladders:
		if walls.is_walkway(ladders[ground]):
			result.append(Portal.new(ground, ladders[ground], RAMP, false))
	if faction != province.home_faction:
		return result
	for building: BuildingState in province.buildings.all():
		if not building.def.is_fort() or not building.is_complete():
			continue
		if building.def.is_gatehouse():
			var passage := building.passage_tiles()
			if passage.size() == 3:
				var d := building.def.door_dir(building.orientation)
				var across := Vector2i(d.y, d.x).abs()
				result.append(Portal.new(passage[1], passage[1] + across, INSIDE, true))
		else:
			result.append(Portal.new(building.door_front_tile(), building.entrance_tile(), INSIDE, true))
	return result


## A walk from [param from] on level [param from_level] to [param to] on [param to_level]
## for [param faction]: [tiles, levels], or [] when there is none. Through at most
## [constant MAX_PORTALS] portals, the cheapest by straight-line distance between them.
const MAX_PORTALS := 3


func route(province: ProvinceSim, from: Vector2i, from_level: int, to: Vector2i, to_level: int,
		faction: int) -> Array:
	var start_nav := nav_of(province, from_level, faction)
	var goal_nav := nav_of(province, to_level, faction)
	if not start_nav.is_walkable(from) or not goal_nav.is_walkable(to):
		return []
	if from_level == to_level and start_nav.area_of(from) == start_nav.area_of(to):
		var direct := start_nav.find_path(from, to)
		return [direct, _levels(direct.size(), from_level)] if not direct.is_empty() else []
	var list := portals(province, faction)
	if list.is_empty():
		return []
	var ground := ground_nav(province, faction)
	# Dijkstra over portal ends. Node = portal index * 2 + side (0 ground end, 1 top end).
	var area := func(level: int, tile: Vector2i) -> int:
		return (wall_nav if level == WALL else ground).area_of(tile)
	var end_tile := func(i: int) -> Vector2i:
		return list[i / 2].ground if i % 2 == 0 else list[i / 2].top
	var target_area: int = area.call(to_level, to)
	var count := list.size() * 2
	var best := PackedFloat32Array()
	best.resize(count)
	best.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(count)
	prev.fill(-1)
	var hops := PackedInt32Array()
	hops.resize(count)
	var done := PackedByteArray()
	done.resize(count)
	var from_area: int = area.call(from_level, from)
	# Entering a portal from the start.
	for i: int in count:
		var level := i % 2
		var t: Vector2i = end_tile.call(i)
		if level == from_level and area.call(level, t) == from_area:
			best[i] = _dist(from, t)
			prev[i] = -2
	var finish := -1
	var finish_cost := INF
	while true:
		var u := -1
		for i: int in count:
			if done[i] == 0 and best[i] < INF and (u < 0 or best[i] < best[u]):
				u = i
		if u < 0 or best[u] >= finish_cost:
			break
		done[u] = 1
		# Cross the portal.
		var other := u ^ 1
		var cross: float = best[u] + 1.0
		if hops[u] < MAX_PORTALS and cross < best[other] and done[other] == 0:
			best[other] = cross
			prev[other] = u
			hops[other] = hops[u] + 1
		# Just through a portal: walk on to the target, or to another portal end in this area.
		if prev[u] < 0 or prev[u] != (u ^ 1):
			continue
		var level := u % 2
		var here: Vector2i = end_tile.call(u)
		var a: int = area.call(level, here)
		if level == to_level and a == target_area:
			var c: float = best[u] + _dist(here, to)
			if c < finish_cost:
				finish_cost = c
				finish = u
		for j: int in count:
			if j == u or done[j] == 1 or j % 2 != level:
				continue
			var t: Vector2i = end_tile.call(j)
			if area.call(level, t) != a:
				continue
			var c: float = best[u] + _dist(here, t)
			if c < best[j]:
				best[j] = c
				prev[j] = u
				hops[j] = hops[u]
	if finish < 0:
		return []
	# The portal ends in order, then the walks between them.
	var chain: Array[int] = []
	var at := finish
	while at >= 0:
		chain.push_front(at)
		at = prev[at]
	var tiles: Array[Vector2i] = []
	var levels := PackedByteArray()
	var cur := from
	var cur_level := from_level
	for k: int in chain.size():
		var node := chain[k]
		var t: Vector2i = end_tile.call(node)
		var level := node % 2
		if level == cur_level:
			var leg := nav_of(province, level, faction).find_path(cur, t)
			if leg.is_empty():
				return []
			_append(tiles, levels, leg, level)
		else:
			# Through the portal: the far end, on its own level.
			tiles.append(t)
			levels.append(level)
		cur = t
		cur_level = level
	var last := nav_of(province, to_level, faction).find_path(cur, to)
	if last.is_empty():
		return []
	_append(tiles, levels, last, to_level)
	return [tiles, levels]


static func _append(tiles: Array[Vector2i], levels: PackedByteArray, leg: Array[Vector2i], level: int) -> void:
	for t: Vector2i in leg:
		if not tiles.is_empty() and tiles.back() == t and levels[levels.size() - 1] == level:
			continue
		tiles.append(t)
		levels.append(level)


static func _levels(n: int, level: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(n)
	result.fill(level)
	return result


static func _dist(a: Vector2i, b: Vector2i) -> float:
	var d := (a - b).abs()
	return maxi(d.x, d.y) + 0.41 * mini(d.x, d.y)


## The portal whose ends are [param a] and [param b] (in either order), or null: a step
## between levels in a walk.
func portal_between(province: ProvinceSim, a: Vector2i, b: Vector2i, faction: int) -> Portal:
	for p: Portal in portals(province, faction):
		if (p.ground == a and p.top == b) or (p.ground == b and p.top == a):
			return p
	return null


func to_dict() -> Dictionary:
	var list := []
	for ground: Vector2i in ladders:
		list.append([SimCodec.vec2i(ground), SimCodec.vec2i(ladders[ground])])
	return {"ladders": list}


func load_dict(d: Dictionary) -> void:
	for pair: Variant in d.get("ladders", []):
		ladders[SimCodec.to_vec2i(pair[0])] = SimCodec.to_vec2i(pair[1])

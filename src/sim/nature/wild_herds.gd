class_name WildHerds
extends RefCounted
## Wild animals of a province (E2 part 2): small herds of deer and boar on the forest and the
## meadows, away from the town. A herd is a spot on the map with a number of animals; it
## wanders a few tiles now and then, grows slowly up to its size, and new herds come out of the
## woods while the province has fewer than its forest can feed. A hunter takes one animal at a
## time; the rest of the herd flees. The animals themselves walk around the spot in the view.
##
## No random numbers are kept: every choice hashes the tick with the herd's id, so a province
## replays the same after a save.

## Kind -> [herd size limit, animals of a new herd].
const KINDS: Dictionary[StringName, Array] = {&"deer": [5, 3], &"boar": [4, 2]}
## Seconds between the herd's wanderings (the herd's id shifts it in this window).
const WANDER_SECONDS := 30.0
const WANDER_SPREAD := 20.0
## Tiles of one wandering, of a flight from a hunter.
const WANDER_TILES := 3
const FLEE_TILES := 7
## Seconds for a herd to gain an animal while below its size.
const BREED_SECONDS := 120.0
## Seconds between the checks for a new herd coming out of the woods.
const SPAWN_SECONDS := 60.0
## Forest and meadow tiles per herd the province feeds, and the limits of that number.
const TILES_PER_HERD := 150
const MIN_HERDS := 2
const MAX_HERDS := 8
## A herd keeps this many tiles away from buildings (it moves off when the town grows to it).
const SHY_TILES := 5
## Herds keep to the forest's edge: a forest this near.
const EDGE_TILES := 3
## Terrain the herds live on.
const HOMES: Array[StringName] = [&"forest", &"grass", &"meadow"]


class Herd:
	extends RefCounted
	var id: int
	var kind: StringName
	var tile: Vector2i
	var count: int
	## Tick of the next wandering, of the next young.
	var move_at: int
	var breed_at: int
	## Agent hunting this herd (one hunter at a time), 0 = none.
	var hunter: int = 0

	func to_list() -> Array:
		return [id, String(kind), tile.x, tile.y, count, move_at, breed_at, hunter]

	static func from_list(e: Array) -> Herd:
		var h := Herd.new()
		h.id = int(e[0])
		h.kind = StringName(String(e[1]))
		h.tile = Vector2i(int(e[2]), int(e[3]))
		h.count = int(e[4])
		h.move_at = int(e[5])
		h.breed_at = int(e[6])
		h.hunter = int(e[7]) if e.size() > 7 else 0
		return h


var herds: Dictionary[int, Herd] = {}
var next_id: int = 1
## Tick of the next check for a new herd.
var spawn_at: int = 0
## The woods were filled once (a new map, or a save from before E2 on its first second).
var populated: bool = false
## Forest and meadow tiles of the map, counted once (derived, not saved).
var _homes: int = -1
## Centres of the province's buildings, refreshed when they change (derived, not saved).
var _centres: PackedInt32Array = PackedInt32Array()
var _centres_version: int = -1


func all() -> Array[Herd]:
	var result: Array[Herd] = []
	var ids: Array[int] = []
	ids.assign(herds.keys())
	ids.sort()
	for id: int in ids:
		result.append(herds[id])
	return result


func animals() -> int:
	var sum := 0
	for herd: Herd in herds.values():
		sum += herd.count
	return sum


## How many herds the forest and meadows of [param province] feed.
func target(province: ProvinceSim) -> int:
	if _homes < 0:
		_homes = 0
		for y: int in province.grid.size.y:
			for x: int in province.grid.size.x:
				if _is_home(province, Vector2i(x, y)):
					_homes += 1
	if _homes < TILES_PER_HERD / 2:
		return 0
	return clampi(_homes / TILES_PER_HERD, MIN_HERDS, MAX_HERDS)


## Once a second: herds wander, grow and come out of the woods.
func update(province: ProvinceSim) -> void:
	if not populated:
		populate(province)
	var tick := province.tick
	if tick >= spawn_at:
		spawn_at = tick + SimClock.seconds_to_ticks(SPAWN_SECONDS)
		if herds.size() < target(province):
			_spawn(province, tick)
	for herd: Herd in all():
		if tick >= herd.breed_at:
			herd.breed_at = tick + SimClock.seconds_to_ticks(BREED_SECONDS)
			if herd.count < size_of(herd.kind):
				herd.count += 1
		if tick >= herd.move_at and herd.hunter == 0:
			_wander(province, herd, tick)


## A new province fills its woods at once (a map, a save from before E2).
func populate(province: ProvinceSim) -> void:
	populated = true
	var tick := province.tick
	for i: int in target(province):
		_spawn(province, tick + i)
	spawn_at = tick + SimClock.seconds_to_ticks(SPAWN_SECONDS)


static func size_of(kind: StringName) -> int:
	return int(KINDS[kind][0]) if KINDS.has(kind) else 1


## The nearest herd within [param radius] tiles (Chebyshev) of [param from] that nobody hunts.
func nearest(from: Vector2i, radius: int, hunter: int = 0) -> Herd:
	var best: Herd = null
	var best_d := 1 << 30
	for herd: Herd in all():
		if herd.count <= 0 or (herd.hunter != 0 and herd.hunter != hunter):
			continue
		var delta := herd.tile - from
		if maxi(absi(delta.x), absi(delta.y)) > radius:
			continue
		var d := delta.length_squared()
		if d < best_d:
			best = herd
			best_d = d
	return best


## One animal of [param herd] is shot at [param tick] from [param from]: it leaves the herd,
## the rest flees away from the hunter (the herd is gone when none is left).
func take_one(province: ProvinceSim, herd: Herd, from: Vector2i) -> void:
	herd.count -= 1
	herd.hunter = 0
	if herd.count <= 0:
		herds.erase(herd.id)
		province.events.emit(&"herd_changed", {"herd": herd.id})
		return
	var away := herd.tile - from
	var dir := Vector2(away).normalized() if away != Vector2i.ZERO else Vector2(1, 0)
	var goal := herd.tile + Vector2i((dir * FLEE_TILES).round())
	var spot := _free_spot_near(province, goal, 3, herd.id + province.tick)
	if spot != Agent.NO_TILE:
		herd.tile = spot
	herd.move_at = province.tick + SimClock.seconds_to_ticks(WANDER_SECONDS)
	province.events.emit(&"herd_changed", {"herd": herd.id})


func release_hunter(agent_id: int) -> void:
	for herd: Herd in herds.values():
		if herd.hunter == agent_id:
			herd.hunter = 0


func to_dict() -> Dictionary:
	var list: Array = []
	for herd: Herd in all():
		list.append(herd.to_list())
	return {"herds": list, "next": next_id, "spawn_at": spawn_at, "populated": populated}


static func from_dict(d: Dictionary) -> WildHerds:
	var w := WildHerds.new()
	for e: Variant in d.get("herds", []):
		var herd := Herd.from_list(e)
		w.herds[herd.id] = herd
	w.next_id = int(d.get("next", 1))
	w.spawn_at = int(d.get("spawn_at", 0))
	w.populated = bool(d.get("populated", false))
	return w


func _spawn(province: ProvinceSim, tick: int) -> void:
	var size := province.grid.size
	for attempt: int in 80:
		var h := _hash(next_id, tick, attempt)
		var tile := Vector2i(h % size.x, (h / size.x) % size.y)
		# In the open by the edge of a forest: where deer graze, seen and reached by a hunter.
		if not _is_free(province, tile) or not _is_open(province, tile) \
				or not _by_forest(province, tile) or _near_buildings(province, tile, SHY_TILES * 2):
			continue
		var herd := Herd.new()
		herd.id = next_id
		next_id += 1
		herd.kind = &"deer" if (h / 7) % 3 != 0 else &"boar"
		herd.tile = tile
		herd.count = int(KINDS[herd.kind][1])
		herd.move_at = tick + SimClock.seconds_to_ticks(WANDER_SECONDS + (h % 97) / 97.0 * WANDER_SPREAD)
		herd.breed_at = tick + SimClock.seconds_to_ticks(BREED_SECONDS)
		herds[herd.id] = herd
		province.events.emit(&"herd_changed", {"herd": herd.id})
		return


func _wander(province: ProvinceSim, herd: Herd, tick: int) -> void:
	var h := _hash(herd.id, tick, 0)
	herd.move_at = tick + SimClock.seconds_to_ticks(WANDER_SECONDS + (h % 97) / 97.0 * WANDER_SPREAD)
	var goal := herd.tile + Vector2i(h % (2 * WANDER_TILES + 1) - WANDER_TILES,
			(h / 13) % (2 * WANDER_TILES + 1) - WANDER_TILES)
	if _near_buildings(province, herd.tile, SHY_TILES):
		# The town has grown to the herd: it moves off, away from the nearest building.
		var away := herd.tile - _nearest_building(province, herd.tile)
		goal = herd.tile + Vector2i((Vector2(away).normalized() * (SHY_TILES + 2)).round())
	var spot := _free_spot_near(province, goal, 2, h)
	if spot != Agent.NO_TILE and spot != herd.tile:
		herd.tile = spot
		province.events.emit(&"herd_changed", {"herd": herd.id})


## A free home tile within [param radius] of [param goal] by a forest (open ground first: the
## herd grazes where it is seen, owner 2026-11-11), NO_TILE if none.
func _free_spot_near(province: ProvinceSim, goal: Vector2i, radius: int, salt: int) -> Vector2i:
	var best := Agent.NO_TILE
	var best_score := -1
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var tile := goal + Vector2i(dx, dy)
			if not _is_free(province, tile) or not _by_forest(province, tile) \
					or _near_buildings(province, tile, SHY_TILES):
				continue
			var score := (2 if _is_open(province, tile) else 1) * 100 \
					- (dx * dx + dy * dy) * 10 + _hash(salt, tile.x, tile.y) % 7
			if score > best_score:
				best = tile
				best_score = score
	return best


## Whether a forest lies within EDGE_TILES of [param tile] (or under it).
static func _by_forest(province: ProvinceSim, tile: Vector2i) -> bool:
	for dy: int in range(-EDGE_TILES, EDGE_TILES + 1):
		for dx: int in range(-EDGE_TILES, EDGE_TILES + 1):
			var t := tile + Vector2i(dx, dy)
			if province.grid.is_inside(t):
				var terrain := province.terrain_at(t)
				if terrain != null and terrain.id == &"forest":
					return true
	return false


## Grass or a meadow without a tree: the herd is seen there.
static func _is_open(province: ProvinceSim, tile: Vector2i) -> bool:
	var terrain := province.terrain_at(tile)
	return terrain != null and terrain.id != &"forest" and province.resources.def_at(tile) == null


func _is_free(province: ProvinceSim, tile: Vector2i) -> bool:
	return province.grid.is_inside(tile) and _is_home(province, tile) and not province.is_tile_solid(tile) \
			and not province.fields.has_field(tile) and not province.grid.has_road(tile) \
			and province.nav.is_walkable(tile)


static func _is_home(province: ProvinceSim, tile: Vector2i) -> bool:
	var terrain := province.terrain_at(tile)
	return terrain != null and HOMES.has(terrain.id) and province.grid.occupant(tile) == 0


func _near_buildings(province: ProvinceSim, tile: Vector2i, radius: int) -> bool:
	_refresh_centres(province)
	for i: int in range(0, _centres.size(), 2):
		if absi(_centres[i] - tile.x) <= radius and absi(_centres[i + 1] - tile.y) <= radius:
			return true
	return false


func _nearest_building(province: ProvinceSim, tile: Vector2i) -> Vector2i:
	_refresh_centres(province)
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for i: int in range(0, _centres.size(), 2):
		var c := Vector2i(_centres[i], _centres[i + 1])
		var d := (c - tile).length_squared()
		if d < best_d:
			best = c
			best_d = d
	return best


func _refresh_centres(province: ProvinceSim) -> void:
	if _centres_version == province.buildings.version:
		return
	_centres_version = province.buildings.version
	_centres.clear()
	for building: BuildingState in province.buildings.all():
		var c := building.origin + building.def.footprint / 2
		_centres.append(c.x)
		_centres.append(c.y)


static func _hash(a: int, b: int, c: int) -> int:
	return absi(hash([a, b, c]))

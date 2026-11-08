class_name NeutralTown
extends RefCounted
## Builds the small town of a neutral settlement (ROADMAP M6 part 3: 30-40 buildings, 60-80
## people) on its province map, the way the big test city of M4b-3 is built, but in game code:
## the map's start layout, then the buildings of ProvinceDef.town_buildings placed finished
## near the town hall (those working on trees, rocks or water near them), houses full, the
## first ProvinceDef.town_burghers of them burgher houses, farms with fields, storages with a
## little of everything. It is built deterministically from the province's data, so a game
## and its save give the same town.
##
## The town is kept like a province nobody looks at (ProvinceAbstract) but does not run while
## it is neutral (Simulation.step): it waits for the player as it is.

## Goods each storage of the town starts with.
const STOCK := {&"bread": 12, &"fish": 8, &"beer": 8, &"wood": 20, &"planks": 10, &"stone": 8,
		&"grain": 6}
## Fields a farm gets (hop farms too).
const FIELDS := 10
## Rings searched around an anchor for a free spot.
const SEARCH := 30


## Settles province [param id] of [param sim] as a neutral town; the runtime is frozen.
## [param layout]: another province's town to build there (the five-province benchmark).
static func build(sim: Simulation, id: int, layout: ProvinceDef = null) -> PackedStringArray:
	var def := sim.world.def_of(id, sim.data)
	var town_def := layout if layout != null else def
	var map := sim.data.get_map(sim.world.get_province(id).map_id)
	var problems := PackedStringArray()
	if def == null or map == null:
		problems.append("neutral town %d: no map" % id)
		return problems
	var town := ProvinceSim.new(sim.data, map.size_for(def.mirrored), SimEvents.new(), sim.ids)
	town.treasury = Treasury.new()
	town.tick = sim.clock.tick
	problems.append_array(town.load_map(map, def.mirrored, def.richness, false, def.rare_resource))
	# A map started from a ship (the Coast) has no town yet: no landing, no first building;
	# the town hall goes up first, inland from the beach.
	town.landing = null
	town.first_building = &""
	var hall := town.seat()
	var centre := town.grid.size / 2
	if hall == null and map.beach_tile != Agent.NO_TILE:
		centre = ProvinceSim._variant_tile(map.beach_tile, def.mirrored)
	if hall == null:
		hall = _place(town, sim.data.get_building(ProvinceSim.SEAT), centre)
	if hall != null:
		centre = hall.entrance_tile()
	var ids: Array[StringName] = []
	ids.assign(town_def.town_buildings.keys())
	ids.sort()
	var burghers := town_def.town_burghers
	for building_id: StringName in ids:
		var building_def := sim.data.get_building(building_id)
		if building_def == null:
			problems.append("neutral town: unknown building %s" % building_id)
			continue
		for i: int in int(town_def.town_buildings[building_id]):
			var placed := _place(town, building_def, _near_its_work(town, building_def, centre))
			if placed == null:
				problems.append("neutral town: no spot for %s" % building_id)
				continue
			if placed.house != null:
				_settle(placed, 2 if burghers > 0 else 1)
				burghers -= 1
	for building: BuildingState in town.buildings.all():
		if building.house != null and building.house.residents == 0:
			_settle(building, 1)
		if building.def.id == &"stockpile" and building.stock != null:
			for good: StringName in STOCK:
				building.stock.add(good, int(STOCK[good]))
	town.events.drain()
	town.treasury = sim.treasury
	sim.runtimes[id] = ProvinceAbstract.freeze(town, sim.clock.tick)
	return problems


static func _place(town: ProvinceSim, def: BuildingDef, near: Vector2i) -> BuildingState:
	for r: int in SEARCH:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				var origin := Vector2i(x, y)
				# A building by the water (a wharf) stands on the shore: no margin there.
				if def.needs_terrain_near == &"" and def.water_tiles.is_empty() \
						and not _free_with_margin(town, def, origin):
					continue
				for o: int in def.orientation_count():
					var front := def.door_front(origin, o)
					if not town.grid.is_inside(front) or not town.nav.is_walkable(front):
						continue
					if town.placement_error(def, origin, o) != &"":
						continue
					town.add_building(def, origin, true, o)
					var building := town.buildings.get_building(town.grid.occupant(origin))
					if def.id == &"farm" or def.id == &"hop_farm":
						_fields(town, building)
					return building
	return null


static func _free_with_margin(town: ProvinceSim, def: BuildingDef, origin: Vector2i) -> bool:
	for y: int in range(origin.y - 1, origin.y + def.footprint.y + 1):
		for x: int in range(origin.x - 1, origin.x + def.footprint.x + 1):
			var t := Vector2i(x, y)
			if not town.grid.is_inside(t) or town.grid.occupant(t) != 0 \
					or not town.nav.is_walkable(t) or town.fields.has_field(t):
				return false
	return true


static func _fields(town: ProvinceSim, farm: BuildingState) -> void:
	var left := FIELDS
	for r: int in range(1, farm.def.work_radius + 1):
		for y: int in range(farm.origin.y - r, farm.origin.y + farm.def.footprint.y + r):
			for x: int in range(farm.origin.x - r, farm.origin.x + farm.def.footprint.x + r):
				if left > 0 and town.field_error(farm.id, Vector2i(x, y)) == &"":
					town.add_field(farm.id, Vector2i(x, y))
					left -= 1


## A full house: peasants (level 1) or burghers (2), with a full pantry.
static func _settle(building: BuildingState, level: int) -> void:
	building.house.level = level
	building.supply.stack_limit = building.level_def().supply_units
	building.house.residents = building.capacity()
	building.house.happiness = 70.0
	for need: NeedDef in building.level_def().needs:
		for good: StringName in need.goods:
			building.supply.add(good, building.level_def().supply_units)


## [param near], or the nearest tile with what [param def] works on when nothing is in reach.
static func _near_its_work(town: ProvinceSim, def: BuildingDef, near: Vector2i) -> Vector2i:
	var node := &""
	if def.recipe != null:
		for step: StepDef in def.recipe.steps:
			if step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				node = (step as GoToStepDef).resource
	if node == &"" and def.needs_terrain_near == &"":
		return near
	var reach := maxi(def.work_radius, 3)
	var best := near
	var best_d := 1 << 30
	var size := town.grid.size
	for y: int in size.y:
		for x: int in size.x:
			var t := Vector2i(x, y)
			var hit := false
			if node != &"":
				hit = town.resources.has_node(t, node) and not town.resources.is_depleted(t)
			else:
				var terrain := town.terrain_at(t)
				hit = terrain != null and terrain.is_kind(def.needs_terrain_near)
			if not hit:
				continue
			var d := (t - near).length_squared()
			if d <= reach * reach:
				return near
			if d < best_d:
				best_d = d
				best = t
	return best


# --- Defences (M7 part 3) -----------------------------------------------------------------------

## Buildings this close to the town hall (tiles) are inside the ring of walls; farther ones
## (woodcutters at the forest, fishermen by the water) stay outside unless the ring meets them.
const CORE_RADIUS := 11
## Free ground kept between a building inside and the wall.
const RING_MARGIN := 2


## Gives the neutral town of province [param id] its walls (ProvinceDef.town_wall: a ring of
## palisade or stone around the town centre, with a gatehouse and town_towers towers) and its
## guards. Deterministic from the town as built, so a save from before M7 part 3 gets the same
## walls on its first second. Returns problems.
static func fortify(sim: Simulation, id: int) -> PackedStringArray:
	var problems := PackedStringArray()
	var settlement := sim.world.settlements.get(id) as NeutralSettlement
	var def := sim.world.def_of(id, sim.data)
	var town := sim.province_state(id)
	if settlement == null or def == null or town == null:
		return problems
	settlement.fortified = true
	settlement.guards = def.town_guards.duplicate()
	if def.town_wall == Walls.NONE:
		return problems
	var ring := wall_ring(town)
	if ring.is_empty():
		problems.append("neutral town %d: no ring for walls" % id)
		return problems
	var hall := town.seat()
	var gate := _place_gate(sim, town, ring, hall)
	if gate == null:
		problems.append("neutral town %d: no place for a gatehouse" % id)
	_place_towers(sim, town, ring, def.town_towers, gate)
	for tile: Vector2i in ring:
		if town.walls.fort_tiles.has(tile) or town.walls.kind(tile) != Walls.NONE:
			continue
		var terrain := town.terrain_at(tile)
		if terrain == null or not terrain.walkable or town.grid.occupant(tile) != 0:
			continue
		_clear_ground(town, tile)
		town.lay_wall(tile, def.town_wall)
	town.events.drain()
	return problems


## The ring of tiles around the town centre: the outer edge of the town's core (buildings near
## the hall, each with RING_MARGIN tiles around it), grown over any building it would cut.
## 4-connected, so nobody slips through diagonally.
static func wall_ring(town: ProvinceSim) -> Array[Vector2i]:
	var hall := town.seat()
	if hall == null:
		return []
	var centre := hall.entrance_tile()
	var core: Dictionary[int, bool] = {}
	for building: BuildingState in town.buildings.all():
		if (building.entrance_tile() - centre).length() <= CORE_RADIUS:
			core[building.id] = true
	var size := town.grid.size
	for attempt: int in 12:
		var inside := PackedByteArray()
		inside.resize(size.x * size.y)
		for building_id: int in core:
			for tile: Vector2i in town.buildings.get_building(building_id).tiles():
				for y: int in range(tile.y - RING_MARGIN, tile.y + RING_MARGIN + 1):
					for x: int in range(tile.x - RING_MARGIN, tile.x + RING_MARGIN + 1):
						if x >= 3 and y >= 3 and x < size.x - 3 and y < size.y - 3:
							inside[y * size.x + x] = 1
		var ring := _outer_edge(inside, size)
		var grown := false
		for tile: Vector2i in ring:
			var occupant := town.grid.occupant(tile)
			if occupant != 0 and not core.has(occupant):
				core[occupant] = true
				grown = true
		if not grown:
			return ring
	return []


## Tiles outside [param inside] (reached from the map's edge) that touch it, also diagonally.
static func _outer_edge(inside: PackedByteArray, size: Vector2i) -> Array[Vector2i]:
	var outside := PackedByteArray()
	outside.resize(size.x * size.y)
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	outside[0] = 1
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for d: Vector2i in Walls.DIRS:
			var n := t + d
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			var k := n.y * size.x + n.x
			if outside[k] == 1 or inside[k] == 1:
				continue
			outside[k] = 1
			queue.append(n)
	var ring: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			if outside[y * size.x + x] == 0:
				continue
			var touches := false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < size.x and ny < size.y and inside[ny * size.x + nx] == 1:
						touches = true
			if touches:
				ring.append(Vector2i(x, y))
	return ring


## Trees, roads and fields make way for a wall or a gatehouse.
static func _clear_ground(town: ProvinceSim, tile: Vector2i) -> void:
	if town.resources.has_node(tile):
		town.resources.clear(tile)
		town.refresh_tile(tile)
	if town.grid.has_road(tile):
		town.set_road(tile, false)
	if town.fields.has_field(tile):
		town.remove_field(tile)


## A gatehouse across a straight stretch of the ring, the one nearest the town hall's door
## whose outside leads off into the land.
static func _place_gate(sim: Simulation, town: ProvinceSim, ring: Array[Vector2i], hall: BuildingState) -> BuildingState:
	var def := sim.data.get_building(&"gatehouse")
	var on_ring: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in ring:
		on_ring[tile] = true
	var centre := hall.entrance_tile() if hall != null else town.grid.size / 2
	# Near the hall, and opening onto free land (no trees, water or buildings before it).
	var score: Dictionary[Vector2i, float] = {}
	for tile: Vector2i in ring:
		var blocked := 0
		for y: int in range(-3, 4):
			for x: int in range(-3, 4):
				var t := tile + Vector2i(x, y)
				if on_ring.has(t) or not town.grid.is_inside(t):
					continue
				if town.resources.has_node(t) or not town.nav.is_walkable(t):
					blocked += 1
		score[tile] = (tile - centre).length() + blocked * 2.0
	var candidates: Array[Vector2i] = ring.duplicate()
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return score[a] < score[b] or (score[a] == score[b] and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for tile: Vector2i in candidates:
		for orientation: int in 2:
			var along := Vector2i(1, 0) if orientation == 0 else Vector2i(0, 1)
			if not (on_ring.has(tile - along) and on_ring.has(tile + along)):
				continue
			var origin := tile - Vector2i(1, 1)
			for y: int in 3:
				for x: int in 3:
					var t := origin + Vector2i(x, y)
					if town.grid.occupant(t) == 0:
						_clear_ground(town, t)
			if town.placement_error(def, origin, orientation) == &"":
				return town.add_building(def, origin, true, orientation)
	return null


## [param count] towers on the ring, as far from the gate and from each other as can be.
static func _place_towers(sim: Simulation, town: ProvinceSim, ring: Array[Vector2i], count: int,
		gate: BuildingState) -> void:
	var def := sim.data.get_building(&"tower")
	var placed: Array[Vector2i] = []
	if gate != null:
		placed.append(gate.entrance_tile())
	for k: int in count:
		var best := Agent.NO_TILE
		var best_d := -1.0
		for tile: Vector2i in ring:
			var d := INF
			for other: Vector2i in placed:
				d = minf(d, (tile - other).length())
			if placed.is_empty():
				d = 0.0
			if d > best_d:
				for origin: Vector2i in [tile, tile - Vector2i(1, 0), tile - Vector2i(0, 1), tile - Vector2i(1, 1)]:
					var free := true
					for y: int in 2:
						for x: int in 2:
							if town.grid.occupant(origin + Vector2i(x, y)) != 0:
								free = false
					if free:
						best = tile
						best_d = d
						break
		if best == Agent.NO_TILE:
			return
		for origin: Vector2i in [best, best - Vector2i(1, 0), best - Vector2i(0, 1), best - Vector2i(1, 1)]:
			for y: int in 2:
				for x: int in 2:
					if town.grid.occupant(origin + Vector2i(x, y)) == 0:
						_clear_ground(town, origin + Vector2i(x, y))
			if town.placement_error(def, origin, 0) == &"":
				town.add_building(def, origin, true, 0)
				break
		placed.append(best)

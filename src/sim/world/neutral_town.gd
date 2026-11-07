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

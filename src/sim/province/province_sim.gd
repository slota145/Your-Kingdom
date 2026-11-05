class_name ProvinceSim
extends RefCounted
## Detailed simulation of one province (ARCHITECTURE §4.1): map, buildings, people, goods.
##
## Storages are buildings with a stockpile or ground piles; both are addressed by entity id.
## Systems run in the fixed order of ARCHITECTURE §4.2 from [method step].

var data: DataRegistry
var events: SimEvents
var ids: EntityIds
## Current tick, mirrored from the SimClock before each step.
var tick: int = 0

var grid: TileGrid
var nav: NavGrid
var resources: ResourceField
var buildings: BuildingStore = BuildingStore.new()
var agents: AgentStore = AgentStore.new()
var piles: Dictionary[int, GroundPile] = {}
## Construction and upgrade sites by entity id.
var sites: Dictionary[int, ConstructionSite] = {}
var fields: FieldStore = FieldStore.new()
var jobs: JobBoard = JobBoard.new()
var paths: PathRequestQueue = PathRequestQueue.new()
## The kingdom's gold. Owned by the Simulation (it is global), shared here for convenience.
var treasury: Treasury = Treasury.new()
## Derived from buildings and the map; not saved.
var coverage: ServiceCoverage = ServiceCoverage.new()
## Where newcomers enter the province.
var entry_tile: Vector2i = Vector2i.ZERO
## Terrain definitions by TileGrid index.
var terrains: Array[TerrainDef] = []

## Walking cost on a dirt road: +50% speed (GDD §5.2).
const ROAD_COST := 0.67
## Walking cost on a field tile (ARCHITECTURE §5.3).
const FIELD_COST := 1.2


func _init(registry: DataRegistry, size: Vector2i, event_queue: SimEvents, entity_ids: EntityIds) -> void:
	data = registry
	events = event_queue
	ids = entity_ids
	grid = TileGrid.new(size)
	nav = NavGrid.new(size)
	resources = ResourceField.new(size)
	terrains = registry.terrains_by_index()


func step() -> void:
	jobs.update(self)
	for agent: Agent in agents.all():
		if agents.has_agent(agent.id):
			TaskRunner.tick_agent(self, agent)
	Movement.serve_paths(self)
	Movement.move_all(self)
	_remove_empty_piles()
	Population.update(self)


# --- Map -----------------------------------------------------------------------------------

func terrain_at(tile: Vector2i) -> TerrainDef:
	var index := grid.terrain(tile)
	return terrains[index] if index < terrains.size() else null


func is_tile_solid(tile: Vector2i) -> bool:
	if grid.is_blocked(tile) or resources.blocks_movement(tile):
		return true
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.walkable:
		return true
	var owner := grid.occupant(tile)
	if owner != 0:
		var building := buildings.get_building(owner)
		return building == null or building.entrance_tile() != tile
	return false


func refresh_tile(tile: Vector2i) -> void:
	nav.set_solid(tile, is_tile_solid(tile))
	var cost := 1.0
	if grid.has_road(tile):
		cost = ROAD_COST
	elif fields.has_field(tile):
		cost = FIELD_COST
	else:
		var terrain := terrain_at(tile)
		if terrain != null:
			cost = terrain.move_cost
	if not is_equal_approx(nav.get_cost(tile), cost):
		nav.set_cost(tile, cost)


## Terrain from a map image (pixel colour -> TerrainDef.map_color), trees on forest, and the
## start layout: finished buildings, residents and goods. Returns colours not matching any
## terrain (they become the default terrain).
func load_map(map: MapDef) -> PackedStringArray:
	var problems := PackedStringArray()
	var image := map.terrain_image
	var by_color: Dictionary[int, TerrainDef] = {}
	for terrain: TerrainDef in terrains:
		if terrain != null:
			by_color[terrain.map_color.to_rgba32() | 0xff] = terrain
	for y: int in mini(grid.size.y, image.get_height()):
		for x: int in mini(grid.size.x, image.get_width()):
			var tile := Vector2i(x, y)
			var color := image.get_pixel(x, y).to_rgba32() | 0xff
			var terrain: TerrainDef = by_color.get(color)
			if terrain == null:
				problems.append("unknown colour %08x at %s" % [color, tile])
				continue
			grid.set_terrain(tile, terrain.index)
			if terrain.resource_node != &"":
				resources.place(tile, data.get_resource_node(terrain.resource_node))
	for tile: Vector2i in map.resource_spots:
		var node := data.get_resource_node(map.resource_spots[tile])
		if node == null or not grid.is_inside(tile):
			problems.append("resource spot %s at %s" % [map.resource_spots[tile], tile])
			continue
		resources.place(tile, node)
	entry_tile = map.entry_tile
	treasury.gold = map.start_gold
	rebuild_nav()
	for start: StartBuildingDef in map.start_buildings:
		var def := data.get_building(start.building)
		var error := placement_error(def, start.origin)
		if error != &"":
			problems.append("start %s at %s: %s" % [start.building, start.origin, error])
			continue
		var building := add_building(def, start.origin, true)
		if building.house != null:
			building.house.residents = mini(start.residents, building.capacity())
		var store := building.stock if building.stock != null else building.supply
		if store != null:
			for good: StringName in start.goods:
				store.add(good, start.goods[good])
	return problems

func rebuild_nav() -> void:
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			refresh_tile(Vector2i(x, y))


## A walkable neighbour of [param node] closest to [param from], or Agent.NO_TILE.
## Orthogonal neighbours win ties, then the IsoMath direction order.
func approach_tile(node: Vector2i, from: Vector2i) -> Vector2i:
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		var t := node + step
		if not nav.is_walkable(t):
			continue
		var d := (t - from).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


# --- Buildings -----------------------------------------------------------------------------

## &"" when the building fits at [param origin], otherwise the reason.
func placement_error(def: BuildingDef, origin: Vector2i) -> StringName:
	if def == null:
		return &"unknown_building"
	for tile: Vector2i in def.footprint_tiles(origin):
		if not grid.is_inside(tile):
			return &"outside_map"
		var terrain := terrain_at(tile)
		if terrain != null and not terrain.buildable:
			return &"terrain_not_buildable"
		if grid.is_blocked(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
			return &"tile_occupied"
		if _pile_at(tile) != 0 or fields.has_field(tile) or grid.has_road(tile):
			return &"tile_occupied"
	if def.needs_terrain_near != &"" and not has_terrain_near(def, origin):
		return StringName("no_%s_nearby" % def.needs_terrain_near)
	var entrance := origin + def.entrance
	for agent: Agent in agents.all():
		var t := agent.tile()
		if t != entrance and t.x >= origin.x and t.y >= origin.y \
				and t.x < origin.x + def.footprint.x and t.y < origin.y + def.footprint.y:
			return &"tile_has_people"
	return &""


## Whether a tile of terrain [member BuildingDef.needs_terrain_near] lies within the work
## radius of a building of [param def] placed at [param origin].
func has_terrain_near(def: BuildingDef, origin: Vector2i) -> bool:
	var area := Rect2i(origin, def.footprint).grow(def.work_radius).intersection(Rect2i(Vector2i.ZERO, grid.size))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var terrain := terrain_at(Vector2i(x, y))
			if terrain != null and terrain.id == def.needs_terrain_near:
				return true
	return false


## The walkable tile within the work radius of [param building], next to its
## needs_terrain_near terrain, nearest to [param from]; Agent.NO_TILE if none.
## Tiles where another worker already stands are used only when nothing else is free.
func find_shore(building: BuildingState, from: Vector2i) -> Vector2i:
	var taken: Dictionary[Vector2i, bool] = {}
	for agent: Agent in agents.all():
		if agent.task != null and agent.task.bb.has("stand") and agent.workplace_id != 0:
			taken[SimCodec.to_vec2i(agent.task.bb["stand"])] = true
	var area := Rect2i(building.origin, building.def.footprint).grow(building.def.work_radius) \
			.intersection(Rect2i(Vector2i.ZERO, grid.size))
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			if not nav.is_walkable(tile) or grid.occupant(tile) != 0 \
					or shore_water(tile, building.def.needs_terrain_near) == Agent.NO_TILE:
				continue
			var d := (tile - from).length_squared() + (1 << 20 if taken.has(tile) else 0)
			if d < best_d:
				best_d = d
				best = tile
	return best


## An orthogonal neighbour of [param tile] with terrain [param terrain_id]; Agent.NO_TILE if none.
func shore_water(tile: Vector2i, terrain_id: StringName) -> Vector2i:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var terrain := terrain_at(tile + step) if grid.is_inside(tile + step) else null
		if terrain != null and terrain.id == terrain_id:
			return tile + step
	return Agent.NO_TILE


## Places a building. [param instant] finishes it at once (map start, tests); otherwise it
## becomes a construction site that porters and builders turn into the building (its gold
## cost is paid now; the command checked there is enough).
func add_building(def: BuildingDef, origin: Vector2i, instant: bool = false) -> BuildingState:
	var building := BuildingState.new(ids.take(), def, origin)
	if not instant:
		treasury.pay(def.gold_cost)
	buildings.add(building)
	for tile: Vector2i in building.tiles():
		grid.set_occupant(tile, building.id)
		resources.clear(tile)
		refresh_tile(tile)
	events.emit(&"building_placed", {"building": building.id, "def": def.id, "origin": origin,
			"instant": instant})
	if instant or def.build_cost.is_empty():
		building.finish(data)
		events.emit(&"building_completed", {"building": building.id, "def": def.id})
	else:
		building.under_construction = true
		Construction.open_build_site(self, building)
	return building


## Removes a building. Stored goods and part of the materials are put on the ground,
## workers go home (their characters vanish), people living there leave.
func remove_building(id: int) -> void:
	var building := buildings.get_building(id)
	if building == null:
		return
	for worker_id: int in building.workers.duplicate():
		var worker := agents.get_agent(worker_id)
		if worker != null:
			remove_agent(worker)
	for agent: Agent in agents.all():
		if agent.home_id == id:
			remove_agent(agent)
	for tile: Vector2i in fields.tiles_of(id):
		remove_field(tile)
	var was_complete := building.is_complete()
	Construction.cancel_site(self, building)
	buildings.remove(id)
	jobs.cancel_for_entity(id)
	for agent: Agent in agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == id \
				or int(agent.task.bb.get("_dst", 0)) == id):
			TaskRunner.fail(self, agent)
	var tiles := building.tiles()
	for tile: Vector2i in tiles:
		grid.set_occupant(tile, 0)
		refresh_tile(tile)
	var i := 0
	for store: Stockpile in [building.stock, building.supply]:
		if store == null:
			continue
		for slot: int in store.slot_count():
			var amount := store.slot_amount[slot]
			if amount > 0:
				drop_goods(tiles[i % tiles.size()], store.slot_good[slot], amount)
				i += 1
	if was_complete:
		var refund := Construction.refund(building.def)
		for good: StringName in refund:
			drop_goods(tiles[i % tiles.size()], good, refund[good])
			i += 1
		treasury.add(floori(building.def.gold_cost * Construction.REFUND_SHARE))
	events.emit(&"building_removed", {"building": id, "def": building.def.id})


func assign_worker(agent: Agent, building: BuildingState) -> void:
	var old := buildings.get_building(agent.workplace_id)
	if old != null:
		old.workers.erase(agent.id)
	if agent.task != null and agent.task.kind == Task.KIND_RECIPE:
		TaskRunner.fail(self, agent)
		agent.cooldown = 0
	agent.workplace_id = building.id
	building.workers.append(agent.id)


# --- Fields and roads ----------------------------------------------------------------------

## &"" when [param tile] can become a field of [param farm_id], otherwise the reason.
func field_error(farm_id: int, tile: Vector2i) -> StringName:
	var farm := buildings.get_building(farm_id)
	if farm == null or farm.def.max_fields == 0:
		return &"not_a_farm"
	if not grid.is_inside(tile):
		return &"outside_map"
	if fields.tiles_of(farm_id).size() >= farm.def.max_fields:
		return &"too_many_fields"
	var rect := Rect2i(farm.origin, farm.def.footprint).grow(farm.def.work_radius)
	if not rect.has_point(tile):
		return &"out_of_range"
	return _free_ground_error(tile)


func add_field(farm_id: int, tile: Vector2i) -> void:
	fields.add(tile, farm_id)
	refresh_tile(tile)
	events.emit(&"field_changed", {"tile": tile, "farm": farm_id})


## Removes a field tile; a farmer working it gives up.
func remove_field(tile: Vector2i) -> void:
	var owner := fields.claimant(tile)
	fields.remove(tile)
	refresh_tile(tile)
	var agent := agents.get_agent(owner)
	if agent != null and agent.task != null:
		TaskRunner.fail(self, agent)
	events.emit(&"field_changed", {"tile": tile, "farm": 0})


## &"" when a dirt road can go on [param tile].
func road_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.has_road(tile):
		return &"already_road"
	return _free_ground_error(tile)


func set_road(tile: Vector2i, road: bool) -> void:
	grid.set_road(tile, road)
	refresh_tile(tile)
	events.emit(&"road_changed", {"tile": tile, "road": road})


func _free_ground_error(tile: Vector2i) -> StringName:
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.buildable:
		return &"terrain_not_buildable"
	if grid.is_blocked(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
		return &"tile_occupied"
	if fields.has_field(tile) or grid.has_road(tile) or _pile_at(tile) != 0:
		return &"tile_occupied"
	return &""


# --- Agents --------------------------------------------------------------------------------

func spawn_agent(kind: StringName, tile: Vector2i) -> Agent:
	var agent := Agent.new(ids.take(), kind, IsoMath.tile_center(tile))
	agents.add(agent)
	events.emit(&"agent_spawned", {"agent": agent.id, "kind": kind, "tile": tile})
	return agent


## Takes a person off the map (job lost, errand done, moved in): its task is cancelled,
## whatever it carries goes on the ground, and nothing stays reserved.
func remove_agent(agent: Agent) -> void:
	if not agents.has_agent(agent.id):
		return
	if agent.task != null:
		TaskRunner.fail(self, agent)
	release_agent(agent)
	drop_carried(agent)
	var workplace := buildings.get_building(agent.workplace_id)
	if workplace != null:
		workplace.workers.erase(agent.id)
	var home := buildings.get_building(agent.home_id)
	if home != null and home.house != null:
		for good: StringName in home.house.errands.keys():
			if home.house.errands[good] == agent.id:
				home.house.errands.erase(good)
	agents.remove(agent.id)
	events.emit(&"agent_removed", {"agent": agent.id, "kind": agent.kind})


## Releases every reservation and claim the agent holds.
func release_agent(agent: Agent) -> void:
	for store: Stockpile in all_storages().values():
		store.release_owner(agent.id)
	fields.release_owner(agent.id)
	if agent.claimed_node != Agent.NO_TILE:
		resources.release(agent.claimed_node, agent.id)
		agent.claimed_node = Agent.NO_TILE


## Puts what the agent carries on the ground at its tile.
func drop_carried(agent: Agent) -> void:
	if agent.is_carrying():
		drop_goods(agent.tile(), agent.carry_good, agent.carry_amount)
		agent.carry_good = &""
		agent.carry_amount = 0


# --- Storages ------------------------------------------------------------------------------

## Any stockpile addressed by entity id: a storage building, a house pantry, a construction
## site or a ground pile.
func storage(id: int) -> Stockpile:
	if id == 0:
		return null
	var building := buildings.get_building(id)
	if building != null:
		return building.stock if building.stock != null else building.supply
	var site := sites.get(id) as ConstructionSite
	if site != null:
		return site.stock
	var pile := piles.get(id) as GroundPile
	return pile.stock if pile != null else null


## Every stockpile by entity id, in a stable order (accounting, reservations).
func all_storages() -> Dictionary[int, Stockpile]:
	var result: Dictionary[int, Stockpile] = {}
	for building: BuildingState in buildings.all():
		var store := storage(building.id)
		if store != null:
			result[building.id] = store
	for site: ConstructionSite in sites.values():
		result[site.id] = site.stock
	for pile: GroundPile in piles.values():
		result[pile.id] = pile.stock
	return result


func accepts_deliveries(id: int) -> bool:
	var building := buildings.get_building(id)
	if building != null:
		return building.stock != null or building.supply != null
	return sites.has(id)


func access_tile(id: int) -> Vector2i:
	var building := buildings.get_building(id)
	if building != null:
		return building.entrance_tile()
	var site := sites.get(id) as ConstructionSite
	if site != null:
		var target := buildings.get_building(site.building_id)
		return target.entrance_tile() if target != null else Agent.NO_TILE
	var pile := piles.get(id) as GroundPile
	return pile.tile if pile != null else Agent.NO_TILE


## Nearest storage (building or pile) able to give [param amount] of [param good]; 0 if none.
## [param keep_reserve] leaves each storage's reserve of the good alone (construction).
func nearest_source(good: StringName, amount: int, from: Vector2i, exclude: int = 0,
		keep_reserve: bool = false) -> int:
	var best := 0
	var best_d := 1 << 30
	for building: BuildingState in buildings.all():
		if building.stock != null and building.id != exclude \
				and can_give(building.id, good, amount, keep_reserve):
			var d := (building.entrance_tile() - from).length_squared()
			if d < best_d:
				best_d = d
				best = building.id
	for pile: GroundPile in piles.values():
		if pile.id != exclude and pile.stock.can_supply(good, amount):
			var d := (pile.tile - from).length_squared()
			if d < best_d:
				best_d = d
				best = pile.id
	return best


## Units of [param good] in storage buildings that can still be taken.
func stored(good: StringName) -> int:
	var sum := 0
	for building: BuildingState in buildings.all():
		if building.stock != null:
			sum += building.stock.available(good)
	return sum


## Units of [param good] storage [param id] keeps back from construction (0 for piles).
func reserve_of(id: int, good: StringName) -> int:
	var building := buildings.get_building(id)
	return int(building.reserves.get(good, 0)) if building != null else 0


## Whether storage [param id] can hand out [param amount] of [param good] in one load, leaving
## its reserve in place when [param keep_reserve].
func can_give(id: int, good: StringName, amount: int, keep_reserve: bool = false) -> bool:
	var store := storage(id)
	if store == null or not store.can_supply(good, amount):
		return false
	return not keep_reserve or store.available(good) - reserve_of(id, good) >= amount


## Nearest storage building with room for [param amount] of [param good]; 0 if none.
func nearest_sink(good: StringName, amount: int, from: Vector2i, exclude: int = 0) -> int:
	var best := 0
	var best_d := 1 << 30
	for building: BuildingState in buildings.all():
		if building.stock != null and building.id != exclude and building.stock.can_accept(good, amount):
			var d := (building.entrance_tile() - from).length_squared()
			if d < best_d:
				best_d = d
				best = building.id
	return best


## Puts goods on the ground (merging into a pile of the same good on that tile) and asks
## porters to bring them to a storage. Returns the pile id.
func drop_goods(tile: Vector2i, good: StringName, amount: int) -> int:
	var left := amount
	var last := 0
	for pile: GroundPile in piles.values():
		if left > 0 and pile.tile == tile and pile.good() == good:
			var before := left
			left = pile.stock.add(good, left)
			if left < before:
				jobs.add(good, before - left, pile.id, 0)
				last = pile.id
	while left > 0:
		var pile := GroundPile.new(ids.take(), tile, data)
		var before := left
		left = pile.stock.add(good, left)
		piles[pile.id] = pile
		jobs.add(good, before - left, pile.id, 0)
		events.emit(&"pile_created", {"pile": pile.id, "tile": tile, "good": good})
		last = pile.id
	return last


func _pile_at(tile: Vector2i) -> int:
	for pile: GroundPile in piles.values():
		if pile.tile == tile:
			return pile.id
	return 0


func _remove_empty_piles() -> void:
	for pile: GroundPile in piles.values():
		if pile.stock.is_empty():
			piles.erase(pile.id)
			jobs.cancel_for_entity(pile.id)
			events.emit(&"pile_removed", {"pile": pile.id, "tile": pile.tile})


# --- Accounting (tests, debug) -------------------------------------------------------------

## Every unit of [param good] in the province: storages, piles and hands.
func goods_total(good: StringName) -> int:
	var sum := 0
	for store: Stockpile in all_storages().values():
		sum += store.total(good)
	for agent: Agent in agents.all():
		if agent.carry_good == good:
			sum += agent.carry_amount
	return sum


func reservation_count() -> int:
	var sum := 0
	for store: Stockpile in all_storages().values():
		sum += store.reservation_count()
	return sum


## Reservations and claims not backed by a running task step that knows about them.
## Must always be empty; used by tests after failure scenarios.
func dangling_holds() -> PackedStringArray:
	var problems := PackedStringArray()
	var storages := all_storages()
	for storage_id: int in storages:
		for res: Reservation in storages[storage_id].reservations():
			var agent := agents.get_agent(res.owner)
			var bb: Dictionary = agent.task.bb if agent != null and agent.task != null else {}
			var held := int(bb.get("_res", 0)) == res.id \
					and (int(bb.get("_src", 0)) == storage_id or int(bb.get("_dst", 0)) == storage_id)
			if not held:
				problems.append("reservation %d in %d by %d" % [res.id, storage_id, res.owner])
	for tile: Vector2i in resources.tiles_with_nodes():
		var owner := resources.claimant(tile)
		if owner != 0:
			var agent := agents.get_agent(owner)
			if agent == null or agent.claimed_node != tile:
				problems.append("claim %s by %d" % [tile, owner])
	for tile: Vector2i in fields.all_tiles():
		var owner := fields.claimant(tile)
		if owner != 0:
			var agent := agents.get_agent(owner)
			var bb: Dictionary = agent.task.bb if agent != null and agent.task != null else {}
			if not bb.has("field") or SimCodec.to_vec2i(bb["field"]) != tile:
				problems.append("field %s by %d" % [tile, owner])
	return problems


func claim_count() -> int:
	var sum := 0
	for tile: Vector2i in resources.tiles_with_nodes():
		if resources.claimant(tile) != 0:
			sum += 1
	return sum


# --- Save ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pile_list: Array = []
	for pile: GroundPile in piles.values():
		pile_list.append(pile.to_dict())
	var site_list: Array = []
	for site: ConstructionSite in sites.values():
		site_list.append(site.to_dict())
	return {
		"grid": grid.to_dict(),
		"resources": resources.to_dict(),
		"buildings": buildings.to_dict(),
		"piles": pile_list,
		"sites": site_list,
		"fields": fields.to_dict(),
		"entry": SimCodec.vec2i(entry_tile),
		"agents": agents.to_dict(),
		"jobs": jobs.to_dict(),
		"path_queue": paths.to_dict(),
	}


static func from_dict(d: Dictionary, registry: DataRegistry, event_queue: SimEvents,
		entity_ids: EntityIds) -> ProvinceSim:
	var grid := TileGrid.from_dict(d["grid"])
	var province := ProvinceSim.new(registry, grid.size, event_queue, entity_ids)
	province.grid = grid
	province.resources = ResourceField.from_dict(d["resources"], grid.size, registry)
	province.buildings = BuildingStore.from_dict(d["buildings"], registry)
	for building: BuildingState in province.buildings.all():
		for tile: Vector2i in building.tiles():
			grid.set_occupant(tile, building.id)
	for pd: Variant in d.get("piles", []):
		var pile := GroundPile.from_dict(pd, registry)
		province.piles[pile.id] = pile
	for sd: Variant in d.get("sites", []):
		var site := ConstructionSite.from_dict(sd, registry)
		province.sites[site.id] = site
	province.fields = FieldStore.from_dict(d.get("fields", []))
	province.entry_tile = SimCodec.to_vec2i(d.get("entry", [0, 0]))
	province.agents = AgentStore.from_dict(d["agents"])
	for agent: Agent in province.agents.all():
		if agent.task != null and not TaskRunner.restore_steps(province, agent.task):
			agent.task = null
	province.jobs = JobBoard.from_dict(d["jobs"])
	province.paths = PathRequestQueue.from_dict(d.get("path_queue", []))
	province.rebuild_nav()
	return province

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
var jobs: JobBoard = JobBoard.new()
var paths: PathRequestQueue = PathRequestQueue.new()


func _init(registry: DataRegistry, size: Vector2i, event_queue: SimEvents, entity_ids: EntityIds) -> void:
	data = registry
	events = event_queue
	ids = entity_ids
	grid = TileGrid.new(size)
	nav = NavGrid.new(size)
	resources = ResourceField.new(size)


func step() -> void:
	jobs.update(self)
	for agent: Agent in agents.all():
		TaskRunner.tick_agent(self, agent)
	Movement.serve_paths(self)
	Movement.move_all(self)
	_remove_empty_piles()


# --- Map -----------------------------------------------------------------------------------

func is_tile_solid(tile: Vector2i) -> bool:
	if grid.is_blocked(tile) or resources.blocks_movement(tile):
		return true
	var owner := grid.occupant(tile)
	if owner != 0:
		var building := buildings.get_building(owner)
		return building == null or building.entrance_tile() != tile
	return false


func refresh_tile(tile: Vector2i) -> void:
	nav.set_solid(tile, is_tile_solid(tile))


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
		if grid.is_blocked(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
			return &"tile_occupied"
		if _pile_at(tile) != 0:
			return &"tile_occupied"
	var entrance := origin + def.entrance
	for agent: Agent in agents.all():
		var t := agent.tile()
		if t != entrance and t.x >= origin.x and t.y >= origin.y \
				and t.x < origin.x + def.footprint.x and t.y < origin.y + def.footprint.y:
			return &"tile_has_people"
	return &""


func add_building(def: BuildingDef, origin: Vector2i) -> BuildingState:
	var building := BuildingState.new(ids.take(), def, origin, data)
	buildings.add(building)
	for tile: Vector2i in building.tiles():
		grid.set_occupant(tile, building.id)
		resources.clear(tile)
		refresh_tile(tile)
	events.emit(&"building_placed", {"building": building.id, "def": def.id, "origin": origin})
	return building


## Removes a building. Stored goods are put on the ground, workers are released.
func remove_building(id: int) -> void:
	var building := buildings.get_building(id)
	if building == null:
		return
	for worker_id: int in building.workers:
		var worker := agents.get_agent(worker_id)
		if worker != null:
			worker.workplace_id = 0
			if worker.task != null and worker.task.kind == Task.KIND_RECIPE:
				TaskRunner.fail(self, worker)
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
	if building.stock != null:
		var i := 0
		for slot: int in building.stock.slot_count():
			var amount := building.stock.slot_amount[slot]
			if amount > 0:
				drop_goods(tiles[i % tiles.size()], building.stock.slot_good[slot], amount)
				i += 1
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


# --- Agents --------------------------------------------------------------------------------

func spawn_agent(kind: StringName, tile: Vector2i) -> Agent:
	var agent := Agent.new(ids.take(), kind, IsoMath.tile_center(tile))
	agents.add(agent)
	events.emit(&"agent_spawned", {"agent": agent.id, "kind": kind, "tile": tile})
	return agent


## Releases every reservation and claim the agent holds.
func release_agent(agent: Agent) -> void:
	for building: BuildingState in buildings.all():
		if building.stock != null:
			building.stock.release_owner(agent.id)
	for pile: GroundPile in piles.values():
		pile.stock.release_owner(agent.id)
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

func storage(id: int) -> Stockpile:
	if id == 0:
		return null
	var building := buildings.get_building(id)
	if building != null:
		return building.stock
	var pile := piles.get(id) as GroundPile
	return pile.stock if pile != null else null


func accepts_deliveries(id: int) -> bool:
	var building := buildings.get_building(id)
	return building != null and building.stock != null


func access_tile(id: int) -> Vector2i:
	var building := buildings.get_building(id)
	if building != null:
		return building.entrance_tile()
	var pile := piles.get(id) as GroundPile
	return pile.tile if pile != null else Agent.NO_TILE


## Nearest storage (building or pile) able to give [param amount] of [param good]; 0 if none.
func nearest_source(good: StringName, amount: int, from: Vector2i, exclude: int = 0) -> int:
	var best := 0
	var best_d := 1 << 30
	for building: BuildingState in buildings.all():
		if building.stock != null and building.id != exclude and building.stock.can_supply(good, amount):
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
	for building: BuildingState in buildings.all():
		if building.stock != null:
			sum += building.stock.total(good)
	for pile: GroundPile in piles.values():
		sum += pile.stock.total(good)
	for agent: Agent in agents.all():
		if agent.carry_good == good:
			sum += agent.carry_amount
	return sum


func reservation_count() -> int:
	var sum := 0
	for building: BuildingState in buildings.all():
		if building.stock != null:
			sum += building.stock.reservation_count()
	for pile: GroundPile in piles.values():
		sum += pile.stock.reservation_count()
	return sum


## Reservations and claims not backed by a running task step that knows about them.
## Must always be empty; used by tests after failure scenarios.
func dangling_holds() -> PackedStringArray:
	var problems := PackedStringArray()
	var storages: Dictionary[int, Stockpile] = {}
	for building: BuildingState in buildings.all():
		if building.stock != null:
			storages[building.id] = building.stock
	for pile: GroundPile in piles.values():
		storages[pile.id] = pile.stock
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
	return {
		"grid": grid.to_dict(),
		"resources": resources.to_dict(),
		"buildings": buildings.to_dict(),
		"piles": pile_list,
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
	province.agents = AgentStore.from_dict(d["agents"])
	for agent: Agent in province.agents.all():
		if agent.task != null and not TaskRunner.restore_steps(province, agent.task):
			agent.task = null
	province.jobs = JobBoard.from_dict(d["jobs"])
	province.paths = PathRequestQueue.from_dict(d.get("path_queue", []))
	province.rebuild_nav()
	return province

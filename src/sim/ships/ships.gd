class_name Ships
extends RefCounted
## Ships on the water and shipyards (GDD §5.4, ROADMAP M5 part 1): sailing along water paths,
## launching new ships, giving boats to fishing wharves and opening the next order of a
## shipyard. Static helpers over ProvinceSim state, like Construction.

## Agent.vehicle of somebody aboard a ship (the fisherman in his boat).
const ABOARD := &"boat"
## How far (tiles, Chebyshev from the berth) a fishing boat looks for a shoal.
const SHOAL_RADIUS := 24
## Most orders a shipyard queue holds.
const MAX_ORDERS := 5


# --- Water paths ---------------------------------------------------------------------------

## The water NavGrid ships of [param def] sail on.
static func nav_for(province: ProvinceSim, def: ShipDef) -> NavGrid:
	return province.cog_nav if def.deep_only else province.boat_nav


## Sets [param ship] sailing to [param goal]; false (and FAILED) when there is no way.
static func sail_to(province: ProvinceSim, ship: ShipUnit, goal: Vector2i) -> bool:
	ship.clear_path()
	ship.path_goal = goal
	if ship.tile() == goal:
		ship.path_state = ShipUnit.PathState.ARRIVED
		return true
	var path := nav_for(province, ship.def).find_path(ship.tile(), goal)
	if path.is_empty():
		ship.path_state = ShipUnit.PathState.FAILED
		return false
	ship.path = path
	ship.path_index = 1
	ship.path_state = ShipUnit.PathState.MOVING
	ship.dock_id = 0
	ship.activity = &"sail"
	_face(ship)
	return true


## Moves every sailing ship along its path; crews aboard move with their ship.
static func move_all(province: ProvinceSim) -> void:
	for ship: ShipUnit in province.ships.values():
		ship.prev_pos = ship.pos
		if ship.path_state == ShipUnit.PathState.MOVING:
			_advance(province, ship)
		var crew := province.agents.get_agent(ship.crew) if ship.crew != 0 else null
		if crew == null:
			continue
		crew.prev_pos = crew.prev_pos if crew.pos == ship.pos else ship.prev_pos
		crew.pos = ship.pos
		if ship.path_state == ShipUnit.PathState.MOVING:
			crew.facing = ship.facing
		else:
			ship.activity = crew.activity


static func _advance(province: ProvinceSim, ship: ShipUnit) -> void:
	var nav := nav_for(province, ship.def)
	var budget := ship.def.speed * SimClock.TICK
	while budget > 0.0:
		if ship.path_index >= ship.path.size():
			ship.path_state = ShipUnit.PathState.ARRIVED
			ship.activity = &"idle"
			return
		var tile := ship.path[ship.path_index]
		if not nav.is_walkable(tile):
			# Something was built on the way: find another way from here.
			var goal := ship.path_goal
			if not sail_to(province, ship, goal):
				return
			continue
		var target := IsoMath.tile_center(tile)
		var delta := target - ship.pos
		var length := delta.length()
		if length <= budget:
			ship.pos = target
			budget -= length
			ship.path_index += 1
			if ship.path_index < ship.path.size():
				_face(ship)
		else:
			ship.pos += delta / length * budget
			budget = 0.0
	if ship.path_index >= ship.path.size():
		ship.path_state = ShipUnit.PathState.ARRIVED
		ship.activity = &"idle"


static func _face(ship: ShipUnit) -> void:
	if ship.path_index >= ship.path.size():
		return
	var dir := IsoMath.screen_dir(IsoMath.tile_center(ship.path[ship.path_index]) - ship.pos)
	if dir >= 0:
		ship.facing = dir


# --- Ships and their buildings -------------------------------------------------------------

## The ship working for [param building] (a wharf's boat), or null.
static func ship_of(province: ProvinceSim, building: BuildingState) -> ShipUnit:
	for ship: ShipUnit in province.ships.values():
		if ship.home_id == building.id:
			return ship
	return null


## Moors [param ship] at the berth of [param building].
static func dock(ship: ShipUnit, building: BuildingState) -> void:
	ship.clear_path()
	ship.pos = IsoMath.tile_center(building.berth_tile())
	ship.dock_id = building.id
	ship.activity = &"idle"


## [param agent] steps aboard [param ship] (from the building where it is moored).
static func board(ship: ShipUnit, agent: Agent) -> void:
	agent.clear_path()
	agent.vehicle = ABOARD
	agent.pos = ship.pos
	agent.prev_pos = ship.pos
	ship.crew = agent.id


## [param agent] goes ashore into [param building] (at its entrance) from [param ship].
static func disembark(ship: ShipUnit, agent: Agent, building: BuildingState) -> void:
	agent.vehicle = &""
	agent.pos = IsoMath.tile_center(building.entrance_tile())
	agent.prev_pos = agent.pos
	agent.activity = &"idle"
	ship.crew = 0
	ship.activity = &"idle"


## The ship [param agent] is aboard, or null.
static func ship_with_crew(province: ProvinceSim, agent: Agent) -> ShipUnit:
	for ship: ShipUnit in province.ships.values():
		if ship.crew == agent.id:
			return ship
	return null


## Takes [param agent] off its ship (he leaves the province): what he carries goes into the
## hold, so nothing is lost at sea.
static func leave_ship(province: ProvinceSim, agent: Agent) -> void:
	var ship := ship_with_crew(province, agent)
	agent.vehicle = &""
	if ship == null:
		return
	ship.crew = 0
	if agent.is_carrying():
		var left := ship.hold.add(agent.carry_good, agent.carry_amount)
		agent.carry_amount = left
		if left == 0:
			agent.carry_good = &""


## A building of [param building_id] is gone: its ships lose their home or their mooring.
static func on_building_removed(province: ProvinceSim, building_id: int) -> void:
	for ship: ShipUnit in province.ships.values():
		if ship.home_id == building_id:
			ship.home_id = 0
		if ship.dock_id == building_id:
			ship.dock_id = 0
		if ship.berth_id == building_id:
			ship.berth_id = 0
	for build: ShipBuild in province.ship_builds.values():
		if build.shipyard_id == building_id:
			close_build(province, build, false)


# --- Shipyards -----------------------------------------------------------------------------

## The ship being built at [param shipyard], or null.
static func build_at(province: ProvinceSim, shipyard: BuildingState) -> ShipBuild:
	for build: ShipBuild in province.ship_builds.values():
		if build.shipyard_id == shipyard.id:
			return build
	return null


## Opens the slipway for the first order of [param shipyard]: all materials are asked for at
## once (like a construction site).
static func open_build(province: ProvinceSim, shipyard: BuildingState) -> ShipBuild:
	var def := province.data.get_ship(shipyard.ship_orders[0])
	var build := ShipBuild.new(province.ids.take(), shipyard.id, def, province.data)
	province.ship_builds[build.id] = build
	var total := build.total_cost()
	var goods: Array[StringName] = []
	goods.assign(total.keys())
	goods.sort()
	for good: StringName in goods:
		province.jobs.add(good, total[good], 0, build.id)
	province.events.emit(&"ship_build_opened", {"build": build.id, "building": shipyard.id,
			"ship": def.id})
	return build


## Asks again for materials that will not arrive any more (a porter carrying them lost his
## job and they went on the ground): every unit still needed is either on the slipway or on
## its way.
static func _top_up(province: ProvinceSim, build: ShipBuild) -> void:
	var needed := build.still_needed()
	for good: StringName in needed:
		var on_way := province.jobs.in_flight(good, 0, build.id)
		province.jobs.set_amount(good, 0, build.id, needed[good] - build.stock.total(good) - on_way)


static func start_stage(province: ProvinceSim, build: ShipBuild) -> void:
	var cost := build.current_cost()
	for good: StringName in cost:
		build.stock.remove(good, int(cost[good]))
		province.ledger.used(good, int(cost[good]), province.tick)
	build.stage_started = true
	build.work_left = build.stage_ticks
	province.events.emit(&"ship_stage_started", {"build": build.id, "building": build.shipyard_id,
			"stage": build.stage})


## The current stage is worked off: the next one, or the launch after the last.
static func finish_stage(province: ProvinceSim, build: ShipBuild) -> void:
	province.events.emit(&"ship_stage_finished", {"build": build.id, "building": build.shipyard_id,
			"stage": build.stage})
	build.stage += 1
	build.stage_started = false
	build.work_left = build.stage_ticks
	if build.stage >= build.stage_count():
		close_build(province, build, true)


## Removes a ship build. [param launched]: the ship goes into the water at the berth and the
## order leaves the queue. Otherwise (order cancelled, shipyard gone) materials not used yet
## go on the ground at the shipyard.
static func close_build(province: ProvinceSim, build: ShipBuild, launched: bool) -> void:
	province.ship_builds.erase(build.id)
	province.jobs.cancel_for_entity(build.id)
	for agent: Agent in province.agents.all():
		if agent.task != null and int(agent.task.bb.get("_dst", 0)) == build.id:
			TaskRunner.fail(province, agent)
	var shipyard := province.buildings.get_building(build.shipyard_id)
	if launched and shipyard != null:
		if not shipyard.ship_orders.is_empty():
			shipyard.ship_orders.remove_at(0)
		var ship := launch(province, province.data.get_ship(build.ship), shipyard)
		province.events.emit(&"ship_launched", {"ship": ship.id, "def": build.ship,
				"building": shipyard.id})
	var at := province.door_tile(shipyard) if shipyard != null else province.entry_tile
	if at == Agent.NO_TILE:
		at = province.entry_tile
	var leftovers := build.stock.totals()
	for good: StringName in leftovers:
		province.drop_goods(at, good, leftovers[good])
	province.events.emit(&"ship_build_closed", {"build": build.id, "building": build.shipyard_id,
			"launched": launched})


## A new ship moored at the berth of [param building].
static func launch(province: ProvinceSim, def: ShipDef, building: BuildingState) -> ShipUnit:
	var ship := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(building.berth_tile()),
			province.data)
	ship.dock_id = building.id
	province.ships[ship.id] = ship
	return ship


## Once a second: shipyards start their next order, new boats get a wharf, and a ship left
## at sea without crew sails back to its home on its own.
static func update(province: ProvinceSim) -> void:
	for building: BuildingState in province.buildings.all():
		if building.def.ship_kinds.is_empty() or not building.is_complete():
			continue
		if not building.ship_orders.is_empty() and build_at(province, building) == null:
			open_build(province, building)
	for build: ShipBuild in province.ship_builds.values():
		_top_up(province, build)
	if province.ships.is_empty():
		return
	for ship: ShipUnit in province.ships.values():
		if ship.def.id == SeaMerchant.SHIP or ship.voyage != null or ship.def.id == Landing.SHIP:
			continue   # cogs go their own way (SeaMerchant, Voyage)
		if ship.home_id == 0:
			_find_home(province, ship)
		if ship.crew == 0 and ship.dock_id == 0 and ship.path_state != ShipUnit.PathState.MOVING:
			var home := province.buildings.get_building(ship.home_id)
			if home == null:
				continue
			if ship.path_state == ShipUnit.PathState.ARRIVED and ship.path_goal == home.berth_tile():
				dock(ship, home)
			elif not sail_to(province, ship, home.berth_tile()):
				dock(ship, home)   # no way back by water: it is towed home


## Gives [param ship] the nearest finished building using its kind that has no ship yet
## and can be reached by water.
static func _find_home(province: ProvinceSim, ship: ShipUnit) -> void:
	var taken: Dictionary[int, bool] = {}
	for other: ShipUnit in province.ships.values():
		if other.home_id != 0:
			taken[other.home_id] = true
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if building.def.uses_ship != ship.def.id or not building.is_complete() or taken.has(building.id):
			continue
		var d := (building.berth_tile() - ship.tile()).length_squared()
		if d < best_d and not nav_for(province, ship.def).find_path(ship.tile(), building.berth_tile()).is_empty():
			best_d = d
			best = building
	if best != null:
		ship.home_id = best.id
		province.events.emit(&"ship_assigned", {"ship": ship.id, "building": best.id})


# --- Fairways ------------------------------------------------------------------------------

## Shallow tiles dredged from each berth that needs one to the nearest deep water (4
## neighbours, breadth first in a fixed order, so the result is deterministic). Derived from
## the buildings, not saved.
static func fairway_tiles(province: ProvinceSim) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for building: BuildingState in province.buildings.all():
		if building.def.berth_fairway:
			for tile: Vector2i in fairway_from(province, building.berth_tile()):
				result[tile] = true
	return result


## The shallow tiles on the shortest way by water from [param berth] to deep water (berth
## included when shallow); empty when deep water is out of reach within [param limit] steps.
static func fairway_from(province: ProvinceSim, berth: Vector2i, limit: int = 12) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not province.grid.is_inside(berth) or province.sail_depth(berth) == 0:
		return result
	var from: Dictionary[Vector2i, Vector2i] = {berth: Agent.NO_TILE}
	var queue: Array[Vector2i] = [berth]
	var head := 0
	var deep := Agent.NO_TILE
	while head < queue.size():
		var tile := queue[head]
		head += 1
		if province.sail_depth(tile) >= 2 and province.grid.occupant(tile) == 0:
			deep = tile
			break
		var steps := 0
		var back := tile
		while from[back] != Agent.NO_TILE:
			back = from[back]
			steps += 1
		if steps >= limit:
			continue
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next := tile + step
			if from.has(next) or not province.grid.is_inside(next) or province.sail_depth(next) == 0 \
					or province.grid.occupant(next) != 0:
				continue
			from[next] = tile
			queue.append(next)
	if deep == Agent.NO_TILE:
		return result
	var back := from[deep]
	while back != Agent.NO_TILE:
		result.append(back)
		back = from[back]
	return result

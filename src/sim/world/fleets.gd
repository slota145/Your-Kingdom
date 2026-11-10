class_name Fleets
extends RefCounted
## Fleets on the world map (ROADMAP M8 part 2, owner's survey 2026-11-09): the player's
## warships leave their province for the sea of the world map, one by one from the ship's
## panel (the ship sails to the edge of the map first) or all at once from the province's panel
## on the world map; soldiers aboard (P2 part 2) go with them. A fleet is an Army with ships at
## sea; it sails anywhere on the sea, sets its soldiers ashore, goes back into the port of the
## player's coastal province, and fights enemy fleets it meets (BattleResolver, NAVAL).
## Static helpers like Armies.

## Fleets of one side nearer than this (parchment pixels) at the same coast join.
const MERGE := 40.0


## Warships of province [param id] free to go: finished, at anchor, not taking soldiers aboard
## or ashore, not on their way out already.
static func free_warships(sim: Simulation, id: int) -> Array[ShipUnit]:
	var result: Array[ShipUnit] = []
	var province := sim.province_state(id)
	if province == null:
		return result
	var keys: Array[int] = []
	keys.assign(province.ships.keys())
	keys.sort()
	for key: int in keys:
		var ship := province.ships[key]
		if _free(ship):
			result.append(ship)
	return result


static func _free(ship: ShipUnit) -> bool:
	return ship.def.troops > 0 and ship.voyage == null and ship.troop_order == &"" \
			and ship.boarding.is_empty() and ship.sail_out == 0


## Why the warships of province [param id] cannot go out as a fleet now, or &"".
static func fleet_out_error(sim: Simulation, id: int) -> StringName:
	if sim.world.is_single():
		return &"no_world"
	if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
		return &"not_your_province"
	if sim.viewed_id == Simulation.BATTLEFIELD and id == FieldBattles.prev_view(sim):
		return &"army_in_battle"
	if ArmyOrders.offshore(sim, id) == Vector2.INF:
		return &"no_coast"
	if free_warships(sim, id).is_empty():
		return &"no_warships"
	return &""


## All free warships of province [param id] go out at once (with the soldiers aboard) and
## stand off its coast as a fleet.
static func fleet_out(sim: Simulation, id: int) -> Army:
	var province := sim.province_state(id)
	var fleet := _new_fleet(sim, id)
	fleet.state = Army.State.IDLE
	fleet.pos = ArmyOrders.offshore(sim, id)
	for ship: ShipUnit in free_warships(sim, id):
		_take(sim, province, ship, fleet)
	Armies.refill_from(sim, fleet, id)
	sim.events.emit(&"fleet_out", {"army": fleet.id, "province": id, "ships": fleet.ships})
	return merge(sim, fleet)


static func _new_fleet(sim: Simulation, id: int) -> Army:
	var fleet := Army.new()
	fleet.id = sim.ids.take()
	fleet.owner = ProvinceDef.OWNER_PLAYER
	fleet.at = 0
	fleet.home = id
	fleet.fleet_home = id
	fleet.by_sea = true
	sim.world.armies[fleet.id] = fleet
	return fleet


## [param ship] leaves [param province] for [param fleet]: its soldiers aboard become the
## fleet's men.
static func _take(sim: Simulation, province: ProvinceSim, ship: ShipUnit, fleet: Army) -> void:
	for agent_id: int in ship.troops:
		var agent := province.agents.get_agent(agent_id)
		if agent == null:
			continue
		var unit := Troops.unit_of(province, agent)
		var barracks := province.buildings.get_building(agent.home_id)
		if barracks != null:
			barracks.soldiers.erase(agent.id)
		if unit != null:
			fleet.add(unit.id)
		province.remove_agent(agent)
	ship.troops.clear()
	province.jobs.cancel_for_entity(ship.id)
	province.ships.erase(ship.id)
	fleet.ships += 1
	fleet.fleet[ship.def.id] = fleet.fleet.get(ship.def.id, 0) + 1


## Why warship [param ship_id] of the viewed province cannot sail out to the world map, or &"".
static func sail_out_error(sim: Simulation, ship_id: int) -> StringName:
	if sim.world.is_single():
		return &"no_world"
	if sim.world.owner_of(sim.viewed_id) != ProvinceDef.OWNER_PLAYER:
		return &"not_your_province"
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if ship == null or ship.def.troops <= 0:
		return &"not_a_warship"
	if not _free(ship):
		return &"ship_busy"
	if ArmyOrders.offshore(sim, sim.viewed_id) == Vector2.INF:
		return &"no_coast"
	return &""


## Warship [param ship_id] of the viewed province sails to the edge of the map, where it joins
## the fleet of the province (INSIDE until its last ship is off the map).
static func sail_out(sim: Simulation, ship_id: int) -> Army:
	var province := sim.province
	var ship := province.ships[ship_id]
	var fleet: Army = null
	for army: Army in sim.world.armies.values():
		if army.owner == ProvinceDef.OWNER_PLAYER and army.state == Army.State.INSIDE and army.by_sea \
				and army.at == sim.viewed_id:
			fleet = army
	if fleet == null:
		fleet = _new_fleet(sim, sim.viewed_id)
		fleet.state = Army.State.INSIDE
		fleet.at = sim.viewed_id
	ship.sail_out = fleet.id
	ship.dock_id = 0
	var edge := SeaMerchant._edge_for(province, Ships.nav_for(province, ship.def), ship.tile())
	if edge == Agent.NO_TILE or not Ships.sail_to(province, ship, edge):
		leave_map(province, ship)
	sim.events.emit(&"ship_sailing_out", {"ship": ship_id, "army": fleet.id})
	return fleet


## A ship sailing out is at the edge (Ships.update) or the province is left: it goes off the
## map; Armies.absorb adds it and its soldiers to its fleet.
static func leave_map(province: ProvinceSim, ship: ShipUnit) -> void:
	for agent_id: int in ship.troops:
		var agent := province.agents.get_agent(agent_id)
		if agent == null:
			continue
		var unit := Troops.unit_of(province, agent)
		var barracks := province.buildings.get_building(agent.home_id)
		if barracks != null:
			barracks.soldiers.erase(agent.id)
		if unit != null:
			province.marched.append({"army": ship.sail_out, "unit": unit.id})
		province.remove_agent(agent)
	ship.troops.clear()
	province.marched.append({"army": ship.sail_out, "ship": ship.def.id})
	province.jobs.cancel_for_entity(ship.id)
	province.ships.erase(ship.id)
	province.events.emit(&"ship_sailed_out", {"ship": ship.id})


## Ships of the viewed province still sailing out for [param fleet].
static func sailing_out(province: ProvinceSim, fleet: int) -> int:
	var count := 0
	for ship: ShipUnit in province.ships.values():
		if ship.sail_out == fleet:
			count += 1
	return count


## A fleet whose last ship left the viewed map stands off the coast (and joins a fleet there).
static func out_of_province(sim: Simulation, fleet: Army) -> void:
	fleet.state = Army.State.IDLE
	fleet.pos = ArmyOrders.offshore(sim, fleet.fleet_home)
	fleet.at = 0
	Armies.refill_from(sim, fleet, fleet.fleet_home)
	sim.events.emit(&"fleet_out", {"army": fleet.id, "province": fleet.fleet_home, "ships": fleet.ships})
	merge(sim, fleet)


## [param fleet] joins another fleet of its side standing near it (the older one stays).
static func merge(sim: Simulation, fleet: Army) -> Army:
	if fleet.pos == Vector2.INF:
		return fleet
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var other := sim.world.armies[key]
		if other == fleet or other.owner != fleet.owner or not other.is_fleet() or other.state != Army.State.IDLE \
				or other.pos.distance_to(fleet.pos) > MERGE:
			continue
		other.ships += fleet.ships
		for id: StringName in fleet.fleet:
			other.fleet[id] = other.fleet.get(id, 0) + fleet.fleet[id]
		for unit: StringName in fleet.units:
			other.add(unit, fleet.units[unit])
		other.food += fleet.food
		sim.world.armies.erase(fleet.id)
		return other
	return fleet


# --- At the end of its way ---------------------------------------------------------------------

static func arrive(sim: Simulation, fleet: Army) -> void:
	if fleet.docking:
		dock(sim, fleet, fleet.target)
	elif fleet.ashore != Vector2.INF:
		land(sim, fleet)
	else:
		fleet.state = Army.State.IDLE
		fleet.target = 0
		sim.events.emit(&"army_arrived", {"army": fleet.id, "province": 0})


## The fleet goes into the port of province [param id]: its warships anchor there, its
## soldiers go into the barracks (the rest stand by the town as an army).
static func dock(sim: Simulation, fleet: Army, id: int) -> void:
	var province := sim.province_state(id)
	fleet.docking = false
	if province != null and sim.world.owner_of(id) == fleet.owner:
		var ids: Array[StringName] = []
		ids.assign(fleet.fleet.keys())
		ids.sort()
		for ship_id: StringName in ids:
			var def := sim.data.get_ship(ship_id)
			if def == null:
				continue
			for k: int in fleet.fleet[ship_id]:
				var ship := ShipUnit.new(sim.ids.take(), def, Vector2.ZERO, sim.data)
				var at := Armies._sea_spot(province, ship)
				if at == Agent.NO_TILE:
					break
				ship.pos = IsoMath.tile_center(at)
				ship.prev_pos = ship.pos
				province.ships[ship.id] = ship
	sim.events.emit(&"fleet_docked", {"army": fleet.id, "province": id, "ships": fleet.ships})
	fleet.ships = 0
	fleet.fleet.clear()
	fleet.by_sea = false
	if fleet.is_empty():
		sim.world.armies.erase(fleet.id)
		return
	fleet.pos = ArmyOrders.stand_point(sim, id)
	fleet.at = id
	fleet.state = Army.State.IDLE
	fleet.target = 0
	Armies.join_barracks(sim, fleet)


## The fleet sets its soldiers ashore: they are an army on the land (the same army), walking on
## to where they were sent; the warships stay at sea as a new fleet.
static func land(sim: Simulation, fleet: Army) -> void:
	var ships := Army.new()
	ships.id = sim.ids.take()
	ships.owner = fleet.owner
	ships.state = Army.State.IDLE
	ships.by_sea = true
	ships.pos = fleet.pos
	ships.at = 0
	ships.ships = fleet.ships
	ships.fleet = fleet.fleet.duplicate()
	ships.fleet_home = fleet.fleet_home
	ships.home = fleet.fleet_home
	sim.world.armies[ships.id] = ships
	fleet.ships = 0
	fleet.fleet.clear()
	fleet.by_sea = false
	fleet.pos = fleet.ashore
	var goal := fleet.ashore_goal
	fleet.ashore = Vector2.INF
	fleet.ashore_goal = Vector2.INF
	ArmyOrders.place(sim, fleet)
	sim.events.emit(&"army_landed", {"army": fleet.id, "fleet": ships.id, "province": fleet.at})
	merge(sim, ships)
	var way: Array[Vector2] = []
	var n := ArmyOrders.nav(sim)
	if goal != Vector2.INF and goal.distance_to(fleet.pos) > 1.0 and n != null:
		way = n.find_path(fleet.pos, goal, false)
	fleet.landed_by_sea = true
	if not way.is_empty():
		fleet.path = way
		fleet.state = Army.State.MOVING
		return
	fleet.path.clear()
	Armies.arrive_on_land(sim, fleet)


# --- Sea battles -------------------------------------------------------------------------------

## Two fleets of enemies met at sea: BattleResolver decides it (J1 part 3: by kinds of
## warships, with the soldiers aboard); ships sunk stay sunk, men the ships afloat cannot carry
## drown; the beaten fleet sails home (or is gone).
static func sea_battle(sim: Simulation, a: Army, b: Army) -> void:
	var result := Armies.battle(sim, a, b.side(), BattleResolver.Kind.NAVAL, null, 0, b.owner, a.pos)
	b.lose(result.lost_b)
	a.sink_to(result.ships_left_a)
	b.sink_to(result.ships_left_b)
	sim.events.emit(&"sea_battle", {"pos": a.pos, "attacker": a.owner, "defender": b.owner,
			"won": result.a_won(), "province": 0})
	ArmyMeetings.after_battle(sim, a, b, result.a_won())

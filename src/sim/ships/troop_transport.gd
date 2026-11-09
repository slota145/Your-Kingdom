class_name TroopTransport
extends RefCounted
## Soldiers aboard a warship (P2 part 2, ROADMAP P2): the player right-clicks a warship with
## soldiers selected; a ship that is not moored sails to the nearest free berth it can reach
## (a port, a mooring or a bollard) and moors there, the soldiers walk to it and go aboard one
## by one, as many as it has room for (ShipDef.troops); then it sails back to anchor and frees
## the quay (owner's survey 2026-11-09). Landing them goes the same way the other way round:
## to a free berth, the soldiers step ashore and stand by the dock, the ship goes back to
## anchor. Soldiers aboard keep their agents (life, unit, barracks) with vehicle Ships.ABOARD:
## they move with the ship, are not drawn, cannot be selected and do not fight. They do not
## sail off with a world army (survey 2026-11-09: later). Static helpers like Ships.

const BOARD := &"board"
const LAND := &"land"
## Ticks between two soldiers going aboard or ashore.
const STEP_TICKS := 4
## How near (tiles) to the dock's entrance a soldier must be to go aboard.
const REACH := 3.5


## Free places for soldiers aboard [param ship] (counting those on their way aboard).
static func room(ship: ShipUnit) -> int:
	return maxi(ship.def.troops - ship.troops.size() - ship.boarding.size(), 0)


## Whether [param ship] can carry soldiers for the player (a warship of his, not a visitor's).
static func carries_troops(province: ProvinceSim, ship: ShipUnit) -> bool:
	if ship == null or ship.def.troops <= 0 or ship.is_away():
		return false
	if ship.id == province.sea_merchant.ship_id:
		return false
	return province.landing == null or not province.landing.is_landing_ship(ship)


## Orders [param soldiers] aboard [param ship] (as many as it has room for). Returns how many.
static func order_board(province: ProvinceSim, ship: ShipUnit, soldiers: Array[Agent]) -> int:
	var taken := 0
	for agent: Agent in soldiers:
		if room(ship) <= 0:
			break
		if ship.boarding.has(agent.id) or ship.troops.has(agent.id):
			continue
		_leave_other_orders(province, agent)
		# Under orders from now on: he waits where he is until the ship has a berth.
		Troops.take_command(agent)
		agent.combat.order = CombatState.Order.NONE
		ship.boarding.append(agent.id)
		taken += 1
	if taken > 0:
		ship.troop_order = BOARD
		ship.troops_called = 0
		province.events.emit(&"troops_boarding", {"ship": ship.id, "count": taken})
	return taken


## Orders the soldiers aboard [param ship] ashore at the nearest free berth.
static func order_land(province: ProvinceSim, ship: ShipUnit) -> void:
	ship.troop_order = LAND
	province.events.emit(&"troops_landing", {"ship": ship.id, "count": ship.troops.size()})


## A soldier ordered aboard another ship, or anything else, leaves that order.
static func _leave_other_orders(province: ProvinceSim, agent: Agent) -> void:
	for other: ShipUnit in province.ships.values():
		other.boarding.erase(agent.id)


## The soldier was given another order (OrderTroopsCommand): he is no longer going aboard.
static func forget(province: ProvinceSim, agents: Array[Agent]) -> void:
	for agent: Agent in agents:
		_leave_other_orders(province, agent)


## Every tick: soldiers aboard move with their ship; ships with an order go to a berth, take
## soldiers aboard or set them ashore, then go back to anchor.
static func update(province: ProvinceSim) -> void:
	for ship: ShipUnit in province.ships.values():
		if ship.troops.is_empty() and ship.troop_order == &"":
			continue
		_prune(province, ship)
		for id: int in ship.troops:
			var agent := province.agents.get_agent(id)
			agent.pos = ship.pos
			agent.prev_pos = ship.prev_pos
		if ship.troop_order != &"":
			_work(province, ship)


static func _prune(province: ProvinceSim, ship: ShipUnit) -> void:
	for list: Array in [ship.troops, ship.boarding]:
		for i: int in range(list.size() - 1, -1, -1):
			var agent := province.agents.get_agent(list[i])
			if agent == null or agent.combat == null or agent.combat.hp <= 0:
				list.remove_at(i)


static func _work(province: ProvinceSim, ship: ShipUnit) -> void:
	if ship.troop_order == BOARD and ship.boarding.is_empty():
		_done(province, ship)
		return
	if ship.troop_order == LAND and ship.troops.is_empty():
		_done(province, ship)
		return
	var dock := _dock(province, ship)
	if dock == null:
		return
	if ship.troop_order == BOARD and ship.troops_called != dock.id:
		# The soldiers walk to the dock now that it is known.
		ship.troops_called = dock.id
		Troops.order_move(province, _agents(province, ship.boarding), dock.entrance_tile(), MilitaryNav.GROUND)
	if not (ship.is_moored() and ship.dock_id == dock.id):
		return
	if province.tick % STEP_TICKS != 0:
		return
	if ship.troop_order == BOARD:
		_board_one(province, ship, dock)
	else:
		_land_one(province, ship, dock)


## The dock [param ship] holds a berth at, moored or on its way; finds and claims the nearest
## free one it can reach (once a second) when it holds none. Null while there is none.
static func _dock(province: ProvinceSim, ship: ShipUnit) -> BuildingState:
	var dock := province.buildings.get_building(ship.berth_id) if ship.berth_id != 0 else null
	if dock == null or not dock.def.is_port() or not dock.is_complete():
		ship.berth_id = 0
		if province.tick % SimClock.TICKS_PER_SECOND != 0:
			return null
		dock = free_dock(province, ship)
		if dock == null:
			return null
		Harbour.claim_berth(province, ship, dock)
		if ship.is_moored() and ship.dock_id != dock.id:
			ship.dock_id = 0
		Ships.sail_to(province, ship, dock.berth_tile())
	if ship.is_moored() and ship.dock_id == dock.id:
		return dock
	var berth := dock.berth_tile()
	if ship.path_state == ShipUnit.PathState.ARRIVED and ship.tile() == berth:
		Harbour.moor(ship, dock)
		province.events.emit(&"ship_moored", {"ship": ship.id, "port": dock.id})
	elif ship.path_state != ShipUnit.PathState.MOVING and province.tick % SimClock.TICKS_PER_SECOND == 0:
		if not Ships.sail_to(province, ship, berth):
			ship.berth_id = 0   # cannot get there: look for another berth
	return dock


## The nearest finished dock (port, mooring, bollard) whose berth is free and which [param ship]
## can sail to; null if none.
static func free_dock(province: ProvinceSim, ship: ShipUnit) -> BuildingState:
	var nav := Ships.nav_for(province, ship.def)
	var docks: Array[BuildingState] = []
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or not building.is_complete():
			continue
		var holder := Harbour.berth_holder(province, building)
		if holder != null and holder != ship:
			continue
		if not nav.is_walkable(building.berth_tile()):
			continue
		docks.append(building)
	docks.sort_custom(func(a: BuildingState, b: BuildingState) -> bool:
		var da := (a.berth_tile() - ship.tile()).length_squared()
		var db := (b.berth_tile() - ship.tile()).length_squared()
		return da < db or (da == db and a.id < b.id))
	for building: BuildingState in docks:
		if ship.tile() == building.berth_tile() or not nav.find_path(ship.tile(), building.berth_tile()).is_empty():
			return building
	return null


## The nearest soldier on his way aboard who has come to the dock goes aboard.
static func _board_one(province: ProvinceSim, ship: ShipUnit, dock: BuildingState) -> void:
	var door := IsoMath.tile_center(dock.entrance_tile())
	for id: int in ship.boarding:
		var agent := province.agents.get_agent(id)
		if agent.pos.distance_to(door) > REACH or agent.level != MilitaryNav.GROUND:
			continue
		ship.boarding.erase(id)
		ship.troops.append(id)
		var c := agent.combat
		c.order = CombatState.Order.NONE
		c.target_id = 0
		c.clear_path()
		agent.clear_path()
		agent.vehicle = Ships.ABOARD
		agent.activity = &"idle"
		agent.pos = ship.pos
		agent.prev_pos = ship.pos
		province.events.emit(&"soldier_aboard", {"agent": id, "ship": ship.id})
		return


## One soldier steps ashore at the dock's entrance; the last one sends them all to stand by
## the dock.
static func _land_one(province: ProvinceSim, ship: ShipUnit, dock: BuildingState) -> void:
	var id: int = ship.troops.pop_front()
	var agent := province.agents.get_agent(id)
	agent.vehicle = &""
	agent.pos = IsoMath.tile_center(dock.entrance_tile())
	agent.prev_pos = agent.pos
	agent.level = MilitaryNav.GROUND
	ship.landed.append(id)
	province.events.emit(&"soldier_ashore", {"agent": id, "ship": ship.id})
	if ship.troops.is_empty():
		var stand := province.door_tile(dock)
		if stand == Agent.NO_TILE:
			stand = dock.entrance_tile()
		Troops.order_move(province, _agents(province, ship.landed), stand, MilitaryNav.GROUND)
		ship.landed.clear()


## The order is carried out: the ship leaves the berth and goes back to anchor.
static func _done(province: ProvinceSim, ship: ShipUnit) -> void:
	var order := ship.troop_order
	ship.troop_order = &""
	ship.troops_called = 0
	if not ship.landed.is_empty():
		ship.landed.clear()
	var berth := Agent.NO_TILE
	var dock := province.buildings.get_building(ship.berth_id) if ship.berth_id != 0 else null
	if dock != null:
		berth = dock.berth_tile()
	ship.berth_id = 0
	ship.dock_id = 0
	province.events.emit(&"troops_done", {"ship": ship.id, "order": order, "aboard": ship.troops.size()})
	if berth == Agent.NO_TILE:
		return
	var anchor := Voyage.anchorage(province, ship, berth)
	if anchor != Agent.NO_TILE:
		Ships.sail_to(province, ship, anchor)


static func _agents(province: ProvinceSim, ids: Array[int]) -> Array[Agent]:
	var result: Array[Agent] = []
	for id: int in ids:
		var agent := province.agents.get_agent(id)
		if agent != null:
			result.append(agent)
	return result

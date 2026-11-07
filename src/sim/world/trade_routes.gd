class_name TradeRoutes
extends RefCounted
## Runs the trade routes of the world once a second (ROADMAP M6 part 3, GDD §4.5; the states
## are TradeRoute's). Loading and unloading are visible in the viewed province (Voyage,
## RouteWagon) and happen at once in a province nobody looks at.


## Once a second (Simulation._update_world).
static func update(sim: Simulation) -> void:
	var ids: Array[int] = []
	ids.assign(sim.world.routes.keys())
	ids.sort()
	for id: int in ids:
		var route := sim.world.routes.get(id) as TradeRoute
		if route != null:
			_update(sim, route)


static func _update(sim: Simulation, route: TradeRoute) -> void:
	var tick := sim.clock.tick
	match route.state:
		TradeRoute.State.WAITING:
			if route.closing or route.one_off:
				remove(sim, route)
				return
			if route.paused or not vehicle_ready(sim, route):
				return
			var run := plan_run(sim, route)
			if not run.is_empty():
				_begin_loading(sim, route, run)
		TradeRoute.State.LOADING:
			var cargo: Variant = _loaded_cargo(sim, route)
			if cargo == null:
				return
			route.cargo = cargo
			var seconds := travel_seconds(sim, route)
			route.depart_at = tick
			if route.cargo.is_empty():
				# Nothing came aboard after all: it comes back at once.
				route.state = TradeRoute.State.RETURNING
				route.arrive_at = tick
			else:
				route.state = TradeRoute.State.TRAVELLING
				route.arrive_at = tick + SimClock.seconds_to_ticks(seconds)
				sim.events.emit(&"route_travelling", {"route": route.id, "from": route.from, "to": route.to})
		TradeRoute.State.TRAVELLING:
			if tick >= route.arrive_at:
				_begin_unloading(sim, route)
		TradeRoute.State.UNLOADING:
			var there := sim.province_state(route.to)
			var wagon := there.route_wagons.get(route.id) as RouteWagon if there != null else null
			if wagon == null or wagon.is_gone():
				if there != null:
					there.route_wagons.erase(route.id)
				_return(sim, route)
		TradeRoute.State.RETURNING:
			if tick >= route.arrive_at:
				route.state = TradeRoute.State.WAITING
				_call_cog_home(sim, route)
				if route.one_off or route.closing:
					remove(sim, route)


## The province the route sets out from, in detail or frozen (null when it is gone).
static func home(sim: Simulation, route: TradeRoute) -> ProvinceSim:
	return sim.province_state(route.from)


## The route's cog, or null.
static func cog(sim: Simulation, route: TradeRoute) -> ShipUnit:
	var p := home(sim, route)
	if p == null or not route.by_sea:
		return null
	var ship := p.ships.get(route.vehicle) as ShipUnit
	return ship if ship != null and ship.voyage != null else null


## Seconds a journey of the route takes one way (a merchant wagon is slower than a cart).
static func travel_seconds(sim: Simulation, route: TradeRoute) -> float:
	var seconds := maxf(sim.world.travel_seconds(route.from, route.to, route.by_sea, sim.data), 0.0)
	return seconds if route.by_sea else seconds * TradeRoute.WAGON_SLOWNESS


## The trading post lending the route's merchant wagon, or null.
static func depot(sim: Simulation, route: TradeRoute) -> BuildingState:
	var p := home(sim, route)
	if p == null or route.by_sea:
		return null
	var building := p.buildings.get_building(route.vehicle)
	return building if building != null and building.def.id == TradeRoute.TRADING_POST else null


## Whether the vehicle is at home and free for the next run.
static func vehicle_ready(sim: Simulation, route: TradeRoute) -> bool:
	if route.by_sea:
		var ship := cog(sim, route)
		return ship != null and ship.home_id != 0 and ship.voyage.route == route.id \
				and ship.voyage.expedition == 0 and ship.voyage.state == Voyage.State.IDLE \
				and ship.hold.is_empty()
	var building := depot(sim, route)
	return building != null and building.is_complete() and not building.paused \
			and not home(sim, route).route_wagons.has(route.id)


## Units a run takes now (good -> units): every line whose good B has less of than its
## threshold while A has some, at most the line's amount and what A holds, all within the
## vehicle's hold. Empty when B lacks nothing (or A has nothing of it).
static func plan_run(sim: Simulation, route: TradeRoute) -> Dictionary[StringName, int]:
	var run: Dictionary[StringName, int] = {}
	var a := home(sim, route)
	var b := sim.province_state(route.to)
	if a == null or b == null:
		return run
	# A neutral settlement being bought takes what its demand still lacks (M6 part 3).
	var settlement := sim.world.settlements.get(route.to) as NeutralSettlement \
			if sim.world.owner_of(route.to) == ProvinceDef.OWNER_NEUTRAL else null
	for entry: Dictionary in route.lines:
		var good: StringName = entry["good"]
		if run.has(good):
			continue
		var most := int(entry["amount"])
		if settlement != null:
			most = mini(most, settlement.missing(good) if settlement.state == NeutralSettlement.State.ASKING else 0)
		elif b.stored(good) >= int(entry["below"]):
			continue
		var units := mini(most, a.stored(good))
		if units > 0:
			run[good] = units
	_fit(sim, route, run)
	return run


## Cuts [param run] down to what the vehicle takes (the last goods first).
static func _fit(sim: Simulation, route: TradeRoute, run: Dictionary[StringName, int]) -> void:
	var keys: Array[StringName] = []
	keys.assign(run.keys())
	if route.by_sea:
		var ship := cog(sim, route)
		if ship == null:
			run.clear()
			return
		while not run.is_empty() and Voyage.slots_needed(run, ship.hold) > ship.def.hold_slots:
			_cut(run, keys)
	else:
		var total := 0
		for good: StringName in run:
			total += run[good]
		while total > TradeRoute.WAGON_LOAD:
			_cut(run, keys)
			total -= 1


static func _cut(run: Dictionary[StringName, int], keys: Array[StringName]) -> void:
	var largest: StringName = keys[0]
	for good: StringName in keys:
		if run.has(good) and (not run.has(largest) or run[good] > run[largest]):
			largest = good
	run[largest] -= 1
	if run[largest] <= 0:
		run.erase(largest)
		keys.erase(largest)


static func _begin_loading(sim: Simulation, route: TradeRoute, run: Dictionary[StringName, int]) -> void:
	route.state = TradeRoute.State.LOADING
	var a := home(sim, route)
	if route.by_sea:
		cog(sim, route).voyage.start_route_run(run)
	elif sim.is_detailed(route.from):
		a.route_wagons[route.id] = RouteWagon.to_load(a, route.id, run, depot(sim, route))
	else:
		var near := a.door_tile(depot(sim, route))
		var cargo: Dictionary[StringName, int] = {}
		for good: StringName in RouteWagon._sorted(run):
			var taken := a.take_from_storages(good, run[good], near, false)
			if taken > 0:
				cargo[good] = taken
		var wagon := RouteWagon.new()
		wagon.id = route.id
		wagon.store = Stockpile.new(RouteWagon.SLOTS, sim.data)
		for good: StringName in cargo:
			wagon.store.add(good, cargo[good])
		wagon.state = RouteWagon.State.GONE
		a.route_wagons[route.id] = wagon
	sim.events.emit(&"route_loading", {"route": route.id, "province": route.from})


## The cargo once the vehicle has left A, else null (still loading).
static func _loaded_cargo(sim: Simulation, route: TradeRoute) -> Variant:
	var empty: Dictionary[StringName, int] = {}
	if route.by_sea:
		var ship := cog(sim, route)
		if ship == null:
			return empty   # the cog is gone: the run ends
		if ship.voyage.state != Voyage.State.AWAY:
			return null
		var cargo := ship.voyage.shipped
		ship.voyage.shipped = {}
		return cargo
	var a := home(sim, route)
	var wagon := a.route_wagons.get(route.id) as RouteWagon if a != null else null
	if wagon == null:
		return empty
	if not wagon.is_gone():
		return null
	a.route_wagons.erase(route.id)
	a.jobs.cancel_for_entity(route.id)
	return wagon.cargo()


## The cargo arrives in B: a wagon drives in (B viewed), a cog's cargo is put down at B's port
## for porters (B viewed), or it all goes into the storages at once.
static func _begin_unloading(sim: Simulation, route: TradeRoute) -> void:
	var b := sim.province_state(route.to)
	var cargo := route.cargo
	route.cargo = {}
	route.runs += 1
	for good: StringName in cargo:
		route.delivered += cargo[good]
	sim.events.emit(&"route_arrived", {"route": route.id, "province": route.to})
	if b == null:
		_return(sim, route)   # nobody to take it (cannot happen while B is the player's)
		return
	var settlement := sim.world.settlements.get(route.to) as NeutralSettlement \
			if sim.world.owner_of(route.to) == ProvinceDef.OWNER_NEUTRAL else null
	if settlement != null:
		# Bought goods: counted towards the demand, the rest goes into the town's storages.
		for good: StringName in RouteWagon._sorted(cargo):
			cargo[good] = settlement.take(good, cargo[good])
			if cargo[good] <= 0:
				cargo.erase(good)
		sim.events.emit(&"settlement_delivered", {"province": route.to, "route": route.id})
	var viewed := sim.is_detailed(route.to)
	if viewed and not route.by_sea:
		route.state = TradeRoute.State.UNLOADING
		b.route_wagons[route.id] = RouteWagon.to_unload(b, route.id, cargo)
		return
	var tile := _drop_tile(b)
	for good: StringName in RouteWagon._sorted(cargo):
		if viewed:
			b.drop_goods(tile, good, cargo[good])
		else:
			Departure.give_back(b, good, cargo[good], tile, true)
	_return(sim, route)


## Where a cog's cargo is put down in B: in front of its port, else of its town hall.
static func _drop_tile(b: ProvinceSim) -> Vector2i:
	for building: BuildingState in b.buildings.all():
		if building.def.is_port() and building.is_complete():
			return b.door_tile(building)
	var hall := b.seat()
	return b.door_tile(hall) if hall != null else b.entry_tile


static func _return(sim: Simulation, route: TradeRoute) -> void:
	route.state = TradeRoute.State.RETURNING
	route.depart_at = sim.clock.tick
	route.arrive_at = sim.clock.tick + SimClock.seconds_to_ticks(
			travel_seconds(sim, route))


static func _call_cog_home(sim: Simulation, route: TradeRoute) -> void:
	var ship := cog(sim, route)
	if ship != null:
		ship.voyage.call_home(sim.clock.tick)


## Takes the route off the world and lets its vehicle go (it must be at home: WAITING).
static func remove(sim: Simulation, route: TradeRoute) -> void:
	sim.world.routes.erase(route.id)
	var ship := cog(sim, route)
	if ship != null and ship.voyage.route == route.id:
		ship.voyage.route = 0
		ship.voyage.route_run = {}
	var building := depot(sim, route)
	if building != null:
		building.lent = maxi(building.lent - 1, 0)
	var a := home(sim, route)
	if a != null:
		a.route_wagons.erase(route.id)
		a.jobs.cancel_for_entity(route.id)
	sim.events.emit(&"route_removed", {"route": route.id})


## Goods of the kingdom under way on routes (good -> units), for the tests of lost goods.
static func goods_under_way(sim: Simulation) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for route: TradeRoute in sim.world.routes.values():
		for good: StringName in route.cargo:
			result[good] = int(result.get(good, 0)) + route.cargo[good]
		var ship := cog(sim, route)
		if ship != null:
			for good: StringName in ship.voyage.shipped:
				result[good] = int(result.get(good, 0)) + ship.voyage.shipped[good]
	return result

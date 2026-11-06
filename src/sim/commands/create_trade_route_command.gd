class_name CreateTradeRouteCommand
extends Command
## Sets up a trade route from the player's province [member from_id] to his province
## [member to_id] (ROADMAP M6 part 3, the routes window): by sea with the player's cog
## [member vehicle] of A, or by land to a neighbour with a wagon lent by stable [member vehicle]
## of A. The goods are lines {good, amount, below} (TradeRoute.line), 1 to MAX_LINES.

var from_id: int
var to_id: int
var by_sea: bool
var vehicle: int
var lines: Array[Dictionary]


func _init(from: int, to: int, sea: bool, vehicle_id: int, goods: Array[Dictionary]) -> void:
	from_id = from
	to_id = to
	by_sea = sea
	vehicle = vehicle_id
	lines = goods


func validate(sim: Simulation) -> StringName:
	var error := route_error(sim, from_id, to_id, by_sea)
	if error != &"":
		return error
	if not vehicle_free(sim, from_id, by_sea, vehicle):
		return &"no_vehicle"
	return lines_error(sim, lines)


## Why no route can go from [param from] to [param to] this way, or &"".
static func route_error(sim: Simulation, from: int, to: int, sea: bool) -> StringName:
	var world := sim.world
	if world.is_single() or world.get_province(from) == null or world.get_province(to) == null \
			or from == to:
		return &"unknown_province"
	# To a neutral settlement too, while it asks for goods (M6 part 3: buying it).
	var buying := world.owner_of(to) == ProvinceDef.OWNER_NEUTRAL and world.settlements.has(to) \
			and not world.settlements[to].goods.is_empty()
	if world.owner_of(from) != ProvinceDef.OWNER_PLAYER \
			or (world.owner_of(to) != ProvinceDef.OWNER_PLAYER and not buying) \
			or not sim.runtimes.has(from) or not sim.runtimes.has(to):
		return &"not_your_province"
	if sea and not world.sea_route(from, to, sim.data):
		return &"no_sea_route"
	if not sea and not world.are_neighbours(from, to, sim.data):
		return &"not_a_neighbour"
	return &""


## Whether [param vehicle] of province [param from] can take a route: the player's cog with a
## port, not on a route or an expedition; a finished stable with a wagon not lent yet.
static func vehicle_free(sim: Simulation, from: int, sea: bool, vehicle: int) -> bool:
	var province := sim.province_state(from)
	if province == null:
		return false
	if sea:
		var ship := province.ships.get(vehicle) as ShipUnit
		return ship != null and ship.voyage != null and ship.home_id != 0 and ship.voyage.route == 0 \
				and ship.voyage.expedition == 0
	var stable := province.buildings.get_building(vehicle)
	return stable != null and stable.def.id == &"stable" and stable.is_complete() \
			and stable.lent < stable.def.worker_count()


## Vehicles of province [param from] free for a new route (ids): cogs by sea, stables by land.
static func free_vehicles(sim: Simulation, from: int, sea: bool) -> Array[int]:
	var result: Array[int] = []
	var province := sim.province_state(from)
	if province == null:
		return result
	if sea:
		for ship: ShipUnit in province.ships.values():
			if vehicle_free(sim, from, true, ship.id):
				result.append(ship.id)
	else:
		for building: BuildingState in province.buildings.all():
			if vehicle_free(sim, from, false, building.id):
				result.append(building.id)
	result.sort()
	return result


static func lines_error(sim: Simulation, goods: Array[Dictionary]) -> StringName:
	if goods.is_empty() or goods.size() > TradeRoute.MAX_LINES:
		return &"no_goods"
	for entry: Dictionary in goods:
		var def := sim.data.get_good(StringName(entry.get("good", &"")))
		if def == null or def.is_live() or int(entry.get("amount", 0)) <= 0 \
				or int(entry.get("below", -1)) < 0:
			return &"no_goods"
	return &""


func apply(sim: Simulation) -> void:
	var route := TradeRoute.new()
	route.id = sim.ids.take()
	route.from = from_id
	route.to = to_id
	route.by_sea = by_sea
	route.vehicle = vehicle
	for entry: Dictionary in lines:
		route.lines.append(TradeRoute.line(StringName(entry["good"]), int(entry["amount"]), int(entry["below"])))
	sim.world.routes[route.id] = route
	var province := sim.province_state(from_id)
	if by_sea:
		(province.ships[vehicle] as ShipUnit).voyage.route = route.id
	else:
		province.buildings.get_building(vehicle).lent += 1
	sim.events.emit(&"route_created", {"route": route.id, "from": from_id, "to": to_id})


func get_name() -> StringName:
	return &"create_trade_route"

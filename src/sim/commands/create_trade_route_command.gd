class_name CreateTradeRouteCommand
extends Command
## Sets up a trade route from the player's province [member from_id] to his province
## [member to_id] (ROADMAP M6 part 3, the routes window): by sea with the player's cog
## [member vehicle] of A, or by land to a neighbour with the merchant wagon of trading post [member vehicle]
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
	if error == &"" and sim.world.owner_of(from_id) != ProvinceDef.OWNER_PLAYER:
		error = &"not_your_province"
	if error != &"":
		return error
	if not vehicle_free(sim, from_id, by_sea, vehicle):
		return &"no_vehicle"
	return lines_error(sim, lines)


## Why no route can go from [param from] to [param to] this way, or &"" (the player's, or an
## AI ruler's between his provinces: [param from]'s owner).
static func route_error(sim: Simulation, from: int, to: int, sea: bool) -> StringName:
	var world := sim.world
	if world.is_single() or world.get_province(from) == null or world.get_province(to) == null \
			or from == to:
		return &"unknown_province"
	# To a neutral settlement too, while it asks for goods (M6 part 3: buying it).
	var buying := world.owner_of(to) == ProvinceDef.OWNER_NEUTRAL and world.settlements.has(to) \
			and not world.settlements[to].goods.is_empty()
	var owner := world.owner_of(from)
	if not (owner == ProvinceDef.OWNER_PLAYER or Rulers.is_ruler(owner)) \
			or (world.owner_of(to) != owner and not buying) \
			or not sim.runtimes.has(from) or not sim.runtimes.has(to):
		return &"not_your_province"
	if sea and not world.sea_route(from, to, sim.data):
		return &"no_sea_route"
	if not sea and not world.are_neighbours(from, to, sim.data):
		return &"not_a_neighbour"
	return &""


## Whether [param vehicle] of province [param from] can take a route: the player's cog with a
## port, not on a route or an expedition; a finished trading post whose wagon is free.
static func vehicle_free(sim: Simulation, from: int, sea: bool, vehicle: int) -> bool:
	var province := sim.province_state(from)
	if province == null:
		return false
	if sea:
		var ship := province.ships.get(vehicle) as ShipUnit
		return ship != null and ship.voyage != null and ship.home_id != 0 and ship.voyage.route == 0 \
				and ship.voyage.expedition == 0
	var depot := province.buildings.get_building(vehicle)
	return depot != null and depot.def.id == TradeRoute.TRADING_POST and depot.is_complete() \
			and depot.lent < depot.def.worker_count()


## Vehicles of province [param from] free for a new route (ids): cogs by sea, trading posts by land.
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
	create(sim, from_id, to_id, by_sea, vehicle, lines)


## Sets up the route (checked by [method validate] or, for an AI ruler, by RulerExpansion).
static func create(sim: Simulation, from_id: int, to_id: int, by_sea: bool, vehicle: int,
		lines: Array[Dictionary], one_off: bool = false) -> TradeRoute:
	var route := TradeRoute.new()
	route.id = sim.ids.take()
	route.from = from_id
	route.to = to_id
	route.by_sea = by_sea
	route.vehicle = vehicle
	route.one_off = one_off
	for entry: Dictionary in lines:
		route.lines.append(TradeRoute.line(StringName(entry["good"]), int(entry["amount"]), int(entry["below"])))
	sim.world.routes[route.id] = route
	var province := sim.province_state(from_id)
	if by_sea:
		(province.ships[vehicle] as ShipUnit).voyage.route = route.id
	else:
		province.buildings.get_building(vehicle).lent += 1
	sim.events.emit(&"route_created", {"route": route.id, "from": from_id, "to": to_id,
			"owner": sim.world.owner_of(from_id)})
	return route


func get_name() -> StringName:
	return &"create_trade_route"

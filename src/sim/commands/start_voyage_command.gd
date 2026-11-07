class_name StartVoyageCommand
extends Command
## Sends the player's cog out with its voyage plan (M5 part 3): it moors at its port and
## loads. With [member now] while loading: it casts off with what is aboard.
## With [member to_province] (M6 part 3, "to my province"): the plan's goods are carried to
## that province of the player instead of being sold over the horizon (a one-off TradeRoute).

var ship_id: int
var now: bool
var to_province: int


func _init(ship: int, cast_off_now: bool = false, to: int = 0) -> void:
	ship_id = ship
	now = cast_off_now
	to_province = to


func validate(sim: Simulation) -> StringName:
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if ship == null or ship.voyage == null:
		return &"unknown_ship"
	if now:
		return &"" if ship.voyage.state == Voyage.State.LOADING else &"not_loading"
	if ship.home_id == 0:
		return &"no_port"
	if ship.voyage.state != Voyage.State.IDLE or ship.voyage.route != 0 or ship.voyage.expedition != 0:
		return &"ship_busy"
	if to_province != 0:
		var error := CreateTradeRouteCommand.route_error(sim, sim.viewed_id, to_province, true)
		if error != &"":
			return error
		if ship.voyage.sell.is_empty():
			return &"no_goods"
	return &""


func apply(sim: Simulation) -> void:
	var voyage := (sim.province.ships[ship_id] as ShipUnit).voyage
	if now:
		voyage.depart_now = true
	elif to_province != 0:
		var route := TradeRoute.new()
		route.id = sim.ids.take()
		route.from = sim.viewed_id
		route.to = to_province
		route.by_sea = true
		route.vehicle = ship_id
		route.one_off = true
		for good: StringName in voyage.sell:
			route.lines.append(TradeRoute.line(good, voyage.sell[good], 0))
		route.state = TradeRoute.State.LOADING
		sim.world.routes[route.id] = route
		voyage.route = route.id
		voyage.start_route_run(voyage.sell)
	else:
		voyage.start()
	sim.events.emit(&"voyage_started", {"ship": ship_id, "now": now, "to": to_province})


func get_name() -> StringName:
	return &"start_voyage"

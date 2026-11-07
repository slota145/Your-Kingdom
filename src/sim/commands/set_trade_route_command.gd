class_name SetTradeRouteCommand
extends Command
## Changes the goods of trade route [member route_id] and whether it is paused (the routes
## window, ROADMAP M6 part 3). A run under way keeps its cargo; the next run follows the new
## lines.

var route_id: int
var lines: Array[Dictionary]
var paused: bool


func _init(route: int, goods: Array[Dictionary], pause: bool = false) -> void:
	route_id = route
	lines = goods
	paused = pause


func validate(sim: Simulation) -> StringName:
	var route := sim.world.routes.get(route_id) as TradeRoute
	if route == null or route.one_off or route.closing:
		return &"unknown_route"
	return CreateTradeRouteCommand.lines_error(sim, lines)


func apply(sim: Simulation) -> void:
	var route := sim.world.routes[route_id] as TradeRoute
	route.lines.clear()
	for entry: Dictionary in lines:
		route.lines.append(TradeRoute.line(StringName(entry["good"]), int(entry["amount"]), int(entry["below"])))
	route.paused = paused
	sim.events.emit(&"route_changed", {"route": route_id})


func get_name() -> StringName:
	return &"set_trade_route"

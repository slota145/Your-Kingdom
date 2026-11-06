class_name RemoveTradeRouteCommand
extends Command
## Removes trade route [member route_id] (the routes window, ROADMAP M6 part 3): at once when
## its vehicle is at home, else when it is back (the cargo under way still arrives). The cog
## goes back to its voyages, the wagon back to its stable.

var route_id: int


func _init(route: int) -> void:
	route_id = route


func validate(sim: Simulation) -> StringName:
	var route := sim.world.routes.get(route_id) as TradeRoute
	return &"unknown_route" if route == null or route.one_off else &""


func apply(sim: Simulation) -> void:
	var route := sim.world.routes[route_id] as TradeRoute
	if route.state == TradeRoute.State.WAITING:
		TradeRoutes.remove(sim, route)
	else:
		route.closing = true


func get_name() -> StringName:
	return &"remove_trade_route"

class_name StartVoyageCommand
extends Command
## Sends the player's cog out with its voyage plan (M5 part 3): it moors at its port and
## loads. With [member now] while loading: it casts off with what is aboard.

var ship_id: int
var now: bool


func _init(ship: int, cast_off_now: bool = false) -> void:
	ship_id = ship
	now = cast_off_now


func validate(sim: Simulation) -> StringName:
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if ship == null or ship.voyage == null:
		return &"unknown_ship"
	if now:
		return &"" if ship.voyage.state == Voyage.State.LOADING else &"not_loading"
	if ship.home_id == 0:
		return &"no_port"
	if ship.voyage.state != Voyage.State.IDLE:
		return &"ship_busy"
	return &""


func apply(sim: Simulation) -> void:
	var voyage := (sim.province.ships[ship_id] as ShipUnit).voyage
	if now:
		voyage.depart_now = true
	else:
		voyage.start()
	sim.events.emit(&"voyage_started", {"ship": ship_id, "now": now})


func get_name() -> StringName:
	return &"start_voyage"

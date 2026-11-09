class_name LandTroopsCommand
extends Command
## The soldiers aboard a warship go ashore at the nearest free berth (P2 part 2: a button in
## the ship's panel).

var ship_id: int


func _init(ship: int) -> void:
	ship_id = ship


func validate(sim: Simulation) -> StringName:
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if not TroopTransport.carries_troops(sim.province, ship):
		return &"not_a_warship"
	if ship.troops.is_empty():
		return &"no_troops_aboard"
	return &""


func apply(sim: Simulation) -> void:
	TroopTransport.order_land(sim.province, sim.province.ships[ship_id])


func get_name() -> StringName:
	return &"land_troops"

class_name BoardShipCommand
extends Command
## The player's soldiers go aboard a warship (P2 part 2): right click on the ship with them
## selected. A ship not moored sails to the nearest free berth first (TroopTransport).

var ids: Array[int]
var ship_id: int


func _init(soldier_ids: Array[int], ship: int) -> void:
	ids = soldier_ids
	ship_id = ship


func _soldiers(sim: Simulation) -> Array[Agent]:
	var result: Array[Agent] = []
	for id: int in ids:
		var agent := sim.province.agents.get_agent(id)
		if Troops.is_soldier(sim.province, agent):
			var unit := Troops.unit_of(sim.province, agent)
			if unit != null and unit.siege == &"":
				result.append(agent)
	return result


func validate(sim: Simulation) -> StringName:
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if not TroopTransport.carries_troops(sim.province, ship):
		return &"not_a_warship"
	if _soldiers(sim).is_empty():
		return &"no_soldiers"
	if TroopTransport.room(ship) <= 0:
		return &"ship_full"
	if ship.troop_order == TroopTransport.LAND:
		return &"ship_landing_troops"
	return &""


func apply(sim: Simulation) -> void:
	TroopTransport.order_board(sim.province, sim.province.ships[ship_id], _soldiers(sim))


func get_name() -> StringName:
	return &"board_ship"

class_name CancelShipOrderCommand
extends Command
## Removes an order from a shipyard's queue (M5). Cancelling the ship on the slipway puts the
## materials not used yet on the ground at the shipyard; work already done is lost.

var building_id: int
var index: int


func _init(building: int, order_index: int) -> void:
	building_id = building
	index = order_index


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if index < 0 or index >= building.ship_orders.size():
		return &"no_such_order"
	return &""


func apply(sim: Simulation) -> void:
	var province := sim.province
	var building := province.buildings.get_building(building_id)
	if index == 0:
		var build := Ships.build_at(province, building)
		if build != null:
			Ships.close_build(province, build, false)
	building.ship_orders.remove_at(index)
	sim.events.emit(&"ship_order_cancelled", {"building": building_id, "index": index})


func get_name() -> StringName:
	return &"cancel_ship_order"

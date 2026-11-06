class_name BuyCartCommand
extends Command
## Buys a handcart for a storage (M4b-3): its planks come out of the storages at once.

var building_id: int


func _init(building: int) -> void:
	building_id = building


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.def.max_carts <= 0 or not building.is_complete():
		return &"no_carts_here"
	if building.carts >= building.def.max_carts:
		return &"carts_full"
	for good: StringName in Carriers.HANDCART_COST:
		if sim.province.stored(good) < Carriers.HANDCART_COST[good]:
			return &"not_enough_goods"
	return &""


func apply(sim: Simulation) -> void:
	var province := sim.province
	var building := province.buildings.get_building(building_id)
	for good: StringName in Carriers.HANDCART_COST:
		province.take_from_storages(good, Carriers.HANDCART_COST[good], building.entrance_tile())
	building.carts += 1
	sim.events.emit(&"cart_bought", {"building": building_id, "carts": building.carts})


func get_name() -> StringName:
	return &"buy_cart"

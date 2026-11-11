class_name OrderShipCommand
extends Command
## Orders a ship at a shipyard (M5): it joins the end of the shipyard's queue. The first
## order goes onto the slipway and asks porters for its materials.

var building_id: int
var ship: StringName


func _init(building: int, ship_id: StringName) -> void:
	building_id = building
	ship = ship_id


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if not building.def.ship_kinds.has(ship) or sim.data.get_ship(ship) == null:
		return &"ship_not_built_here"
	if building.ship_orders.size() >= Ships.MAX_ORDERS:
		return &"orders_full"
	if not sim.province.research.allows_ship(sim.data, ship):
		return &"needs_research"   # E4 part 2
	return &""


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	building.ship_orders.append(ship)
	sim.events.emit(&"ship_ordered", {"building": building_id, "ship": ship,
			"orders": building.ship_orders.size()})


func get_name() -> StringName:
	return &"order_ship"

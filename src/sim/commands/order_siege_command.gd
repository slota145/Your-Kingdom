class_name OrderSiegeCommand
extends Command
## Orders a siege engine (a ram or a ladderman) from a siege workshop, or with an empty unit
## clears the list (materials already there stay in the workshop) (M7 part 2).

var building_id: int
var unit_id: StringName


func _init(workshop: int, unit: StringName) -> void:
	building_id = workshop
	unit_id = unit


func validate(sim: Simulation) -> StringName:
	var workshop := sim.province.buildings.get_building(building_id)
	if unit_id == &"":
		return &"" if workshop != null and not workshop.def.siege_engines.is_empty() else &"not_siege_workshop"
	return SiegeWorks.order_error(sim.province, workshop, sim.data.get_unit(unit_id))


func apply(sim: Simulation) -> void:
	var workshop := sim.province.buildings.get_building(building_id)
	if unit_id == &"":
		workshop.siege_orders.clear()
		workshop.siege_work = 0
		return
	workshop.siege_orders.append(unit_id)


func get_name() -> StringName:
	return &"order_siege"

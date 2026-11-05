class_name SetReserveCommand
extends Command
## Sets how many units of a good a storage keeps back from construction (ROADMAP M4 decisions:
## firewood for houses before building sites).

var building_id: int
var good: StringName
var amount: int


func _init(building: int, good_id: StringName, units: int) -> void:
	building_id = building
	good = good_id
	amount = units


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.stock == null:
		return &"not_a_storage"
	if sim.data.get_good(good) == null:
		return &"unknown_good"
	if amount < 0 or amount > BuildingState.MAX_RESERVE:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	if amount == 0:
		building.reserves.erase(good)
	else:
		building.reserves[good] = amount
	sim.events.emit(&"reserve_changed", {"building": building_id, "good": good, "amount": amount})


func get_name() -> StringName:
	return &"set_reserve"

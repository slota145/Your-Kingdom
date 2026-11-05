class_name SetKeepForBuildingCommand
extends Command
## Sets how many units of a good the workshops leave in the province for construction and
## households (GDD §4.1). One value for the whole province, 0 = none.

const MAX_KEEP := 60

var good: StringName
var amount: int


func _init(good_id: StringName, units: int) -> void:
	good = good_id
	amount = units


func validate(sim: Simulation) -> StringName:
	if sim.data.get_good(good) == null:
		return &"unknown_good"
	if amount < 0 or amount > MAX_KEEP:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	if amount == 0:
		sim.province.keep_for_building.erase(good)
	else:
		sim.province.keep_for_building[good] = amount
	sim.events.emit(&"keep_for_building_changed", {"good": good, "amount": amount})


func get_name() -> StringName:
	return &"set_keep_for_building"

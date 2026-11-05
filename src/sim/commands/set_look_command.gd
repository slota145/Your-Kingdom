class_name SetLookCommand
extends Command
## Chooses how a house looks (M4b-1.5, like picking a facade): 0 = by its position, 1.. =
## that look. Changes nothing in the simulation; the view and the save read it.

## Highest look number accepted.
const MAX_LOOK := 8

var building_id: int
var look: int


func _init(building: int, chosen: int) -> void:
	building_id = building
	look = chosen


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if not building.def.is_house():
		return &"not_a_house"
	if look < 0 or look > MAX_LOOK:
		return &"bad_look"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.buildings.get_building(building_id).look = look
	sim.events.emit(&"look_changed", {"building": building_id, "look": look})


func get_name() -> StringName:
	return &"set_look"

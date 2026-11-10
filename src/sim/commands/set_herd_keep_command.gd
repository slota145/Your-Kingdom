class_name SetHerdKeepCommand
extends Command
## Sets how many animals a herd keeps for breeding (Z1, the slider in the panel of a pigsty):
## nobody takes the herd below it. At least 2 (a pair), at most the herd's room.

## Lowest reserve the player can set: a breeding pair.
const MIN_KEEP := 2

var building_id: int
var keep: int


func _init(building: int, value: int) -> void:
	building_id = building
	keep = value


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.def.herd_good == &"":
		return &"no_herd"
	return &""


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	building.herd_keep = clampi(keep, MIN_KEEP, maxi(building.herd_room(), MIN_KEEP))
	sim.events.emit(&"herd_keep_changed", {"building": building_id, "keep": building.herd_keep})


func get_name() -> StringName:
	return &"set_herd_keep"
